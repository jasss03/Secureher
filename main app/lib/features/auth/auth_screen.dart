import 'package:flutter/material.dart';
import '../../widgets/branding.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _biometric = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Save session locally so user stays logged in
  Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();

    // Always store UID (non-null)
    await prefs.setString('userUid', user.uid);

    // Get fresh ID token and store if available
    final String? token = await user.getIdToken();
    if (token != null && token.isNotEmpty) {
      await prefs.setString('idToken', token);
    }
  }

  /// Login or signup logic
  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_loading) return;

    setState(() => _loading = true);
    final auth = AuthService();

    try {
      if (isLogin) {
        // Login mode
        if (_email.text.trim().isNotEmpty) {
          try {
            await auth.signInWithEmail(
              email: _email.text.trim(),
              password: _password.text,
            );

            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await _saveUserSession(user);
              }
            } catch (_) {}

            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          } on FirebaseAuthException catch (e) {
            String msg;
            switch (e.code) {
              case 'user-not-found':
                msg = 'No account found with this email. Please sign up first.';
                break;
              case 'wrong-password':
                msg = 'Incorrect password. Please try again.';
                break;
              case 'no-app':
                msg =
                    'App is not connected to Firebase. Please configure Firebase to enable login.';
                break;
              default:
                msg = e.message ?? 'Login failed';
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
          }
        } else if (_phone.text.trim().isNotEmpty) {
          // Check if user exists with this phone number before allowing OTP login
          try {
            // Show a message that they need to create an account first
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please create an account first before logging in with OTP',
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter email and password to login')),
          );
        }
      } else {
        // Sign Up mode
        if (_name.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Full Name is required to create an account'),
            ),
          );
        } else if (_phone.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile number is required to create an account'),
            ),
          );
        } else {
          try {
            // Create account with email if provided, otherwise use a placeholder
            final email = _email.text.trim().isNotEmpty
                ? _email.text.trim()
                : '${_phone.text.trim().replaceAll('+', '').replaceAll(' ', '')}@secureher.app';

            await auth.signUpWithEmail(
              email: email,
              password: _password.text,
              displayName: _name.text.trim(),
            );

            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await _saveUserSession(user);
              }
            } catch (_) {}

            if (!mounted) return;

            // Navigate to OTP verification screen with phone number
            Navigator.of(
              context,
            ).pushNamed('/otp', arguments: _phone.text.trim());
          } on FirebaseAuthException catch (e) {
            String msg;
            switch (e.code) {
              case 'email-already-in-use':
                msg =
                    'This email is already registered. Please log in instead.';
                break;
              case 'no-app':
                msg =
                    'App is not connected to Firebase. Please configure Firebase to enable sign up.';
                break;
              default:
                msg = e.message ?? 'Sign up failed';
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google login
  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService().signInWithGoogle();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _saveUserSession(user);
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      String friendly;
      switch (e.code) {
        case 'no-app':
          friendly =
              'Google sign-in isn\'t configured. Add GoogleService-Info.plist and URL schemes in Info.plist.';
          break;
        case 'ERROR_ABORTED_BY_USER':
          friendly = 'Sign in cancelled.';
          break;
        default:
          friendly = e.message ?? 'Google sign-in failed.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendly)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebaseReady = Firebase.apps.isNotEmpty;
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!firebaseReady)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Text(
                            'Note: Firebase is not configured on this build. Email/Google sign-in will not work until configured.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      const Align(
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.shield_rounded,
                          size: 40,
                          color: Color(0xFF7B61FF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin
                            ? 'Welcome to Your\nSafe Space'
                            : 'Create Your\nSafe Space',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedPills(
                        leftSelected: isLogin,
                        leftLabel: 'Login',
                        rightLabel: 'Sign Up',
                        onLeft: () => setState(() => isLogin = true),
                        onRight: () => setState(() => isLogin = false),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!isLogin) ...[
                              PillTextField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                label: 'Full Name *',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            PillTextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              label: 'Phone Number *',
                              validator: (v) =>
                                  !isLogin && (v == null || v.isEmpty)
                                  ? 'Phone number is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            PillTextField(
                              controller: _email,
                              textInputAction: TextInputAction.next,
                              label: isLogin
                                  ? 'Email Address (optional)'
                                  : 'Email Address',
                            ),
                            const SizedBox(height: 12),
                            PillTextField(
                              controller: _password,
                              obscure: true,
                              label: 'Password / PIN',
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter a password or PIN'
                                  : null,
                            ),
                            if (!isLogin) ...[
                              const SizedBox(height: 12),
                              PillTextField(
                                controller: TextEditingController(),
                                obscure: true,
                                label: 'Confirm Password',
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Re-enter password'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _biometric,
                              onChanged: (v) => setState(() => _biometric = v),
                              title: const Text(
                                'Enable biometric login (FaceID/TouchID)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            if ((_phone.text.trim()).isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Enter your phone number first',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            Navigator.of(context).pushNamed(
                                              '/otp',
                                              arguments: _phone.text.trim(),
                                            );
                                          },
                                    icon: const Icon(Icons.sms_rounded),
                                    label: const Text('Use OTP'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PrimaryPillButton(
                                    onPressed: _loading ? null : _continue,
                                    icon: _loading
                                        ? Icons.hourglass_top_rounded
                                        : Icons.arrow_forward_rounded,
                                    label: isLogin ? 'Login' : 'Create Account',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : _signInWithGoogle,
                                    icon: const Icon(Icons.g_translate_rounded),
                                    label: const Text('Continue with Google'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.privacy_tip_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Your data is encrypted and only shared during SOS.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
