import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'routes/app_router.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/otp_verification_screen.dart';
import 'features/contacts/trusted_contacts_screen.dart';
import 'features/safe_zones/safe_zones_screen.dart';
import 'features/motion/motion_settings_screen.dart';
import 'features/maps/maps_screen.dart';
import 'features/companion/companion_manager_screen.dart';
import 'widgets/network_status.dart';

class SecureHerApp extends StatelessWidget {
  final String? initialRoute;
  const SecureHerApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccessibilityModel(),
      child: Consumer<AccessibilityModel>(
        builder: (context, acc, _) {
          final theme = AppTheme.light(highContrast: acc.highContrast);
          final textScale = acc.largeText ? 1.2 : 1.0;
          return MaterialApp(
            title: '🔐 Secure Her',
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: NetworkStatusWidget(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            initialRoute: initialRoute,
            routes: {
              '/': (_) => const SplashScreen(),
              '/auth': (_) => const AuthScreen(),
              '/home': (_) => const AppShell(),
              '/trustedContacts': (_) => const TrustedContactsScreen(),
              '/safeZones': (_) => const SafeZonesScreen(),
              '/motionSettings': (_) => const MotionSettingsScreen(),
              '/maps': (_) => const MapsScreen(),
              '/companionManager': (_) => const CompanionManagerScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/otp') {
                final phone = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (_) =>
                      OtpVerificationScreen(phoneNumber: phone ?? ''),
                );
              }
              return null;
            },
            // If initialRoute is null, home defaults to '/'
          );
        },
      ),
    );
  }
}
