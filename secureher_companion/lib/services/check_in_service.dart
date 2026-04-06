import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:secureher_companion/services/notification_service.dart';

class CheckInService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get check-ins for the current user
  static Stream<QuerySnapshot> getCheckIns() {
    return _firestore
        .collection('check_ins')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get upcoming check-ins
  static Stream<QuerySnapshot> getUpcomingCheckIns() {
    return _firestore
        .collection('check_ins')
        .where('nextCheckIn', isGreaterThan: Timestamp.now())
        .orderBy('nextCheckIn')
        .snapshots();
  }

  // Listen for missed check-ins
  static void listenForMissedCheckIns() {
    getUpcomingCheckIns().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final nextCheckIn = data['nextCheckIn'] as Timestamp?;

        if (nextCheckIn != null) {
          final checkInTime = nextCheckIn.toDate();
          final now = DateTime.now();

          // If check-in time has passed and there's no confirmation
          if (checkInTime.isBefore(now) && !(data['confirmed'] ?? false)) {
            // Show notification for missed check-in
            NotificationService.showNotification(
              title: 'Missed Check-in',
              body: 'A scheduled check-in was missed. Tap to view details.',
              payload: 'missed_checkin',
            );

            // Update the check-in status in Firestore
            doc.reference.update({'missed': true, 'missedAt': Timestamp.now()});
          }
        }
      }
    });
  }

  // Schedule a new check-in reminder
  static Future<void> scheduleCheckIn({
    required DateTime checkInTime,
    required String message,
  }) async {
    try {
      // Create check-in document in Firestore
      await _firestore.collection('check_ins').add({
        'userId': _auth.currentUser?.uid,
        'timestamp': Timestamp.now(),
        'nextCheckIn': Timestamp.fromDate(checkInTime),
        'message': message,
        'confirmed': false,
        'missed': false,
      });

      // Schedule local notification for the check-in
      final id = checkInTime.millisecondsSinceEpoch ~/ 1000;

      await NotificationService.scheduleNotification(
        id: id,
        title: 'Check-in Reminder',
        body: message,
        scheduledDate: checkInTime,
        payload: 'checkin_reminder',
      );

      return;
    } catch (e) {
      print('Error scheduling check-in: $e');
      rethrow;
    }
  }

  // Confirm a check-in
  static Future<void> confirmCheckIn(String checkInId) async {
    try {
      await _firestore.collection('check_ins').doc(checkInId).update({
        'confirmed': true,
        'confirmedAt': Timestamp.now(),
      });
      return;
    } catch (e) {
      print('Error confirming check-in: $e');
      rethrow;
    }
  }
}
