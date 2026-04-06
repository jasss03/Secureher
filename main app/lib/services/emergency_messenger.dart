import 'dart:convert';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import 'contacts_service.dart';
import 'companion_service.dart';
import '../utils/phone_utils.dart';

class EmergencyMessenger {
  static const String _defaultBackend = '';

  static Future<void> pingTrusted({
    required bool announceShare,
    String? backendBaseUrl,
  }) async {
    Position? pos;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (enabled &&
          perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (_) {}

    final msg = _buildMessage(announceShare: announceShare, pos: pos);
    final contacts = await ContactsService().getContacts();
    final recipients = contacts
        .map((c) => PhoneUtils.normalizeIndianNumber(c.phone))
        .where((p) => p.isNotEmpty)
        .toList();

    // Notify companion apps
    try {
      if (!announceShare) {
        // Only send SOS alerts to companion apps, not location sharing notifications
        await CompanionService().sendSosAlert(
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          address: null, // Could add reverse geocoding here in the future
        );
      }
    } catch (e) {
      print('Error notifying companion apps: $e');
    }

    if (recipients.isEmpty) return;

    if (Platform.isAndroid) {
      final sent = await _tryAndroidSmsPlatformChannel(
        recipients: recipients,
        message: msg,
      );
      if (sent) return;
    }

    await _sendViaBackend(
      backendBaseUrl: backendBaseUrl ?? _defaultBackend,
      to: recipients,
      message: msg,
      lat: pos?.latitude,
      lng: pos?.longitude,
    );
  }

  static String _buildMessage({required bool announceShare, Position? pos}) {
    final maps = (pos == null)
        ? null
        : 'https://maps.google.com/?q=${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
    if (announceShare) {
      return [
        "I've started sharing my live location with you.",
        if (maps != null) "My current location: $maps",
      ].join('\n');
    } else {
      return [
        "SOS! I need help. Please contact me immediately.",
        if (maps != null) "My live location: $maps",
      ].join('\n');
    }
  }

  static const MethodChannel _smsChannel = MethodChannel('secureher/sms');

  static Future<bool> _tryAndroidSmsPlatformChannel({
    required List<String> recipients,
    required String message,
  }) async {
    try {
      final bool ok = await _smsChannel.invokeMethod('sendText', {
        'to': recipients,
        'message': message,
      });
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _sendViaBackend({
    required String backendBaseUrl,
    required List<String> to,
    required String message,
    double? lat,
    double? lng,
  }) async {
    if (backendBaseUrl.isEmpty) return; // no-op if backend not provided
    final uri = Uri.parse('$backendBaseUrl/sms/send');
    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'message': message,
          if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
          'source': 'secureher-app',
        }),
      );
    } catch (_) {}
  }
}
