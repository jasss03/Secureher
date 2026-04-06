import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'secureher_app.dart';

Future<void> main() async {
  // Use PlatformDispatcher to catch async errors globally
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('GLOBAL ASYNC ERROR: $error');
    debugPrint(stack.toString());
    return true; // prevent crash
  };

  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase & Services with robust error handling
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await NotificationService.init();
  } catch (e) {
    debugPrint('Critical Initialization Error: $e');
  }

  runApp(const SecureHerApp(initialRoute: '/'));
}
