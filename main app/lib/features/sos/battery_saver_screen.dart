import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatterySaverScreen extends StatefulWidget {
  const BatterySaverScreen({super.key});
  @override
  State<BatterySaverScreen> createState() => _BatterySaverScreenState();
}

class _BatterySaverScreenState extends State<BatterySaverScreen> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _enabled = prefs.getBool('battery_mode') ?? false);
  }

  Future<void> _toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_mode', v);
    setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Saver SOS Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enable Battery Saver Mode'),
              subtitle: const Text(
                'Runs only tracking + SOS with minimal UI to reduce battery consumption.',
              ),
              value: _enabled,
              onChanged: _toggle,
            ),
            const SizedBox(height: 16),
            const Text('When enabled:'),
            const SizedBox(height: 8),
            const Text(
              '• Reduces sensor usage (shake/impact).\n• Keeps location updates and SOS active.\n• Disables background UI refresh.',
            ),
          ],
        ),
      ),
    );
  }
}
