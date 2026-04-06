import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);
    await _plugin.initialize(settings);

    // Request permissions where applicable
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showImmediate({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'secureher_alerts',
      'Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iOS = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: iOS);
    await _plugin.show(0, title, body, details);
  }

  // Android 12-16 style full-screen incoming call notification
  static Future<void> showIncomingCallFullScreen({
    required String caller,
    String? subtitle,
  }) async {
    const android = AndroidNotificationDetails(
      'secureher_calls',
      'Incoming Calls',
      category: AndroidNotificationCategory.call,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: true,
      playSound: true,
    );
    const iOS = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: iOS);
    await _plugin.show(
      1001,
      'Incoming call',
      subtitle == null ? caller : '$caller • $subtitle',
      details,
      payload: 'incoming_call',
    );
  }
}
