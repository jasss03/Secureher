import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../services/companion_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccessibilityModel>();
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// --- USER INFO CARD ---
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      (user?.displayName?.isNotEmpty ?? false)
                          ? user!.displayName!.characters.first.toUpperCase()
                          : 'U',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Your Name',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.phoneNumber ?? user?.email ?? 'No contact info',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit name',
                    onPressed: () async {
                      final newName = await showDialog<String>(
                        context: context,
                        builder: (_) =>
                            _EditNameDialog(current: user?.displayName ?? ''),
                      );
                      if (newName != null && newName.trim().isNotEmpty) {
                        await user?.updateDisplayName(newName.trim());
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// --- EMERGENCY CONTACTS ---
          ListTile(
            leading: const Icon(Icons.people_alt_rounded),
            title: const Text('Trusted Contacts'),
            subtitle: const Text('Add or manage emergency contacts'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pushNamed(context, '/trustedContacts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text('Safe Zones'),
            subtitle: const Text('Configure areas where alerts are silent'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pushNamed(context, '/safeZones');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_input_component_rounded),
            title: const Text('Motion Detection Sensitivity'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pushNamed(context, '/motionSettings');
            },
          ),

          ListTile(
            leading: const Icon(Icons.phone_android_rounded),
            title: const Text('Companion App'),
            subtitle: const Text('Link and manage companion devices'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pushNamed(context, '/companionManager');
            },
          ),

          const Divider(height: 32),

          /// --- SAFETY & MONITORING ---
          Text(
            'Safety & Monitoring',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.directions_walk_rounded),
            title: const Text('Travel Alone Mode'),
            subtitle: const Text(
              'PASSIVELY monitors audio for distress keywords in the background. If a keyword is detected, SOS triggers automatically.',
            ),
            value: acc.travelAloneMode,
            onChanged: (v) => acc.toggleTravelAlone(v),
          ),

          const Divider(height: 32),

          /// --- ACCESSIBILITY / PREFERENCES ---
          Text(
            'Accessibility & Preferences',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
          SwitchListTile(
            title: const Text('Large text'),
            value: acc.largeText,
            onChanged: (v) => acc.toggleLargeText(v),
          ),
          SwitchListTile(
            title: const Text('High contrast'),
            value: acc.highContrast,
            onChanged: (v) => acc.toggleHighContrast(v),
          ),
          SwitchListTile(
            title: const Text('Voice guidance'),
            value: acc.voiceGuidance,
            onChanged: (v) => acc.toggleVoiceGuidance(v),
          ),
          SwitchListTile(
            title: const Text('Accessory'),
            subtitle: const Text('Enable accessory features'),
            value: acc.accessoryEnabled ?? false,
            onChanged: (v) => acc.toggleAccessory(v),
          ),

          const Divider(height: 32),

          /// --- LOGOUT BUTTON ---
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              // Clear local session
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('userUid');
                await prefs.remove('idToken');
              } catch (_) {}
              // Sign out Firebase (and Google if needed)
              try {
                await CompanionService().syncDeviceState({'online': false});
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String current;
  const _EditNameDialog({required this.current});
  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          decoration: const InputDecoration(labelText: 'Full name'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate())
              Navigator.of(context).pop(_ctrl.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
