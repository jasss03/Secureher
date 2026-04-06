import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _verificationId;
  String? _error;
  bool _sending = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    await AuthService().startPhoneVerification(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (id) => setState(() {
        _verificationId = id;
        _sending = false;
      }),
      onError: (msg) => setState(() {
        _error = msg;
        _sending = false;
      }),
      onVerified: (_) {
        // Auto-verified
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
    );
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_verificationId == null) {
      setState(() {
        _error = 'Verification not started yet. Please wait or resend.';
      });
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AuthService().verifyCode(
        verificationId: _verificationId!,
        smsCode: _codeCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid code or verification failed.';
      });
    } finally {
      setState(() {
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('We sent a code to', style: theme.textTheme.titleMedium),
                Text(
                  widget.phoneNumber,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_sending) const LinearProgressIndicator(minHeight: 4),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter 6-digit code',
                    ),
                    maxLength: 6,
                    validator: (v) => (v == null || v.length != 6)
                        ? 'Enter the 6-digit code'
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _start,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Resend'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _verifying ? null : _verify,
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Verify'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
