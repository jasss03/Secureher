import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'services/companion_backend_service.dart';
import 'services/companion_contract.dart';
import 'services/notification_service.dart';
import 'widgets/branding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CompanionApp());

  if (!kIsWeb) {
    unawaited(NotificationService.initialize());
  }
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureHer Companion',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _refreshKey = 0;

  void _refreshLinkState() {
    if (mounted) {
      setState(() => _refreshKey += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: CompanionBackendService.authChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold(
            label: 'Restoring companion session...',
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const AuthScreen();
        }

        return FutureBuilder<LinkedMainAccount?>(
          key: ValueKey(_refreshKey),
          future: () async {
            // Updated to be non-blocking and use local cache for instant feedback
            unawaited(CompanionBackendService.ensureCompanionProfile());
            return CompanionBackendService.getActiveLink(useCache: true);
          }(),
          builder: (context, linkSnapshot) {
            // If we have cached data, we don't even show the loading scaffold
            final linked = linkSnapshot.data;

            if (linkSnapshot.connectionState == ConnectionState.waiting &&
                linked == null) {
              return const _LoadingScaffold(label: 'Loading linked account...');
            }

            if (linked == null) {
              return LinkScreen(onLinked: _refreshLinkState);
            }

            return DashboardShell(
              account: linked,
              onRefreshLink: _refreshLinkState,
            );
          },
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await CompanionBackendService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await CompanionBackendService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = error.message ?? 'Authentication failed.');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.shield_moon_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SecureHer Companion',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sign in once and manage safety features remotely from web or mobile.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 12,
                          children: [
                            ChoiceChip(
                              label: const Text('Sign in'),
                              selected: _isLogin,
                              onSelected: (_) =>
                                  setState(() => _isLogin = true),
                            ),
                            ChoiceChip(
                              label: const Text('Create account'),
                              selected: !_isLogin,
                              onSelected: (_) =>
                                  setState(() => _isLogin = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (_isLogin) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a display name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isLogin
                                      ? Icons.login_rounded
                                      : Icons.person_add_alt_1_rounded,
                                ),
                          label: Text(
                            _isLogin ? 'Sign in' : 'Create companion account',
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
      ),
    );
  }
}

class LinkScreen extends StatefulWidget {
  final VoidCallback onLinked;

  const LinkScreen({super.key, required this.onLinked});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the 6-digit code from the main app.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await CompanionBackendService.redeemLinkCode(_codeController.text.trim());
      widget.onLinked();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.link_rounded, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Link a SecureHer account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Open the main SecureHer app, generate a companion code, and redeem it here to unlock remote controls and shared safety settings.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Companion code',
                          hintText: '123456',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _link,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Link account'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => CompanionBackendService.signOut(),
                        child: const Text('Sign out'),
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

class DashboardShell extends StatefulWidget {
  final LinkedMainAccount account;
  final VoidCallback onRefreshLink;

  const DashboardShell({
    super.key,
    required this.account,
    required this.onRefreshLink,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewPage(account: widget.account),
      _RemotePage(account: widget.account),
      _SettingsPage(account: widget.account),
      _ActivityPage(account: widget.account),
    ];

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CompanionBackendService.watchDeviceState(
        widget.account.mainUserId,
      ),
      builder: (context, snapshot) {
        final deviceState = snapshot.data?.data() ?? const <String, dynamic>{};
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;

            return Scaffold(
              body: PastelBackground(
                child: SafeArea(
                  child: Row(
                    children: [
                      if (wide)
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: (value) =>
                              setState(() => _index = value),
                          labelType: NavigationRailLabelType.all,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard_rounded),
                              label: Text('Overview'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.tune_rounded),
                              selectedIcon: Icon(Icons.tune_rounded),
                              label: Text('Remote'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings_suggest_outlined),
                              selectedIcon: Icon(
                                Icons.settings_suggest_rounded,
                              ),
                              label: Text('Settings'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.history_rounded),
                              selectedIcon: Icon(Icons.history_rounded),
                              label: Text('Activity'),
                            ),
                          ],
                          trailing: Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: IconButton(
                                  tooltip: 'Sign out',
                                  onPressed: CompanionBackendService.signOut,
                                  icon: const Icon(Icons.logout_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.account.displayName ??
                                                widget.account.email ??
                                                'Linked SecureHer user',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Remote safety companion connected to ${widget.account.mainUserId}.',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusPill(
                                      label: deviceState['online'] == true
                                          ? 'Online'
                                          : 'Offline',
                                      icon: Icons.wifi_tethering_rounded,
                                    ),
                                    const SizedBox(width: 12),
                                    if (!wide)
                                      IconButton(
                                        tooltip: 'Sign out',
                                        onPressed:
                                            CompanionBackendService.signOut,
                                        icon: const Icon(Icons.logout_rounded),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(child: pages[_index]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (value) =>
                          setState(() => _index = value),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: 'Overview',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.tune_rounded),
                          selectedIcon: Icon(Icons.tune_rounded),
                          label: 'Remote',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings_suggest_outlined),
                          selectedIcon: Icon(Icons.settings_suggest_rounded),
                          label: 'Settings',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.history_rounded),
                          selectedIcon: Icon(Icons.history_rounded),
                          label: 'Activity',
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final LinkedMainAccount account;

  const _OverviewPage({required this.account});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CompanionBackendService.watchDeviceState(account.mainUserId),
      builder: (context, snapshot) {
        final state = snapshot.data?.data() ?? const <String, dynamic>{};
        final currentLocation = Map<String, dynamic>.from(
          state['currentLocation'] as Map? ?? const {},
        );
        final activeCheckIn = Map<String, dynamic>.from(
          state['activeCheckIn'] as Map? ?? const {},
        );
        final lastCommand = Map<String, dynamic>.from(
          state['lastCommandResult'] as Map? ?? const {},
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _StatCard(
                  icon: Icons.my_location_rounded,
                  label: 'Location sharing',
                  value: state['shareLocationEnabled'] == true
                      ? 'Active'
                      : 'Off',
                ),
                _StatCard(
                  icon: Icons.volume_up_rounded,
                  label: 'Buzzer',
                  value: state['sirenOn'] == true ? 'Playing' : 'Idle',
                ),
                _StatCard(
                  icon: Icons.battery_saver_rounded,
                  label: 'Battery saver',
                  value: state['batteryMode'] == true ? 'On' : 'Off',
                ),
                _StatCard(
                  icon: Icons.speed_rounded,
                  label: 'Motion sensitivity',
                  value:
                      ((state['motionSensitivity'] as num?)?.toDouble() ?? 1.5)
                          .toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Live location map',
              icon: Icons.map_rounded,
              child: currentLocation.isEmpty
                  ? const Text('No live location has been published yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF4F1FF), Color(0xFFE8FAF7)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.place_rounded,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${(currentLocation['lat'] as num?)?.toDouble().toStringAsFixed(5) ?? '—'}, ${(currentLocation['lng'] as num?)?.toDouble().toStringAsFixed(5) ?? '—'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'This stays in sync with the main app whenever live sharing or an alert updates location.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openMaps(
                            currentLocation['lat'],
                            currentLocation['lng'],
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open in Google Maps'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Active check-in',
              icon: Icons.timer_rounded,
              child: activeCheckIn.isEmpty
                  ? const Text('No active check-in is currently running.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeCheckIn['message'] as String? ??
                              'Check-in in progress',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scheduled for ${_formatTimestamp(activeCheckIn['scheduledFor'])}',
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(
                          label:
                              activeCheckIn['status'] as String? ?? 'pending',
                          icon: Icons.schedule_send_rounded,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Last command result',
              icon: Icons.task_alt_rounded,
              child: lastCommand.isEmpty
                  ? const Text('No remote command has been executed yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastCommand['type'] as String? ?? 'Remote command',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(lastCommand['message'] as String? ?? 'Completed.'),
                        const SizedBox(height: 8),
                        _StatusPill(
                          label: lastCommand['status'] as String? ?? 'unknown',
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _openMaps(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _RemotePage extends StatefulWidget {
  final LinkedMainAccount account;

  const _RemotePage({required this.account});

  @override
  State<_RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<_RemotePage> {
  final TextEditingController _checkInMessageController =
      TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _checkInMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand(
    String type, {
    Map<String, dynamic> payload = const {},
  }) async {
    setState(() => _busy = true);
    try {
      await CompanionBackendService.enqueueRemoteCommand(
        widget.account.mainUserId,
        type: type,
        payload: payload,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Queued $type successfully.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Command failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CompanionBackendService.watchDeviceState(
        widget.account.mainUserId,
      ),
      builder: (context, stateSnapshot) {
        final deviceState =
            stateSnapshot.data?.data() ?? const <String, dynamic>{};
        final motionSensitivity =
            (deviceState['motionSensitivity'] as num?)?.toDouble() ?? 1.5;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: CompanionBackendService.watchTrustedContacts(
            widget.account.mainUserId,
          ),
          builder: (context, contactsSnapshot) {
            final contacts =
                contactsSnapshot.data ?? const <Map<String, dynamic>>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                _SectionCard(
                  title: 'Remote safety controls',
                  icon: Icons.rocket_launch_rounded,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _sendCommand(
                                deviceState['shareLocationEnabled'] == true
                                    ? RemoteCommandType.stopShareLocation
                                    : RemoteCommandType.startShareLocation,
                              ),
                        icon: const Icon(Icons.my_location_rounded),
                        label: Text(
                          deviceState['shareLocationEnabled'] == true
                              ? 'Stop location sharing'
                              : 'Start location sharing',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _sendCommand(
                                deviceState['sirenOn'] == true
                                    ? RemoteCommandType.stopSiren
                                    : RemoteCommandType.playSiren,
                              ),
                        icon: const Icon(Icons.campaign_rounded),
                        label: Text(
                          deviceState['sirenOn'] == true
                              ? 'Stop buzzer'
                              : 'Play buzzer',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _sendCommand(
                                RemoteCommandType.triggerFakeCall,
                              ),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Trigger fake call'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy || contacts.isEmpty
                            ? null
                            : () => _showApprovedCallPicker(context, contacts),
                        icon: const Icon(Icons.phone_forwarded_rounded),
                        label: Text(
                          contacts.isEmpty
                              ? 'Add a contact first'
                              : 'Place approved call',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Remote settings',
                  icon: Icons.tune_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Battery saver'),
                        subtitle: const Text(
                          'Apply the low-power safety profile on the main app.',
                        ),
                        value: deviceState['batteryMode'] == true,
                        onChanged: _busy
                            ? null
                            : (value) => _sendCommand(
                                RemoteCommandType.setBatterySaver,
                                payload: {'enabled': value},
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Motion sensitivity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [0.8, 1.2, 1.5, 1.8, 2.2]
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value.toStringAsFixed(1)),
                                selected:
                                    motionSensitivity.toStringAsFixed(1) ==
                                    value.toStringAsFixed(1),
                                onSelected: _busy
                                    ? null
                                    : (_) => _sendCommand(
                                        RemoteCommandType.setMotionSensitivity,
                                        payload: {'value': value},
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Remote check-in',
                  icon: Icons.av_timer_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _checkInMessageController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Check-in note',
                          hintText: 'For example: Heading home after work.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final minutes in [15, 30, 60])
                            FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _sendCommand(
                                      RemoteCommandType.startCheckIn,
                                      payload: {
                                        'minutes': minutes,
                                        'message': _checkInMessageController
                                            .text
                                            .trim(),
                                      },
                                    ),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text('Start $minutes min timer'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _sendCommand(
                                    RemoteCommandType.cancelCheckIn,
                                  ),
                            icon: const Icon(
                              Icons.cancel_schedule_send_rounded,
                            ),
                            label: const Text('Cancel active check-in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showApprovedCallPicker(
    BuildContext context,
    List<Map<String, dynamic>> contacts,
  ) async {
    final selectedContactId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose an approved contact'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.phone_in_talk_rounded),
                ),
                title: Text(contact['name'] as String? ?? 'Trusted Contact'),
                subtitle: Text(contact['phone'] as String? ?? 'No number'),
                onTap: () => Navigator.of(context).pop(contact['id'] as String),
              );
            },
          ),
        ),
      ),
    );

    if (selectedContactId != null) {
      await _sendCommand(
        RemoteCommandType.placeApprovedCall,
        payload: {'contactId': selectedContactId},
      );
    }
  }
}

class _SettingsPage extends StatelessWidget {
  final LinkedMainAccount account;

  const _SettingsPage({required this.account});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _SectionCard(
          title: 'Trusted contacts',
          icon: Icons.people_alt_rounded,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: CompanionBackendService.watchTrustedContacts(
              account.mainUserId,
            ),
            builder: (context, snapshot) {
              final contacts = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _showContactDialog(context, account.mainUserId),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add trusted contact'),
                  ),
                  const SizedBox(height: 12),
                  if (contacts.isEmpty)
                    const Text('No trusted contacts yet.')
                  else
                    ...contacts.map(
                      (contact) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded),
                          ),
                          title: Text(
                            contact['name'] as String? ?? 'Trusted Contact',
                          ),
                          subtitle: Text(
                            '${contact['phone'] ?? 'No number'}${contact['relationship'] != null ? ' • ${contact['relationship']}' : ''}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showContactDialog(
                                  context,
                                  account.mainUserId,
                                  existing: contact,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () =>
                                    CompanionBackendService.deleteTrustedContact(
                                      account.mainUserId,
                                      contact['id'] as String,
                                    ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Safe zones',
          icon: Icons.shield_rounded,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: CompanionBackendService.watchSafeZones(account.mainUserId),
            builder: (context, snapshot) {
              final zones = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _showSafeZoneDialog(context, account.mainUserId),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Add safe zone'),
                  ),
                  const SizedBox(height: 12),
                  if (zones.isEmpty)
                    const Text('No safe zones configured yet.')
                  else
                    ...zones.map(
                      (zone) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.gpp_good_rounded),
                          ),
                          title: Text(zone['name'] as String? ?? 'Safe Zone'),
                          subtitle: Text(
                            '${(zone['lat'] as num?)?.toDouble().toStringAsFixed(5) ?? '0.00000'}, ${(zone['lng'] as num?)?.toDouble().toStringAsFixed(5) ?? '0.00000'} • ${(zone['radius'] as num?)?.toDouble().toStringAsFixed(0) ?? '150'}m',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showSafeZoneDialog(
                                  context,
                                  account.mainUserId,
                                  existing: zone,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () =>
                                    CompanionBackendService.deleteSafeZone(
                                      account.mainUserId,
                                      zone['id'] as String,
                                    ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showContactDialog(
    BuildContext context,
    String mainUserId, {
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: existing?['phone'] as String? ?? '',
    );
    final emailController = TextEditingController(
      text: existing?['email'] as String? ?? '',
    );
    final relationshipController = TextEditingController(
      text: existing?['relationship'] as String? ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'Add trusted contact' : 'Edit trusted contact',
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a phone number.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationshipController,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await CompanionBackendService.saveTrustedContact(
                mainUserId,
                id: existing?['id'] as String?,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim().isEmpty
                    ? null
                    : emailController.text.trim(),
                relationship: relationshipController.text.trim().isEmpty
                    ? null
                    : relationshipController.text.trim(),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSafeZoneDialog(
    BuildContext context,
    String mainUserId, {
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final latController = TextEditingController(
      text: ((existing?['lat'] as num?)?.toDouble() ?? 0).toString(),
    );
    final lngController = TextEditingController(
      text: ((existing?['lng'] as num?)?.toDouble() ?? 0).toString(),
    );
    final radiusController = TextEditingController(
      text: ((existing?['radius'] as num?)?.toDouble() ?? 150).toString(),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add safe zone' : 'Edit safe zone'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Zone name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a zone name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Enter latitude.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lngController,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Enter longitude.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Enter radius.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await CompanionBackendService.saveSafeZone(
                mainUserId,
                id: existing?['id'] as String?,
                name: nameController.text.trim(),
                lat: double.parse(latController.text.trim()),
                lng: double.parse(lngController.text.trim()),
                radius: double.parse(radiusController.text.trim()),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ActivityPage extends StatelessWidget {
  final LinkedMainAccount account;

  const _ActivityPage({required this.account});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _SectionCard(
          title: 'Activity history',
          icon: Icons.history_rounded,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: CompanionBackendService.watchActivity(account.mainUserId),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return const Text(
                  'No companion activity has been recorded yet.',
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.bolt_rounded),
                        ),
                        title: Text(item['summary'] as String? ?? 'Activity'),
                        subtitle: Text(
                          '${item['type'] ?? 'event'} • ${_formatTimestamp(item['createdAt'])}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Check-in timeline',
          icon: Icons.fact_check_rounded,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: CompanionBackendService.watchCheckIns(account.mainUserId),
            builder: (context, snapshot) {
              final checkIns = snapshot.data ?? const <Map<String, dynamic>>[];
              if (checkIns.isEmpty) {
                return const Text('No check-ins have been created yet.');
              }
              return Column(
                children: checkIns
                    .take(12)
                    .map(
                      (checkIn) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.schedule_send_rounded),
                        ),
                        title: Text(
                          checkIn['message'] as String? ?? 'Check-in',
                        ),
                        subtitle: Text(
                          '${checkIn['status'] ?? 'pending'} • ${_formatTimestamp(checkIn['scheduledFor'])}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 24,
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  final String label;

  const _LoadingScaffold({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PastelBackground(
        child: Center(
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTimestamp(dynamic value) {
  Timestamp? timestamp;
  if (value is Timestamp) {
    timestamp = value;
  } else if (value is Map<String, dynamic> && value['seconds'] is int) {
    timestamp = Timestamp(
      value['seconds'] as int,
      value['nanoseconds'] as int? ?? 0,
    );
  }
  if (timestamp == null) return 'Pending sync';
  return DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate());
}
