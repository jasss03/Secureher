import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/branding.dart';

class MotionSettingsScreen extends StatefulWidget {
  const MotionSettingsScreen({super.key});
  @override
  State<MotionSettingsScreen> createState() => _MotionSettingsScreenState();
}

class _MotionSettingsScreenState extends State<MotionSettingsScreen> {
  double _sensitivity = 1.5;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sensitivity = prefs.getDouble('motion_sensitivity') ?? 1.5;
      _loading = false;
    });
  }

  Future<void> _saveSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('motion_sensitivity', _sensitivity);
  }

  String get _sensitivityText {
    if (_sensitivity < 1.0) return 'Very Low';
    if (_sensitivity < 1.3) return 'Low';
    if (_sensitivity < 1.7) return 'Medium';
    if (_sensitivity < 2.0) return 'High';
    return 'Very High';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Motion Detection Sensitivity')),
      body: PastelBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Shake and Impact Detection',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adjust how sensitive the app is to motion. Higher values trigger alerts more easily.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _sensitivityText,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          Slider(
                            value: _sensitivity,
                            min: 0.5,
                            max: 3.0,
                            divisions: 10,
                            onChanged: (v) => setState(() => _sensitivity = v),
                            onChangeEnd: (_) => _saveSetting(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Less Sensitive',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'More Sensitive',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              Icon(Icons.info_outline_rounded),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Changes take effect immediately. Test by gently shaking your device.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
