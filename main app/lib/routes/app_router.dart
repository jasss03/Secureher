import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/sos/sos_controller.dart';
import '../features/sos/sos_screen.dart';
import '../features/map/safe_space_finder_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/women_essential/women_essential_screen.dart';
import '../widgets/global_sos_button.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final SosController _sosController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _sosController = SosController()
      ..bindOpenSosTab(() {
        if (!mounted) return;
        setState(() => _index = 1);
      });
    _pages = [
      HomeScreen(sosController: _sosController),
      SosScreen(controller: _sosController),
      const SafeSpaceFinderScreen(),
      const WomenEssentialScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: IndexedStack(index: _index, children: _pages),
            ),
            // Global SOS button overlay on all screens
            const Positioned(right: 16, bottom: 16, child: GlobalSosButton()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.emergency_rounded),
              label: 'SOS',
            ),
            NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Map'),
            NavigationDestination(
              icon: Icon(Icons.spa_rounded),
              label: 'Essentials',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
