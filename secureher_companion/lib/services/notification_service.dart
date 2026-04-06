import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static tz.Location? local;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      // Initialize timezone
      tz_data.initializeTimeZones();
      local = tz.local;

      // Request permission for notifications
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Listen for FCM messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showNotification(message);
      });

      _messaging.onTokenRefresh.listen(_saveFcmToken);
      await _saveFcmToken(await getAvailableFcmToken());
    } on FirebaseException catch (error) {
      debugPrint('Notification setup skipped: ${error.code}');
    } catch (error) {
      debugPrint('Notification setup skipped: $error');
    }
  }

  static Future<String?> getAvailableFcmToken() async {
    if (kIsWeb) {
      return _messaging.getToken();
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('FCM token deferred until APNS token is available.');
          return null;
        }
      }

      return await _messaging.getToken();
    } on FirebaseException catch (error) {
      if (error.code == 'apns-token-not-set') {
        debugPrint('FCM token deferred until APNS token is available.');
        return null;
      }
      rethrow;
    }
  }

  static Future<void> _saveFcmToken(String? token) async {
    if (token == null) return;

    // TODO: Save token to Firestore with user ID
    // This would be implemented when user authentication is added
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _notificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sos_channel',
            'SOS Alerts',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['type'],
      );
    }
  }

  static Future<void> showSosNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _notificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_channel',
          'SOS Alerts',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          sound: RawResourceAndroidNotificationSound('siren'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'siren.mp3',
        ),
      ),
      payload: payload,
    );
  }

  // Add the missing methods that are used in check_in_service.dart
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Default Notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb || local == null) return;
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, local!),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }
}
