import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';

// ─── Category ────────────────────────────────────────────────────────────────
enum PlaceCategory {
  police,
  hospital,
  ngo,
  safeSpace,
}

extension PlaceCategoryExt on PlaceCategory {
  String get label {
    switch (this) {
      case PlaceCategory.police:    return 'Police';
      case PlaceCategory.hospital:  return 'Hospital';
      case PlaceCategory.ngo:       return 'NGO / Support';
      case PlaceCategory.safeSpace: return 'Safe Places';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.police:    return Icons.local_police;
      case PlaceCategory.hospital:  return Icons.local_hospital;
      case PlaceCategory.ngo:       return Icons.volunteer_activism;
      case PlaceCategory.safeSpace: return Icons.store;
    }
  }

  Color get color {
    switch (this) {
      case PlaceCategory.police:    return const Color(0xFF1565C0); // deep blue
      case PlaceCategory.hospital:  return const Color(0xFFC62828); // deep red
      case PlaceCategory.ngo:       return const Color(0xFF2E7D32); // deep green
      case PlaceCategory.safeSpace: return const Color(0xFFE65100); // deep orange
    }
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────
class SafePlace {
  final String name;
  final PlaceCategory category;
  final double lat;
  final double lng;
  final double distanceMeters;
  final String? phone;
  final String? address;
  final String? openingHours;

  SafePlace({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.phone,
    this.address,
    this.openingHours,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class SafeSpaceFinderScreen extends StatefulWidget {
  const SafeSpaceFinderScreen({super.key});

  @override
  State<SafeSpaceFinderScreen> createState() => _SafeSpaceFinderScreenState();
}

class _SafeSpaceFinderScreenState extends State<SafeSpaceFinderScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isFetching = false;
  Map<PlaceCategory, List<SafePlace>> _places = {};
  PlaceCategory _selectedCategory = PlaceCategory.police;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        setState(() { _isLoading = false; _error = 'Could not get location. Allow location access.'; });
        return;
      }
      setState(() { _currentPosition = pos; _isLoading = false; });
      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 14);
      await _fetchAll(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Location error: $e'; });
    }
  }

  Future<void> _fetchAll(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isFetching = true);

    const r = 10000; // 10 km radius
    final query = '''
[out:json][timeout:30];
(
  node["amenity"="police"](around:$r,$lat,$lng);
  way["amenity"="police"](around:$r,$lat,$lng);
  node["amenity"="hospital"](around:$r,$lat,$lng);
  way["amenity"="hospital"](around:$r,$lat,$lng);
  node["amenity"="clinic"](around:$r,$lat,$lng);
  node["amenity"="doctors"](around:$r,$lat,$lng);
  node["amenity"="pharmacy"](around:$r,$lat,$lng);
  node["office"="ngo"](around:$r,$lat,$lng);
  way["office"="ngo"](around:$r,$lat,$lng);
  node["office"="association"](around:$r,$lat,$lng);
  node["amenity"="social_facility"](around:$r,$lat,$lng);
  way["amenity"="social_facility"](around:$r,$lat,$lng);
  node["amenity"="community_centre"](around:$r,$lat,$lng);
  node["amenity"="hotel"](around:$r,$lat,$lng);
  way["amenity"="hotel"](around:$r,$lat,$lng);
  node["tourism"="hotel"](around:$r,$lat,$lng);
  node["amenity"="restaurant"](around:$r,$lat,$lng);
  node["amenity"="cafe"](around:$r,$lat,$lng);
  node["amenity"="fast_food"](around:$r,$lat,$lng);
  node["shop"="mall"](around:$r,$lat,$lng);
);
out center tags;
''';

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() => _isFetching = false);
        return;
      }

      final data = json.decode(response.body);
      final elements = (data['elements'] as List?) ?? [];

      final Map<PlaceCategory, List<SafePlace>> result = {
        for (final c in PlaceCategory.values) c: []
      };

      for (final el in elements) {
        double? eLat, eLng;
        if (el['type'] == 'node') {
          eLat = (el['lat'] as num?)?.toDouble();
          eLng = (el['lon'] as num?)?.toDouble();
        } else if (el['center'] != null) {
          eLat = (el['center']['lat'] as num?)?.toDouble();
          eLng = (el['center']['lon'] as num?)?.toDouble();
        }
        if (eLat == null || eLng == null) continue;

        final tags = (el['tags'] as Map?) ?? {};
        final amenity  = tags['amenity']?.toString() ?? '';
        final office   = tags['office']?.toString() ?? '';
        final tourism  = tags['tourism']?.toString() ?? '';
        final shop     = tags['shop']?.toString() ?? '';
        final name     = tags['name']?.toString() ??
            tags['name:en']?.toString() ??
            tags['operator']?.toString() ?? '';
        if (name.isEmpty) continue;

        PlaceCategory? cat;
        if (amenity == 'police') {
          cat = PlaceCategory.police;
        } else if (['hospital', 'clinic', 'doctors', 'pharmacy'].contains(amenity)) {
          cat = PlaceCategory.hospital;
        } else if (office == 'ngo' ||
            office == 'association' ||
            amenity == 'social_facility' ||
            amenity == 'community_centre') {
          cat = PlaceCategory.ngo;
        } else if (['hotel', 'restaurant', 'cafe', 'fast_food'].contains(amenity) ||
            tourism == 'hotel' ||
            shop == 'mall') {
          cat = PlaceCategory.safeSpace;
        }

        if (cat == null) continue;

        final dist = _haversine(lat, lng, eLat, eLng);
        result[cat]!.add(SafePlace(
          name: name,
          category: cat,
          lat: eLat,
          lng: eLng,
          distanceMeters: dist,
          phone: tags['phone']?.toString() ?? tags['contact:phone']?.toString(),
          address: _buildAddress(tags),
          openingHours: tags['opening_hours']?.toString(),
        ));
      }

      // Sort each category by distance, cap at 20
      for (final cat in PlaceCategory.values) {
        result[cat]!.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        if (result[cat]!.length > 20) result[cat] = result[cat]!.sublist(0, 20);
      }

      setState(() { _places = result; _isFetching = false; });
    } catch (e) {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  String? _buildAddress(Map tags) {
    final parts = <String>[];
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber'].toString());
    if (tags['addr:street'] != null) parts.add(tags['addr:street'].toString());
    if (tags['addr:city'] != null) parts.add(tags['addr:city'].toString());
    return parts.isEmpty ? null : parts.join(', ');
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  List<SafePlace> get _visible => _places[_selectedCategory] ?? [];

  void _navigate(SafePlace s) async {
    final uri = Uri.parse(
        'https://maps.google.com/?daddr=${s.lat},${s.lng}&dirflg=d');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _currentPosition != null
        ? ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const ll.LatLng(28.6139, 77.2090);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Space Finder'),
        actions: [
          if (_isFetching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _init,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Category chips ──────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: PlaceCategory.values.map((cat) {
                final selected = cat == _selectedCategory;
                final count = _places[cat]?.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    avatar: Icon(cat.icon,
                        size: 16,
                        color: selected ? Colors.white : cat.color),
                    label: Text(
                      '${cat.label}${count > 0 ? ' ($count)' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : null,
                          fontWeight: selected ? FontWeight.bold : null),
                    ),
                    selectedColor: cat.color,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Map ────────────────────────────────────────────────────────
          Expanded(
            flex: 50,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.secureher.secureher',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        // User location
                        if (_currentPosition != null)
                          Marker(
                            point: ll.LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2)
                                ],
                              ),
                              child: const Icon(Icons.person_pin,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        // Category places
                        ..._visible.map((s) => Marker(
                              point: ll.LatLng(s.lat, s.lng),
                              width: 38,
                              height: 38,
                              child: GestureDetector(
                                onTap: () => _showDetail(s),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: s.category.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: s.category.color
                                              .withOpacity(0.4),
                                          blurRadius: 6,
                                          spreadRadius: 1)
                                    ],
                                  ),
                                  child: Icon(s.category.icon,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child:
                        const Center(child: CircularProgressIndicator()),
                  ),
                // Re-centre FAB
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'center_btn',
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController.move(
                          ll.LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          14,
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            flex: 50,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        Icon(_selectedCategory.icon,
                            color: _selectedCategory.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Nearby ${_selectedCategory.label}',
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _selectedCategory.color),
                        ),
                        if (_isFetching) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _selectedCategory.color)),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Colors.red, size: 36),
                                      const SizedBox(height: 8),
                                      Text(_error!,
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: _init,
                                          child: const Text('Retry')),
                                    ],
                                  ),
                                ),
                              )
                            : _visible.isEmpty && !_isFetching
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_selectedCategory.icon,
                                            size: 40,
                                            color: Colors.grey.shade300),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No ${_selectedCategory.label} found within 10 km',
                                          style: TextStyle(
                                              color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    itemCount: _visible.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final s = _visible[i];
                                      return ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              s.category.color,
                                          radius: 18,
                                          child: Icon(s.category.icon,
                                              color: Colors.white,
                                              size: 18),
                                        ),
                                        title: Text(s.name,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        subtitle: Row(children: [
                                          Icon(Icons.near_me,
                                              size: 11,
                                              color:
                                                  Colors.grey.shade500),
                                          const SizedBox(width: 2),
                                          Text(s.distanceLabel,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors
                                                      .grey.shade600)),
                                          if (s.openingHours != null) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.access_time,
                                                size: 11,
                                                color:
                                                    Colors.grey.shade500),
                                            const SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                s.openingHours!,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors
                                                        .grey.shade600),
                                              ),
                                            ),
                                          ],
                                        ]),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (s.phone != null)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.phone,
                                                    color: Colors.green,
                                                    size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32),
                                                onPressed: () =>
                                                    _call(s.phone!),
                                              ),
                                            IconButton(
                                              icon: Icon(Icons.directions,
                                                  color:
                                                      s.category.color,
                                                  size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32),
                                              onPressed: () =>
                                                  _navigate(s),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          _mapController.move(
                                              ll.LatLng(s.lat, s.lng),
                                              16);
                                        },
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(SafePlace s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  backgroundColor: s.category.color,
                  child:
                      Icon(s.category.icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(s.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 14),
            _detailRow(Icons.near_me, s.distanceLabel),
            if (s.address != null)
              _detailRow(Icons.location_on, s.address!),
            if (s.phone != null)
              _detailRow(Icons.phone, s.phone!),
            if (s.openingHours != null)
              _detailRow(Icons.access_time, s.openingHours!),
            const SizedBox(height: 20),
            Row(children: [
              if (s.phone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _call(s.phone!);
                    },
                  ),
                ),
              if (s.phone != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: s.category.color),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _navigate(s);
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14))),
        ]),
      );
}
