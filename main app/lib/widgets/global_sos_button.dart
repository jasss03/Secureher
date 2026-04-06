import 'package:flutter/material.dart';
import '../services/siren_service.dart';

class GlobalSosButton extends StatelessWidget {
  const GlobalSosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const _SosQuickSheet()));
      },
      label: const Text('SOS'),
      icon: const Icon(Icons.emergency_rounded),
    );
  }
}

class _SosQuickSheet extends StatelessWidget {
  const _SosQuickSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.2),
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Emergency Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to full SOS screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _SosScreenShortcut(),
                    ),
                  );
                },
                icon: const Icon(Icons.radio_button_checked_rounded),
                label: const Text('One-Tap SOS'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  // Toggle siren
                  // Using a local instance for simplicity
                  // In production, share one via provider
                  final siren = SirenHolder.instance;
                  if (siren.on) {
                    await siren.stop();
                  } else {
                    await siren.play();
                  }
                },
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Loud Siren'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  // Trigger fake call
                },
                icon: const Icon(Icons.call_rounded),
                label: const Text('Fake Call'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Minimal inline SOS page shortcut to avoid route table dependency.
class SirenHolder {
  SirenHolder._();
  static final SirenHolder instance = SirenHolder._();
  final SirenService _svc = SirenService();
  bool on = false;
  Future<void> play() async {
    await _svc.play();
    on = true;
  }

  Future<void> stop() async {
    await _svc.stop();
    on = false;
  }
}

class _SosScreenShortcut extends StatelessWidget {
  const _SosScreenShortcut();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.radio_button_checked_rounded),
          label: const Text('ONE-TAP SOS'),
        ),
      ),
    );
  }
}
