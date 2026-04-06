import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';
import '../../services/alert_service.dart';
import '../../services/routing_service.dart';

class RouteGuardScreen extends StatefulWidget {
  const RouteGuardScreen({super.key});

  @override
  State<RouteGuardScreen> createState() => _RouteGuardScreenState();
}

class RouteOption {
  final String name;
  final String description;
  final int durationMinutes;
  final double safetyScore;
  final bool isRecommended;
  final List<LatLng> polylinePoints;

  RouteOption({
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.safetyScore,
    required this.polylinePoints,
    this.isRecommended = false,
  });
}

class _RouteGuardScreenState extends State<RouteGuardScreen> {
  final _destAddressController = TextEditingController();
  final _destLat = TextEditingController();
  final _destLng = TextEditingController();
  final _etaMin = TextEditingController(text: '30');
  final _loc = LocationService();
  final _alerts = AlertService();
  StreamSubscription<Position>? _sub;
  Position? _start;
  Position? _current;
  double? _minDistToDest;
  bool _active = false;
  bool _isLoading = false;
  bool _showRouteOptions = false;
  DateTime? _deadline;
  String? _status;
  String? _alertId;
  String? _currentAddress;
  String? _destinationAddress;
  final RoutingService _routing = RoutingService();
  final MapController _flutterMapController = MapController();
  bool _mapInitialized = false;
  int _selectedRouteIndex = 0;
  List<RouteOption> _routeOptions = [];

  // Helper: convert google_maps_flutter LatLng -> latlong2 LatLng for display
  ll.LatLng _ll(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    _getCurrentLocationWithAddress();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _destAddressController.dispose();
    _destLat.dispose();
    _destLng.dispose();
    _etaMin.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationWithAddress() async {
    setState(() => _isLoading = true);
    try {
      final position = await _loc.getCurrentPosition();
      if (position != null) {
        _current = position;

        // Get address from coordinates
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _currentAddress =
                '${place.street}, ${place.locality}, ${place.postalCode}';
          }
        } catch (e) {
          _currentAddress = 'Address unavailable';
        }

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchDestination() async {
    final address = _destAddressController.text.trim();
    if (address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a destination address')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        _destLat.text = location.latitude.toString();
        _destLng.text = location.longitude.toString();
        _destinationAddress = address;

        // Generate route options
        await _generateRouteOptions(location.latitude, location.longitude);

        setState(() => _showRouteOptions = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not find location. Please try a different address.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('API Key Restricted')
            ? 'API Key Restriction: Please ensure "Directions API" and "Maps SDK for iOS" are authorized for bundle ID "com.secureher.secureher" in Google Cloud Console.'
            : 'Error searching location: $e';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateRouteOptions(double destLat, double destLng) async {
    if (_current == null) return;

    setState(() => _isLoading = true);
    try {
      final start = LatLng(_current!.latitude, _current!.longitude);
      final end = LatLng(destLat, destLng);
      
      final results = await _routing.getRouteOptions(start, end);
      
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No routes found between these locations.')),
          );
        }
        return;
      }

      _routeOptions = results.map((r) => RouteOption(
        name: r.name,
        description: r.safetyReason,
        durationMinutes: r.durationMinutes,
        safetyScore: r.safetyScore,
        polylinePoints: r.polylinePoints,
        isRecommended: r.isSafest,
      )).toList();

      _selectedRouteIndex = 0;
      _updateMapLayers();
    } catch (e) {
      // Route generation failed silently for user safety
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateMapLayers() {
    if (_routeOptions.isEmpty) return;
    
    final selected = _routeOptions[_selectedRouteIndex];
    setState(() {}); // flutter_map reads directly from _routeOptions
    _fitMapToPolyline(selected.polylinePoints);
  }

  void _fitMapToPolyline(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    _flutterMapController.move(ll.LatLng(centerLat, centerLng), 13);
  }

  Future<void> _startTrip() async {
    final lat = double.tryParse(_destLat.text.trim());
    final lng = double.tryParse(_destLng.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid destination lat/lng')),
      );
      return;
    }

    final eta = int.tryParse(_etaMin.text.trim()) ?? 30;
    _deadline = DateTime.now().add(Duration(minutes: eta));

    _start = await _loc.getCurrentPosition();
    if (_start == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location unavailable')));
      }
      return;
    }

    // Send initial trip alert (non-SOS display) to contacts
    try {
      final msg = 'Started a monitored trip to ${_destinationAddress ?? "$lat,$lng"}. Tracking started.';
      final res = await _alerts.startSosSession(
        position: _start,
        customMessage: msg,
        type: 'trip',
      );
      _alertId = res.alertId;
    } catch (e) {
      debugPrint('Trip alert failed: $e');
    }

    setState(() {
      _active = true;
      _showRouteOptions = false;
      _status = 'Tracking live...';
    });

    _sub?.cancel();
    _sub = _loc.watchPosition().listen((p) {
      _current = p;
      final dist = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        lat,
        lng,
      );
      
      // Update live destination in Firestore
      if (_alertId != null) {
        _alerts.updateLiveLocation(_alertId!, p);
      }

      _minDistToDest = _minDistToDest == null
          ? dist
          : math.min(_minDistToDest!, dist);

      final offRoute = _isOffRoute(_start!, lat, lng, p);
      String s = 'Distance: ${(dist / 1000).toStringAsFixed(1)} km';
      if (offRoute) s += ' • Off route';
      if (DateTime.now().isAfter(_deadline!)) s += ' • Late';
      setState(() => _status = s);

      // Auto-recenter map during trip
      _flutterMapController.move(ll.LatLng(p.latitude, p.longitude), 15);

      if (offRoute || DateTime.now().isAfter(_deadline!)) {
        _sendDeviationAlert(dist, offRoute);
      }

      if (dist < 100) { // 100m proximity
        _finishTrip(arrived: true);
      }
    });
  }

  bool _isOffRoute(
    Position start,
    double destLat,
    double destLng,
    Position point,
  ) {
    // Equirectangular projection for small distances
    const R = 6371000.0; // meters
    final lat0 = start.latitude * math.pi / 180;
    final x1 = (destLng - start.longitude) * math.pi / 180 * math.cos(lat0) * R;
    final y1 = (destLat - start.latitude) * math.pi / 180 * R;
    final x =
        (point.longitude - start.longitude) *
        math.pi /
        180 *
        math.cos(lat0) *
        R;
    final y = (point.latitude - start.latitude) * math.pi / 180 * R;

    final segLen2 = x1 * x1 + y1 * y1;
    if (segLen2 == 0) return false;
    final t = ((x * x1 + y * y1) / segLen2).clamp(0.0, 1.0);
    final projX = t * x1;
    final projY = t * y1;
    final dx = x - projX;
    final dy = y - projY;
    final crossTrack = math.sqrt(dx * dx + dy * dy); // meters from path
    return crossTrack > 300; // 300m off the straight route
  }

  Future<void> _sendDeviationAlert(double dist, bool offRoute) async {
    if (_alertId != null) {
      try {
        await _alerts.updateLiveLocation(_alertId!, _current!);
      } catch (_) {}
    }
    try {
      await _alerts.startSosSession(
        position: _current,
        customMessage: offRoute
            ? 'Alert: I appear to be off my selected route.'
            : 'Alert: I have not reached my destination in time (current distance ${dist.toStringAsFixed(0)} m).',
      );
    } catch (_) {}
  }

  Future<void> _finishTrip({bool arrived = false}) async {
    await _sub?.cancel();
    setState(() {
      _active = false;
      _status = arrived ? 'Arrived at destination.' : 'Trip ended.';
    });
    if (_alertId != null) {
      try {
        await _alerts.closeSosSession(_alertId!, position: _current);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Route Guard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current location card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.my_location,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Your Current Location',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_current != null) ...[
                            Text(
                              _currentAddress ?? 'Address unavailable',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GPS: ${_current!.latitude.toStringAsFixed(5)}, ${_current!.longitude.toStringAsFixed(5)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ] else
                            const Text('Location unavailable'),
                        ],
                      ),
                    ),
                  ),

                  // Destination input
                  if (!_active) ...[
                    Text(
                      'Enter Destination',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _destAddressController,
                      decoration: InputDecoration(
                        labelText: 'Destination Address',
                        hintText: 'Enter street, city, etc.',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _searchDestination,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Map view
                    if (_current != null)
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: _flutterMapController,
                            options: MapOptions(
                              initialCenter: ll.LatLng(
                                _current!.latitude,
                                _current!.longitude,
                              ),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.secureher.secureher',
                                maxZoom: 19,
                              ),
                              // Polylines (selected route)
                              if (_routeOptions.isNotEmpty && _routeOptions.length > _selectedRouteIndex)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routeOptions[_selectedRouteIndex]
                                          .polylinePoints
                                          .map(_ll)
                                          .toList(),
                                      color: Colors.deepPurple,
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                              // Markers
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: ll.LatLng(
                                      _current!.latitude,
                                      _current!.longitude,
                                    ),
                                    width: 36,
                                    height: 36,
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.blue,
                                      size: 28,
                                    ),
                                  ),
                                  if (_start != null)
                                    Marker(
                                      point: ll.LatLng(
                                        _start!.latitude,
                                        _start!.longitude,
                                      ),
                                      width: 36,
                                      height: 36,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.green,
                                        size: 36,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Route options
                  if (_showRouteOptions && !_active) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Suggested Routes',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_routeOptions.length, (index) {
                      final route = _routeOptions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: route.isRecommended
                            ? theme.colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedRouteIndex = index);
                            _updateMapLayers();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions,
                                      color: route.isRecommended
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      route.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: route.isRecommended
                                                ? FontWeight.bold
                                                : null,
                                          ),
                                    ),
                                    if (route.isRecommended) ...[
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: const Text('RECOMMENDED'),
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        labelStyle: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 10,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(route.description),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${route.durationMinutes} min'),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.shield,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('Safety: ${route.safetyScore}/10'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _startTrip,
                        icon: const Icon(Icons.navigation),
                        label: const Text('START PROTECTED TRIP'),
                      ),
                    ),
                  ],

                  // Active trip status
                  if (_active) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_walk,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Trip in Progress',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Live Trip Map View
                            if (_current != null)
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FlutterMap(
                                    mapController: _flutterMapController,
                                    options: MapOptions(
                                      initialCenter: ll.LatLng(
                                        _current!.latitude,
                                        _current!.longitude,
                                      ),
                                      initialZoom: 15,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.secureher.secureher',
                                        maxZoom: 19,
                                      ),
                                      if (_routeOptions.isNotEmpty && _routeOptions.length > _selectedRouteIndex)
                                        PolylineLayer(
                                          polylines: [
                                            Polyline(
                                              points: _routeOptions[_selectedRouteIndex]
                                                  .polylinePoints
                                                  .map(_ll)
                                                  .toList(),
                                              color: Colors.deepPurple,
                                              strokeWidth: 4,
                                            ),
                                          ],
                                        ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: ll.LatLng(
                                              _current!.latitude,
                                              _current!.longitude,
                                            ),
                                            width: 40,
                                            height: 40,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _status ?? '—',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_current != null)
                              Text(
                                'Current Location: ${_currentAddress ?? "${_current!.latitude.toStringAsFixed(4)}, ${_current!.longitude.toStringAsFixed(4)}"}',
                                style: theme.textTheme.bodySmall,
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _finishTrip(arrived: false),
                                icon: const Icon(Icons.stop_circle),
                                label: const Text('END TRIP'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  if (!_active && !_showRouteOptions) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _searchDestination,
                        icon: const Icon(Icons.search),
                        label: const Text('SEARCH DESTINATION'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
