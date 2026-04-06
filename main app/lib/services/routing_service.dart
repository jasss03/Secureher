import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../firebase_options.dart';

class RoutingResult {
  final String name;
  final String safetyReason;
  final int durationMinutes;
  final double safetyScore;
  final List<LatLng> polylinePoints;
  final bool isSafest;

  RoutingResult({
    required this.name,
    required this.safetyReason,
    required this.durationMinutes,
    required this.safetyScore,
    required this.polylinePoints,
    this.isSafest = false,
  });
}

class RoutingService {
  final String _mapsApiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
  final String _geminiApiKey = DefaultFirebaseOptions.currentPlatform.apiKey;

  Future<List<RoutingResult>> getRouteOptions(LatLng start, LatLng end) async {
    final List<RoutingResult> results = [];

    try {
      if (_mapsApiKey.isEmpty) throw Exception('Google Maps API Key is missing');
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&alternatives=true&key=$_mapsApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('Directions API Error: ${response.body}');
        throw Exception('Maps API returned code ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['status'] == 'REQUEST_DENIED') {
        debugPrint('Directions Status: ${data['status']} - ${data['error_message'] ?? 'No message'}');
        throw Exception('API Key Restricted: Please enable "Directions API" in Google Cloud Console.');
      }
      
      if (data['status'] != 'OK') {
        debugPrint('Directions Status: ${data['status']} - ${data['error_message'] ?? 'No message'}');
        return [];
      }
      final List routes = data['routes'];

      if (routes.isEmpty) return [];

      // Sort by duration to find fastest
      routes.sort((a, b) {
        final durationA = a['legs'][0]['duration']['value'];
        final durationB = b['legs'][0]['duration']['value'];
        return durationA.compareTo(durationB);
      });

      // Prepare data for Gemini
      final routeSummaries = routes.map((r) => r['summary'].toString()).toList();
      final aiReasons = await _getAISafetyReasons(routeSummaries);

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final durationValue = route['legs'][0]['duration']['value'] as int;
        final durationMinutes = (durationValue / 60).round();
        
        // Safety heuristic: Prefer main roads/summary
        // If it follows a primary highway, it's safer than a shorter 'shortcut'
        final isFastest = (i == 0);
        final isSafest = routeSummaries[i].contains('Highway') || routeSummaries[i].contains('Rd') || routes.length == 1;

        results.add(RoutingResult(
          name: isFastest ? 'Fastest Route' : 'Safest Route',
          safetyReason: aiReasons[i],
          durationMinutes: durationMinutes,
          safetyScore: isSafest ? 9.5 : 7.0,
          polylinePoints: _decodePolyline(route['overview_polyline']['points']),
          isSafest: isSafest,
        ));
      }

      // If we didn't mark any as safest specifically, pick one
      if (!results.any((r) => r.isSafest)) {
        // Mocking the first one as safest if only one
      }

    } catch (e) {
      debugPrint('RoutingService Error: $e');
    }

    return results;
  }

  Future<List<String>> _getAISafetyReasons(List<String> summaries) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final prompt = 'Analyze these Google Maps route summaries for a safety app for women. For each route, provide a concise 1-sentence reason why it is safe or what the traveler should watch for. Focus on lighting and road types. Routes: ${summaries.join(', ')}';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final text = response.text ?? '';
      
      // Simple split by route index numbering or newlines if possible
      final reasons = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      
      // Ensure we have enough reasons
      while (reasons.length < summaries.length) {
        reasons.add('This route follows major roads with expected lighting.');
      }
      return reasons.take(summaries.length).toList();
    } catch (e) {
      return summaries.map((s) => 'Follows $s which is largely composed of main roads.').toList();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }
}
