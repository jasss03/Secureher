import 'package:flutter/material.dart';
import 'package:secureher_companion/services/connectivity_service.dart';
import 'package:secureher_companion/features/sos/sos_dashboard.dart';

class AppLinkingScreen extends StatefulWidget {
  const AppLinkingScreen({super.key});

  @override
  State<AppLinkingScreen> createState() => _AppLinkingScreenState();
}

class _AppLinkingScreenState extends State<AppLinkingScreen> {
  final TextEditingController _linkCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingLink();
  }

  Future<void> _checkExistingLink() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isLinked = await ConnectivityService.isLinkedWithMainApp();
      if (isLinked) {
        // If already linked, navigate to dashboard
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SosDashboard()),
          );
        }
      }
    } catch (e) {
      print('Error checking existing link: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkWithMainApp() async {
    final linkCode = _linkCodeController.text.trim();
    if (linkCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a link code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ConnectivityService.linkWithMainApp(linkCode);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SosDashboard()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to link with main app: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link with SecureHer'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.link_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Link with SecureHer App',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter the link code from the SecureHer app to connect this companion app.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _linkCodeController,
                    decoration: InputDecoration(
                      labelText: 'Link Code',
                      hintText: 'Enter the code from the main app',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.code),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _linkWithMainApp(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _linkWithMainApp,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Link Apps'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // For demo purposes, navigate to dashboard without linking
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SosDashboard()),
                      );
                    },
                    child: const Text('Continue without linking (Demo)'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _linkCodeController.dispose();
    super.dispose();
  }
}
