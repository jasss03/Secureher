import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'companion_contract.dart';

class SafeZone {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters; // default 150m
  SafeZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radiusMeters = 150,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'radius': radiusMeters,
  };

  static SafeZone fromJson(Map<String, dynamic> j) => SafeZone(
    id: j['id'],
    name: j['name'] ?? 'Zone',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    radiusMeters: (j['radius'] as num?)?.toDouble() ?? 150,
  );
}

class SafeZoneService {
  static const _key = 'safe_zones_v1';

  bool get _cloudEnabled =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  CollectionReference<Map<String, dynamic>>? get _itemsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(CompanionCollections.safeZones)
        .doc(uid)
        .collection('items');
  }

  Future<void> _saveLocal(List<SafeZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(zones.map((z) => z.toJson()).toList()),
    );
  }

  Future<List<SafeZone>> getZones() async {
    if (_cloudEnabled && _itemsRef != null) {
      final snapshot = await _itemsRef!.get();
      final zones = snapshot.docs
          .map(
            (doc) => SafeZone(
              id: doc.id,
              name: doc.data()['name'] ?? 'Zone',
              lat: (doc.data()['lat'] as num?)?.toDouble() ?? 0,
              lng: (doc.data()['lng'] as num?)?.toDouble() ?? 0,
              radiusMeters: (doc.data()['radius'] as num?)?.toDouble() ?? 150,
            ),
          )
          .toList();
      await _saveLocal(zones);
      return zones;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(SafeZone.fromJson).toList();
  }

  Future<void> saveZones(List<SafeZone> zones) async {
    await _saveLocal(zones);
    if (_cloudEnabled && _itemsRef != null) {
      final existing = await _itemsRef!.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existing.docs) {
        if (!zones.any((zone) => zone.id == doc.id)) {
          batch.delete(doc.reference);
        }
      }
      for (final zone in zones) {
        batch.set(_itemsRef!.doc(zone.id), {
          'kind': 'safe_zone',
          'mainUserId': FirebaseAuth.instance.currentUser!.uid,
          'name': zone.name,
          'lat': zone.lat,
          'lng': zone.lng,
          'radius': zone.radiusMeters,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> addZone(SafeZone z) async {
    final list = await getZones();
    list.add(z);
    await _saveLocal(list);
    if (_cloudEnabled && _itemsRef != null) {
      await _itemsRef!.doc(z.id).set({
        'kind': 'safe_zone',
        'mainUserId': FirebaseAuth.instance.currentUser!.uid,
        'name': z.name,
        'lat': z.lat,
        'lng': z.lng,
        'radius': z.radiusMeters,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeZone(String id) async {
    final list = await getZones();
    list.removeWhere((z) => z.id == id);
    await _saveLocal(list);
    if (_cloudEnabled && _itemsRef != null) {
      await _itemsRef!.doc(id).delete();
    }
  }

  // Compute if a position is inside any zone
  bool isInsideAny(Position p, List<SafeZone> zones) {
    for (final z in zones) {
      final d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        z.lat,
        z.lng,
      );
      if (d <= z.radiusMeters) return true;
    }
    return false;
  }
}
