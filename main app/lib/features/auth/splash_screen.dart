import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/branding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  bool _showGetStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // After first frame, bootstrap and route without blocking initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapAndRoute();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() => Navigator.of(context).pushReplacementNamed('/auth');

  Future<void> _bootstrapAndRoute() async {
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false; // continue gracefully without Firebase
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString('userUid');
    final isFirstLaunch = !(prefs.getBool('hasLaunched') ?? false);
    await prefs.setBool('hasLaunched', true);

    // Check for offline authentication
    final isOfflineAuthenticated =
        prefs.getBool('is_offline_authenticated') ?? false;

    // User is returning if they have a Firebase UID or are offline authenticated
    final isReturning =
        (firebaseReady && savedUid != null) || isOfflineAuthenticated;
    final showGetStarted = isFirstLaunch || !isReturning;

    if (mounted) {
      setState(() => _showGetStarted = showGetStarted);
    }

    if (!showGetStarted) {
      // Returning user: show logo briefly, then go home
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: _showGetStarted
                  ? GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 36,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            size: 56,
                            color: Color(0xFF7B61FF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Because You\nDeserve Safety',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Empowering Safety, Anytime, Anywhere',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.black.withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            onPressed: _goNext,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Get Started'),
                          ),
                        ],
                      ),
                    )
                  : const Icon(
                      Icons.shield_rounded,
                      size: 72,
                      color: Color(0xFF7B61FF),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
