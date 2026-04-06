import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import 'contacts_service.dart';
import '../utils/phone_utils.dart';
import 'companion_service.dart';

class AlertSessionResult {
  final int recipients;
  final String? alertId;
  AlertSessionResult({required this.recipients, required this.alertId});
}

class AlertService {
  final _contacts = ContactsService();
  final _companion = CompanionService();

  // Simple heartbeat location share (optional Firestore only). Safe to call without Firebase configured.
  bool get _firestoreEnabled =>
      AppConfig.useFirestore && Firebase.apps.isNotEmpty;

  Future<void> shareLocationHeartbeat(Position position) async {
    if (!_firestoreEnabled) return;
    try {
      await _companion.publishCurrentPosition(position);
    } catch (_) {
      // Ignore if Firestore not configured.
    }
  }

  Future<void> _openSmsToContacts(String body, {int maxRecipients = 3}) async {
    final contacts = await _contacts.getContacts();
    final numbers = contacts
        .map((c) => c.phone)
        .where((p) => p.trim().isNotEmpty)
        .take(maxRecipients)
        .toList();
    if (numbers.isEmpty) return;

    // Build SMS URI manually to avoid Uri() using form-encoding (+) for spaces.
    // RFC 5724 sms: scheme uses ?body= (not &body=) for the first parameter.
    final encodedBody = Uri.encodeComponent(body);
    final fixedUri = 'sms:${numbers.join(',')}?body=$encodedBody';
    final uri = Uri.parse(fixedUri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> notifyLocationShareStart({Position? position}) async {
    final msg = _composeLocationShareMessage(position: position);
    await _openSmsToContacts(msg);
  }

  // Starts an SOS session: creates Firestore doc (if available) and opens SMS composer.
  Future<AlertSessionResult> startSosSession({
    Position? position,
    String? customMessage,
    String type = 'sos',
    String? triggerSource,
  }) async {
    final contacts = await _contacts.getContacts();
    if (contacts.isEmpty)
      return AlertSessionResult(recipients: 0, alertId: null);

    final msg = customMessage ?? _composeMessage(position: position);
    String? alertId;

    // Try Firestore (optional)
    if (_firestoreEnabled) {
      try {
        final ref = await FirebaseFirestore.instance.collection('alerts').add({
          'type': type,
          'mainUserId': FirebaseAuth.instance.currentUser?.uid,
          'message': msg,
          'active': true,
          'triggerSource': triggerSource ?? 'manual',
          'currentLocation': position == null
              ? null
              : {'lat': position.latitude, 'lng': position.longitude},
          'recipients': contacts
              .map((e) => {'name': e.name, 'phone': e.phone, 'email': e.email})
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        alertId = ref.id;
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Firestore write skipped: $e');
        }
      }
    }

    // Attempt to open SMS composer with prefilled content to first 3 contacts
    final numbers = contacts
        .map((c) => PhoneUtils.normalizeIndianNumber(c.phone))
        .where((p) => p.trim().isNotEmpty)
        .take(3)
        .toList();
    if (numbers.isNotEmpty) {
      // For trip type: include live tracking link if we have an alertId
      final smsBody = (type == 'trip' && alertId != null)
          ? _composeTripMessage(msg, alertId!)
          : msg;
      await _openSmsToContacts(smsBody);
    }
    return AlertSessionResult(recipients: numbers.length, alertId: alertId);
  }

  Future<void> triggerRemoteSiren(String alertId) async {
    if (!_firestoreEnabled) return;
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
        'triggerSiren': true,
        'sirenTriggeredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> updateLiveLocation(String alertId, Position position) async {
    if (!_firestoreEnabled) return;
    try {
      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(alertId)
          .collection('locations')
          .add({
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          });
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update(
        {
          'last': {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          },
        },
      );
    } catch (_) {}
  }

  Future<void> closeSosSession(String alertId, {Position? position}) async {
    if (!_firestoreEnabled) return;
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update(
        {
          'active': false,
          'endedAt': FieldValue.serverTimestamp(),
          if (position != null)
            'end': {
              'lat': position.latitude,
              'lng': position.longitude,
              'timestamp': FieldValue.serverTimestamp(),
            },
        },
      );
    } catch (_) {}
  }

  Future<void> sendSafeMessage({Position? position}) async {
    final contacts = await _contacts.getContacts();
    if (contacts.isEmpty) return;
    final msg = _composeSafeMessage(position: position);
    if (_firestoreEnabled) {
      try {
        await FirebaseFirestore.instance.collection('alerts').add({
          'type': 'safe',
          'mainUserId': FirebaseAuth.instance.currentUser?.uid,
          'message': msg,
          'currentLocation': position == null
              ? null
              : {'lat': position.latitude, 'lng': position.longitude},
          'recipients': contacts
              .map((e) => {'name': e.name, 'phone': e.phone, 'email': e.email})
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    final numbers = contacts
        .map((c) => PhoneUtils.normalizeIndianNumber(c.phone))
        .where((p) => p.trim().isNotEmpty)
        .take(3)
        .toList();
    if (numbers.isEmpty) return;
    await _openSmsToContacts(msg);
  }

  /// Listens to a specific alert document and triggers the local siren if 'triggerSiren' is true.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  listenForRemoteSiren(String alertId, Function() onSiren) {
    if (!_firestoreEnabled) return null;

    return FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (data != null && data['triggerSiren'] == true) {
            onSiren();
          }
        });
  }

  String _composeTripMessage(String base, String alertId) {
    final trackingUrl = 'https://her-b03d7.web.app/track.html?id=$alertId';
    return '$base\nTrack my live location: $trackingUrl';
  }

  String _composeMessage({Position? position}) {
    final base = 'SOS! I need help. Please contact me immediately.';
    if (position == null) return base;
    final maps =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    return '$base\nMy live location: $maps';
  }

  String _composeSafeMessage({Position? position}) {
    final base = "I'm safe now. Thank you for checking in.";
    if (position == null) return base;
    final maps =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    return '$base\nCurrent location: $maps';
  }

  String _composeLocationShareMessage({Position? position}) {
    final base = 'I\'ve started sharing my live location with you.';
    if (position == null) return base;
    final maps =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    return '$base\nMy current location: $maps';
  }
}
