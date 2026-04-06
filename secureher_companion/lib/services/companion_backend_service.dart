import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'companion_contract.dart';
import 'notification_service.dart';

class LinkedMainAccount {
  final String mainUserId;
  final String? displayName;
  final String? email;

  const LinkedMainAccount({
    required this.mainUserId,
    this.displayName,
    this.email,
  });
}

class CompanionBackendService {
  CompanionBackendService._();

  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Stream<User?> authChanges() => auth.authStateChanges();

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await ensureCompanionProfile();
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
    await ensureCompanionProfile();
  }

  static Future<void> signOut() async {
    await auth.signOut();
  }

  static Future<void> ensureCompanionProfile() async {
    final user = auth.currentUser;
    if (user == null || Firebase.apps.isEmpty) return;

    // Fire-and-forget: we don't need to await the server write to let the app start
    unawaited(() async {
      try {
        String? fcmToken;
        if (!kIsWeb) {
          fcmToken = await NotificationService.getAvailableFcmToken();
        }
        await firestore.collection(CompanionCollections.users).doc(user.uid).set({
          'role': 'companion',
          'displayName': user.displayName,
          'email': user.email,
          'phoneNumber': user.phoneNumber,
          'platform': _platform,
          'lastSeenAt': FieldValue.serverTimestamp(),
          if (fcmToken != null) 'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating companion profile: $e');
      }
    }());
  }

  static Future<LinkedMainAccount?> getActiveLink({bool useCache = true}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    if (useCache) {
      final cached = await _getCachedLink(uid);
      if (cached != null) return cached;
    }

    final linkSnapshot = await firestore
        .collection(CompanionCollections.companionLinks)
        .where('companionUserId', isEqualTo: uid)
        .get();

    final activeLinks = linkSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['active'] == true;
    }).toList()
      ..sort((a, b) {
        final aUpdatedAt = _timestampSortValue(a.data()['updatedAt']);
        final bUpdatedAt = _timestampSortValue(b.data()['updatedAt']);
        return bUpdatedAt.compareTo(aUpdatedAt);
      });

    if (activeLinks.isEmpty) return null;

    final link = activeLinks.first.data();
    final mainUserId = link['mainUserId'] as String;
    final userDoc = await firestore
        .collection(CompanionCollections.users)
        .doc(mainUserId)
        .get();
    final userData = userDoc.data();

    final result = LinkedMainAccount(
      mainUserId: mainUserId,
      displayName:
          (userData?['displayName'] ?? link['mainDisplayName']) as String?,
      email: userData?['email'] as String?,
    );

    unawaited(_saveCachedLink(uid, result));
    return result;
  }

  static Future<LinkedMainAccount?> _getCachedLink(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_link_$uid');
      if (data == null) return null;
      final map = jsonDecode(data) as Map<String, dynamic>;
      return LinkedMainAccount(
        mainUserId: map['mainUserId'],
        displayName: map['displayName'],
        email: map['email'],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCachedLink(String uid, LinkedMainAccount link) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_link_$uid',
        jsonEncode({
          'mainUserId': link.mainUserId,
          'displayName': link.displayName,
          'email': link.email,
        }),
      );
    } catch (_) {}
  }

  static Future<LinkedMainAccount?> redeemLinkCode(String code) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final codeDoc = await firestore
        .collection(CompanionCollections.linkCodes)
        .doc(code.trim().toUpperCase())
        .get();

    if (!codeDoc.exists) {
      throw Exception('Invalid link code. Please check the code and try again.');
    }

    final codeData = codeDoc.data()!;
    final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('Link code has expired. Please generate a new one.');
    }

    final mainUserId = codeData['mainUserId'] as String;

    // Create the active link connection
    await firestore
        .collection(CompanionCollections.companionLinks)
        .doc('${mainUserId}_${currentUser.uid}')
        .set({
      'mainUserId': mainUserId,
      'companionUserId': currentUser.uid,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Delete the used code
    try {
      await codeDoc.reference.delete();
    } catch (_) {
      // Best effort, ignore if permissions block deletion (we'll let the TTL clean it up if needed)
    }

    await ensureCompanionProfile();
    return getActiveLink();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchDeviceState(
    String mainUserId,
  ) {
    return firestore
        .collection(CompanionCollections.deviceState)
        .doc(mainUserId)
        .snapshots();
  }

  static Stream<List<Map<String, dynamic>>> watchTrustedContacts(
    String mainUserId,
  ) {
    return firestore
        .collection(CompanionCollections.trustedContacts)
        .doc(mainUserId)
        .collection('items')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> watchSafeZones(String mainUserId) {
    return firestore
        .collection(CompanionCollections.safeZones)
        .doc(mainUserId)
        .collection('items')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> watchCheckIns(String mainUserId) {
    return firestore
        .collection(CompanionCollections.checkIns)
        .doc(mainUserId)
        .collection('items')
        .orderBy('scheduledFor', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> watchActivity(String mainUserId) {
    return firestore
        .collection(CompanionCollections.activityLogs)
        .doc(mainUserId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Future<void> saveTrustedContact(
    String mainUserId, {
    String? id,
    required String name,
    required String phone,
    String? email,
    String? relationship,
  }) async {
    final doc = firestore
        .collection(CompanionCollections.trustedContacts)
        .doc(mainUserId)
        .collection('items')
        .doc(id ?? DateTime.now().microsecondsSinceEpoch.toString());

    await doc.set({
      'kind': 'trusted_contact',
      'mainUserId': mainUserId,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteTrustedContact(String mainUserId, String id) async {
    await firestore
        .collection(CompanionCollections.trustedContacts)
        .doc(mainUserId)
        .collection('items')
        .doc(id)
        .delete();
  }

  static Future<void> saveSafeZone(
    String mainUserId, {
    String? id,
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    final doc = firestore
        .collection(CompanionCollections.safeZones)
        .doc(mainUserId)
        .collection('items')
        .doc(id ?? DateTime.now().microsecondsSinceEpoch.toString());

    await doc.set({
      'kind': 'safe_zone',
      'mainUserId': mainUserId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteSafeZone(String mainUserId, String id) async {
    await firestore
        .collection(CompanionCollections.safeZones)
        .doc(mainUserId)
        .collection('items')
        .doc(id)
        .delete();
  }

  static Future<void> enqueueRemoteCommand(
    String mainUserId, {
    required String type,
    Map<String, dynamic> payload = const {},
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    
    await firestore.collection(CompanionCollections.remoteCommands).add({
      'mainUserId': mainUserId,
      'issuedByCompanionId': uid,
      'type': type,
      'payload': payload,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

int _timestampSortValue(dynamic value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}
