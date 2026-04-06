import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alert_service.dart';
import '../services/companion_service.dart';
import 'companion_contract.dart';

class CheckInService {
  static const _deadlineKey = 'checkin_deadline_epoch';
  static const _activeIdKey = 'checkin_active_id';
  Timer? _timer;

  bool get _cloudEnabled =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  CollectionReference<Map<String, dynamic>>? get _checkInsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(CompanionCollections.checkIns)
        .doc(uid)
        .collection('items');
  }

  Future<void> startCheckIn(
    Duration duration, {
    String message = 'Check-in reminder',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deadline = DateTime.now().add(duration);
    final deadlineMs = deadline.millisecondsSinceEpoch;
    await prefs.setInt(_deadlineKey, deadlineMs);
    final checkInId = DateTime.now().microsecondsSinceEpoch.toString();
    await prefs.setString(_activeIdKey, checkInId);

    if (_cloudEnabled && _checkInsRef != null) {
      await _checkInsRef!.doc(checkInId).set({
        'kind': 'check_in',
        'mainUserId': FirebaseAuth.instance.currentUser!.uid,
        'message': message,
        'scheduledFor': Timestamp.fromDate(deadline),
        'status': 'pending',
        'createdBy': 'main_app',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await CompanionService().syncDeviceState({
      'activeCheckIn': {
        'id': checkInId,
        'message': message,
        'scheduledFor': Timestamp.fromDate(deadline),
        'status': 'pending',
      },
    });

    _timer?.cancel();
    _timer = Timer(duration, () async {
      if (!_cloudEnabled) {
        await _sendMissedCheckInAlert();
      }
    });
  }

  Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeIdKey);
    await prefs.remove(_deadlineKey);
    await prefs.remove(_activeIdKey);
    _timer?.cancel();

    if (_cloudEnabled && _checkInsRef != null && activeId != null) {
      await _checkInsRef!.doc(activeId).set({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await CompanionService().syncDeviceState({'activeCheckIn': null});
  }

  Future<int?> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final deadline = prefs.getInt(_deadlineKey);
    if (deadline == null) return null;
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).floor() : 0;
  }

  Future<void> _sendMissedCheckInAlert() async {
    final alerts = AlertService();
    await alerts.startSosSession(
      customMessage: 'Missed check-in. Please reach out to me now.',
    );
    await cancel();
  }
}
