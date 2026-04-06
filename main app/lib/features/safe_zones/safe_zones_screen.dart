import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/branding.dart';
import '../../services/safe_zone_service.dart';
import '../../services/location_service.dart';

class SafeZonesScreen extends StatefulWidget {
  const SafeZonesScreen({super.key});
  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  final _svc = SafeZoneService();
  final _loc = LocationService();
  List<SafeZone> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final z = await _svc.getZones();
    setState(() {
      _zones = z;
      _loading = false;
    });
  }

  Future<void> _addZone() async {
    final pos = await _loc.getCurrentPosition();
    if (!mounted) return;
    final res = await showDialog<SafeZone>(
      context: context,
      builder: (_) => _AddZoneDialog(current: pos),
    );
    if (res != null) {
      await _svc.addZone(res);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Zones')),
      body: PastelBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _addZone,
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Add Zone'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _zones.isEmpty
                    ? const Center(
                        child: Text(
                          'No safe zones yet. Add home/office or a custom place.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: _zones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final z = _zones[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: ListTile(
                              leading: const Icon(Icons.shield_rounded),
                              title: Text(z.name),
                              subtitle: Text(
                                'Lat: ${z.lat.toStringAsFixed(5)}, Lng: ${z.lng.toStringAsFixed(5)} • R ${z.radiusMeters.toStringAsFixed(0)}m',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  await _svc.removeZone(z.id);
                                  await _load();
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddZoneDialog extends StatefulWidget {
  final Position? current;
  const _AddZoneDialog({required this.current});
  @override
  State<_AddZoneDialog> createState() => _AddZoneDialogState();
}

class _AddZoneDialogState extends State<_AddZoneDialog> {
  final _name = TextEditingController(text: 'Home');
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  final _radius = TextEditingController(text: '150');
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(
      text: widget.current?.latitude.toStringAsFixed(6) ?? '0.0',
    );
    _lng = TextEditingController(
      text: widget.current?.longitude.toStringAsFixed(6) ?? '0.0',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Safe Zone'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lat,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Latitude'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lng,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longitude'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (m)'),
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final z = SafeZone(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _name.text.trim(),
                lat: double.tryParse(_lat.text.trim()) ?? 0,
                lng: double.tryParse(_lng.text.trim()) ?? 0,
                radiusMeters: double.tryParse(_radius.text.trim()) ?? 150,
              );
              Navigator.of(context).pop(z);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
