import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'contacts_service.dart';
import 'companion_contract.dart';

class CompanionService {
  static final CompanionService _instance = CompanionService._internal();
  factory CompanionService() => _instance;
  CompanionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commandSubscription;
  final Set<String> _processingCommands = <String>{};

  bool get _isReady => Firebase.apps.isNotEmpty && _auth.currentUser != null;

  Future<void> syncCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      fcmToken = null;
    }

    await _firestore.collection(CompanionCollections.users).doc(user.uid).set({
      'role': 'main',
      'displayName': user.displayName,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'platform': Platform.operatingSystem,
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (fcmToken != null) 'fcmTokens': FieldValue.arrayUnion([fcmToken]),
    }, SetOptions(merge: true));

    await _firestore
        .collection(CompanionCollections.deviceState)
        .doc(user.uid)
        .set({
          'mainUserId': user.uid,
          'platform': Platform.operatingSystem,
          'online': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<String> createLinkCode() async {
    if (!_isReady) throw Exception('User not authenticated');
    final user = _auth.currentUser!;

    // Generate a random 6-character alphanumeric code
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();

    // Write it to Firestore with a 10-minute TTL
    await _firestore.collection('link_codes').doc(code).set({
      'mainUserId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
    });

    return code;
  }

  Future<List<Map<String, dynamic>>> getLinkedCompanions() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final links = await _firestore
        .collection(CompanionCollections.companionLinks)
        .where('mainUserId', isEqualTo: user.uid)
        .get();

    final activeLinks = links.docs.where((doc) {
      final data = doc.data();
      return data['active'] == true;
    }).toList()
      ..sort((a, b) {
        final aUpdatedAt = _timestampSortValue(a.data()['updatedAt']);
        final bUpdatedAt = _timestampSortValue(b.data()['updatedAt']);
        return bUpdatedAt.compareTo(aUpdatedAt);
      });

    return activeLinks
        .map(
          (doc) => {
            'id': doc.id,
            'companionUserId': doc.data()['companionUserId'],
            'companionName':
                doc.data()['companionDisplayName'] ??
                doc.data()['companionEmail'] ??
                'Companion App',
            'lastActive': doc.data()['updatedAt'],
          },
        )
        .toList();
  }

  Future<void> removeCompanion(String connectionId) async {
    await _firestore
        .collection(CompanionCollections.companionLinks)
        .doc(connectionId)
        .set({
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> syncDeviceState(Map<String, dynamic> patch) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;
    await _firestore
        .collection(CompanionCollections.deviceState)
        .doc(user.uid)
        .set({
          'mainUserId': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          ...patch,
        }, SetOptions(merge: true));
  }

  Future<void> publishCurrentPosition(Position position) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    final payload = {
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'capturedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection(CompanionCollections.deviceState)
        .doc(user.uid)
        .set({
          'currentLocation': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await _firestore
        .collection(CompanionCollections.deviceLocations)
        .doc(user.uid)
        .collection('points')
        .add(payload);
  }

  Future<void> createAlert({
    required String type,
    required String message,
    Position? position,
    bool active = false,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    final contacts = await ContactsService().getContacts();
    await _firestore.collection(CompanionCollections.alerts).add({
      'type': type,
      'mainUserId': user.uid,
      'message': message,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'currentLocation': position == null
          ? null
          : {'lat': position.latitude, 'lng': position.longitude},
      'recipients': contacts
          .map(
            (contact) => {
              'id': contact.id,
              'name': contact.name,
              'phone': contact.phone,
              'email': contact.email,
              'relationship': contact.relationship,
            },
          )
          .toList(),
      ...?extra,
    });
  }

  Future<void> sendSosAlert({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    await createAlert(
      type: 'sos',
      active: true,
      message: '${_auth.currentUser?.displayName ?? 'Your friend'} needs help!',
      extra: {
        'address': address,
        if (latitude != null && longitude != null)
          'currentLocation': {'lat': latitude, 'lng': longitude},
      },
    );
  }

  Future<void> sendCheckInNotification({
    required DateTime scheduledTime,
    required String message,
  }) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    final checkInId = DateTime.now().microsecondsSinceEpoch.toString();
    await _firestore
        .collection(CompanionCollections.checkIns)
        .doc(user.uid)
        .collection('items')
        .doc(checkInId)
        .set({
          'kind': 'check_in',
          'mainUserId': user.uid,
          'message': message,
          'scheduledFor': Timestamp.fromDate(scheduledTime),
          'status': 'pending',
          'createdBy': 'main_app',
          'createdAt': FieldValue.serverTimestamp(),
        });

    await syncDeviceState({
      'activeCheckIn': {
        'id': checkInId,
        'message': message,
        'scheduledFor': Timestamp.fromDate(scheduledTime),
        'status': 'pending',
      },
    });
  }

  Future<void> completeCheckIn(String checkInId) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    await _firestore
        .collection(CompanionCollections.checkIns)
        .doc(user.uid)
        .collection('items')
        .doc(checkInId)
        .set({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await syncDeviceState({'activeCheckIn': null});
  }

  Future<void> startRemoteCommandListener({
    required Future<String?> Function(String type, Map<String, dynamic> payload)
    onCommand,
  }) async {
    final user = _auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    await _commandSubscription?.cancel();
    _commandSubscription = _firestore
        .collection(CompanionCollections.remoteCommands)
        .where('mainUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'queued')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _processQueuedCommand(change.doc, onCommand);
            }
          }
        });
  }

  Future<void> _processQueuedCommand(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Future<String?> Function(String type, Map<String, dynamic> payload)
    onCommand,
  ) async {
    if (_processingCommands.contains(doc.id)) return;
    _processingCommands.add(doc.id);
    final data = doc.data();

    try {
      if (data == null) return;

      await doc.reference.set({
        'status': 'processing',
        'processingAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final type = data['type'] as String? ?? '';
      final payload = Map<String, dynamic>.from(
        data['payload'] as Map? ?? const {},
      );
      final message = await onCommand(type, payload);

      await doc.reference.set({
        'status': 'success',
        'ackAt': FieldValue.serverTimestamp(),
        if (message != null) 'result': message,
      }, SetOptions(merge: true));

      await syncDeviceState({
        'lastCommandResult': {
          'type': type,
          'status': 'success',
          'message': message ?? 'Command completed successfully.',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      await doc.reference.set({
        'status': 'failed',
        'ackAt': FieldValue.serverTimestamp(),
        'error': e.toString(),
      }, SetOptions(merge: true));
      await syncDeviceState({
        'lastCommandResult': {
          'type': data?['type'],
          'status': 'failed',
          'message': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } finally {
      _processingCommands.remove(doc.id);
    }
  }

  Future<void> stopRemoteCommandListener() async {
    await _commandSubscription?.cancel();
    _commandSubscription = null;
  }
}

int _timestampSortValue(dynamic value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}
