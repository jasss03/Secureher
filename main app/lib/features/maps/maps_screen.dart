import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _mapInitialized = false;
  bool _showPoliceStations = true;
  bool _showHospitals = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // API key for Google Places API
  final String _apiKey = 'YOUR_API_KEY'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay getting location to ensure widget is fully initialized
    Future.delayed(const Duration(milliseconds: 150), _getCurrentLocation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _mapInitialized) {
      // Refresh map when app is resumed
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      developer.log('Getting current location');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location services disabled');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permission denied');
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permission denied forever');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied'),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      developer.log(
        'Got position: ${position.latitude}, ${position.longitude}',
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _addMarker(position);

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _addMarker(Position position) {
    if (!mounted) return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    });

    // Fetch nearby places
    if (_showPoliceStations) {
      _fetchNearbyPlaces(position, 'police', BitmapDescriptor.hueBlue);
    }

    if (_showHospitals) {
      _fetchNearbyPlaces(position, 'hospital', BitmapDescriptor.hueRed);
    }
  }

  Future<void> _fetchNearbyPlaces(
    Position position,
    String placeType,
    double markerHue,
  ) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${position.latitude},${position.longitude}'
          '&radius=5000'
          '&type=$placeType'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final places = data['results'] as List;

          setState(() {
            for (var i = 0; i < places.length; i++) {
              final place = places[i];
              final lat = place['geometry']['location']['lat'];
              final lng = place['geometry']['location']['lng'];
              final name = place['name'];

              _markers.add(
                Marker(
                  markerId: MarkerId('${placeType}_$i'),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(title: name),
                  icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                ),
              );
            }
          });
        } else {
          developer.log('Error fetching nearby $placeType: ${data['status']}');
        }
      } else {
        developer.log(
          'Error fetching nearby $placeType: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Error fetching nearby $placeType: $e');
    }
  }

  Future<void> _searchPlaces(
    String query,
    String placeType,
    double markerHue,
  ) async {
    if (query.isEmpty || _currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=$query ${placeType == 'police' ? 'police station' : 'hospital'}'
          '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=10000'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final places = data['results'] as List;

          // Clear existing markers of this type
          setState(() {
            _markers.removeWhere(
              (marker) =>
                  marker.markerId.value.startsWith(placeType) ||
                  marker.markerId.value.startsWith('search_'),
            );

            for (var i = 0; i < places.length; i++) {
              final place = places[i];
              final lat = place['geometry']['location']['lat'];
              final lng = place['geometry']['location']['lng'];
              final name = place['name'];

              final marker = Marker(
                markerId: MarkerId('search_${placeType}_$i'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: name),
                icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
              );

              _markers.add(marker);

              // Center map on first result
              if (i == 0 && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: LatLng(lat, lng), zoom: 15),
                  ),
                );
              }
            }
          });
        } else {
          developer.log('Error searching for $placeType: ${data['status']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results found for "$query"')),
          );
        }
      } else {
        developer.log('Error searching for $placeType: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error searching for $placeType: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default position (San Francisco)
    const LatLng defaultPosition = LatLng(37.7749, -122.4194);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'My Location',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'police') {
                  _showPoliceStations = !_showPoliceStations;
                } else if (value == 'hospital') {
                  _showHospitals = !_showHospitals;
                }

                if (_currentPosition != null) {
                  _addMarker(_currentPosition!);
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'police',
                checked: _showPoliceStations,
                child: const Text('Police Stations'),
              ),
              CheckedPopupMenuItem(
                value: 'hospital',
                checked: _showHospitals,
                child: const Text('Hospitals'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : defaultPosition,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              setState(() {
                _mapController = controller;
                _mapInitialized = true;
              });

              // Refresh map when created
              if (_currentPosition != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 15,
                        ),
                      ),
                    );
                  }
                });
              }
            },
          ),
          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for police stations or hospitals',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            if (_showPoliceStations) {
                              _searchPlaces(
                                value,
                                'police',
                                BitmapDescriptor.hueBlue,
                              );
                            } else if (_showHospitals) {
                              _searchPlaces(
                                value,
                                'hospital',
                                BitmapDescriptor.hueRed,
                              );
                            } else {
                              // If neither is selected, default to police
                              _searchPlaces(
                                value,
                                'police',
                                BitmapDescriptor.hueBlue,
                              );
                            }
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        final value = _searchController.text;
                        if (value.isNotEmpty) {
                          if (_showPoliceStations) {
                            _searchPlaces(
                              value,
                              'police',
                              BitmapDescriptor.hueBlue,
                            );
                          } else if (_showHospitals) {
                            _searchPlaces(
                              value,
                              'hospital',
                              BitmapDescriptor.hueRed,
                            );
                          } else {
                            // If neither is selected, default to police
                            _searchPlaces(
                              value,
                              'police',
                              BitmapDescriptor.hueBlue,
                            );
                          }
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Search filter',
                      onSelected: (value) {
                        final searchText = _searchController.text;
                        if (searchText.isNotEmpty) {
                          if (value == 'police') {
                            _searchPlaces(
                              searchText,
                              'police',
                              BitmapDescriptor.hueBlue,
                            );
                          } else if (value == 'hospital') {
                            _searchPlaces(
                              searchText,
                              'hospital',
                              BitmapDescriptor.hueRed,
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a search term'),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'police',
                          child: Text('Search Police Stations'),
                        ),
                        const PopupMenuItem(
                          value: 'hospital',
                          child: Text('Search Hospitals'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Legend for map markers
          Positioned(
            left: 16,
            bottom: 100,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('Your Location'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Police Stations'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Text('Hospitals'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_mapController != null) {
            final target = _currentPosition != null
                ? LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  )
                : defaultPosition;

            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: target, zoom: 15),
              ),
            );
          }
        },
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}
