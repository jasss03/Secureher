import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ConnectivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Link companion app with main app using a link code
  static Future<void> linkWithMainApp(String linkCode) async {
    try {
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Look up the link code in Firestore to get the mainUserId
      final codeDoc = await _firestore.collection('link_codes').doc(linkCode.toUpperCase().trim()).get();
      if (!codeDoc.exists) {
        throw Exception('Invalid link code. Please check the code and try again.');
      }

      final codeData = codeDoc.data()!;
      final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Link code has expired. Please generate a new code from the main app.');
      }

      final mainAppUserId = codeData['mainUserId'] as String;

      // Get FCM token for notifications
      final fcmToken = await NotificationService.getAvailableFcmToken();

      // Store the linking in Firestore
      await _firestore.collection('app_connections').add({
        'companionUserId': currentUser.uid,
        'mainAppUserId': mainAppUserId,
        'companionFcmToken': fcmToken,
        'linkedAt': Timestamp.now(),
        'active': true,
      });

      // Delete the used link code so it can't be reused
      await codeDoc.reference.delete();

      // Store the linked user ID in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('linked_main_app_user_id', mainAppUserId);

      return;
    } catch (e) {
      print('Error linking with main app: $e');
      rethrow;
    }
  }

  // Get linked main app user ID
  static Future<String?> getLinkedMainAppUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('linked_main_app_user_id');
    } catch (e) {
      print('Error getting linked main app user ID: $e');
      return null;
    }
  }

  // Check if companion app is linked with main app
  static Future<bool> isLinkedWithMainApp() async {
    try {
      final linkedUserId = await getLinkedMainAppUserId();
      return linkedUserId != null;
    } catch (e) {
      print('Error checking if linked with main app: $e');
      return false;
    }
  }

  // Update FCM token
  static Future<void> updateFcmToken() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final fcmToken = await NotificationService.getAvailableFcmToken();

      // Get the connection document
      final querySnapshot = await _firestore
          .collection('app_connections')
          .where('companionUserId', isEqualTo: currentUser.uid)
          .where('active', isEqualTo: true)
          .get();

      // Update FCM token in all active connections
      for (var doc in querySnapshot.docs) {
        await doc.reference.update({
          'companionFcmToken': fcmToken,
          'lastTokenUpdate': Timestamp.now(),
        });
      }

      return;
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Listen for SOS alerts from linked main app user
  static Stream<QuerySnapshot> listenForSosAlerts() {
    return _firestore
        .collection('alerts')
        .where('type', isEqualTo: 'sos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Send a notification to the main app
  static Future<void> sendNotificationToMainApp({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get the linked main app user ID
      final linkedUserId = await getLinkedMainAppUserId();
      if (linkedUserId == null) return;

      // Create a notification document in Firestore
      await _firestore.collection('notifications').add({
        'recipientId': linkedUserId,
        'senderId': currentUser.uid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': Timestamp.now(),
      });

      return;
    } catch (e) {
      print('Error sending notification to main app: $e');
    }
  }
}
