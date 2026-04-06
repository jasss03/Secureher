import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/branding.dart';
import '../contacts/trusted_contacts_screen.dart';
import '../fake_call/fake_call_screen.dart';
import '../route_guard/route_guard_screen.dart';
import '../sos/sos_controller.dart';
import '../sos/sos_screen.dart';
import '../../services/siren_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/motion_service.dart';
import '../safe_zones/safe_zones_screen.dart';
import '../sos/battery_saver_screen.dart';
import '../checkin/check_in_screen.dart';
import '../../services/location_service.dart';
import '../../services/alert_service.dart';
import '../../services/emergency_messenger.dart';
import '../../services/checkin_service.dart';
import '../../services/companion_contract.dart';
import '../../services/companion_service.dart';
import '../../services/notification_service.dart';
import '../../services/ai_assist_service.dart';
import '../../services/tts_service.dart';
import '../tips/tips_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.sosController});

  final SosController sosController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _siren = SirenService();
  MotionService? _motion;
  bool _sirenOn = false;
  bool _batteryMode = false;
  bool _isSOSActive = false;
  bool _isSOSLaunching = false;
  int _powerButtonPresses = 0;
  DateTime? _lastPowerPress;
  double _motionSensitivity = 1.5;
  final _tts = TtsService();
  AiAssistService? _foregroundVoiceGuardian;
  StreamSubscription<String>? _voiceTranscriptSub;
  StreamSubscription<int>? _voiceCheckInSub;
  bool _voiceGuardianStarting = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Live location sharing
  bool _shareLocation = false;
  Timer? _locTimer;
  final _locationSvc = LocationService();
  final _alerts = AlertService();
  final _checkIns = CheckInService();
  final _companion = CompanionService();

  // Status snapshot
  String _lastCheckIn = '—';
  String _currentLocation = '—';
  String? _userName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sosController.addListener(_handleSosControllerChanged);
    _loadSettings();
    _initStatus();
    _startMotion();
    _startForegroundVoiceGuardian();
    _initializeCompanionBridge();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sosController.removeListener(_handleSosControllerChanged);
    _motion?.stop();
    _stopForegroundVoiceGuardian();
    _stopLocationSharing();
    _companion.stopRemoteCommandListener();
    super.dispose();
  }

  void _handleSosControllerChanged() {
    if (!mounted) return;
    final active = widget.sosController.isActive;
    setState(() => _isSOSActive = active);
    if (active) {
      _stopForegroundVoiceGuardian();
    } else {
      _startForegroundVoiceGuardian();
    }
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _batteryMode = prefs.getBool('battery_mode') ?? false;
      _motionSensitivity = prefs.getDouble('motion_sensitivity') ?? 1.5;
      _shareLocation = prefs.getBool('share_location') ?? false;
    });
    if (_shareLocation) _startLocationSharing();
    await _syncRuntimeState();
  }

  Future<void> _initStatus() async {
    // TODO: Pull real data: contacts count, last check-in, current location, route status
    User? u;
    try {
      u = FirebaseAuth.instance.currentUser;
    } catch (_) {
      u = null;
    }
    final name = u?.displayName?.trim();
    final email = u?.email;
    final phone = u?.phoneNumber;
    setState(() {
      _lastCheckIn = 'No timer';
      _currentLocation = 'Unknown';
      _userName = (name != null && name.isNotEmpty)
          ? name
          : (phone != null && phone.isNotEmpty)
          ? phone
          : (email != null && email.isNotEmpty)
          ? email.split('@').first
          : 'Friend';
    });
    await _companion.syncCurrentUserProfile();
  }

  Future<void> _initializeCompanionBridge() async {
    await _companion.syncCurrentUserProfile();
    await _syncRuntimeState();
    await _companion.startRemoteCommandListener(
      onCommand: _handleRemoteCommand,
    );
  }

  Future<void> _syncRuntimeState() async {
    await _companion.syncDeviceState({
      'online': true,
      'sirenOn': _sirenOn,
      'batteryMode': _batteryMode,
      'motionSensitivity': _motionSensitivity,
      'shareLocationEnabled': _shareLocation,
      'uiSnapshot': {
        'lastCheckIn': _lastCheckIn,
        'currentLocationLabel': _currentLocation,
      },
    });
  }

  void _startMotion() {
    _motion?.stop();
    final sens = _batteryMode ? (_motionSensitivity + 0.8) : _motionSensitivity;
    _motion = MotionService(
      sensitivity: sens,
      onShakePanic: () => _triggerEmergencyFlow('Shake', playSiren: true),
      onImpactDetected: () => _triggerEmergencyFlow('Impact', playSiren: true),
    )..start();
  }

  Future<void> _startForegroundVoiceGuardian() async {
    if (!mounted ||
        _voiceGuardianStarting ||
        _foregroundVoiceGuardian != null ||
        _isSOSActive ||
        _appLifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _voiceGuardianStarting = true;
    final guardian = AiAssistService();
    final started = await guardian.startListening(requestPermissions: true);

    if (!mounted ||
        _isSOSActive ||
        _appLifecycleState != AppLifecycleState.resumed) {
      await guardian.stop();
      _voiceGuardianStarting = false;
      return;
    }

    if (!started) {
      _voiceGuardianStarting = false;
      return;
    }

    _foregroundVoiceGuardian = guardian;
    _voiceTranscriptSub = guardian.transcripts.listen((_) async {
      if (!mounted || _isSOSActive || _isSOSLaunching) return;
      if (guardian.dangerDetected) {
        await _triggerEmergencyFlow(
          'Voice: ${guardian.matchedKeyword ?? 'distress keyword'}',
          playSiren: true,
        );
      }
    });
    _voiceCheckInSub = guardian.checkInStatus.listen((count) async {
      if (!mounted || _isSOSActive || _isSOSLaunching) return;
      if (count == 5) {
        await HapticFeedback.heavyImpact();
        await _tts.speak(
          'Safety check active. Say any word within five seconds to cancel.',
        );
      } else if (count == 0) {
        await HapticFeedback.vibrate();
        await _triggerEmergencyFlow('Voice safety timeout', playSiren: true);
      }
    });
    _voiceGuardianStarting = false;
  }

  Future<void> _stopForegroundVoiceGuardian() async {
    await _voiceTranscriptSub?.cancel();
    _voiceTranscriptSub = null;
    await _voiceCheckInSub?.cancel();
    _voiceCheckInSub = null;
    final guardian = _foregroundVoiceGuardian;
    _foregroundVoiceGuardian = null;
    if (guardian != null) {
      await guardian.stop();
    }
  }

  void _startLocationSharing() {
    _locTimer?.cancel();
    final interval = _batteryMode
        ? const Duration(minutes: 2)
        : const Duration(seconds: 30);
    _locTimer = Timer.periodic(interval, (_) async {
      final pos = await _locationSvc.getCurrentPosition();
      if (pos != null) {
        await _alerts.shareLocationHeartbeat(pos);
        await _companion.publishCurrentPosition(pos);
        setState(() {
          _currentLocation =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
        await _syncRuntimeState();
      }
    });
  }

  void _stopLocationSharing() {
    _locTimer?.cancel();
    _locTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      // Approximate power button multi-press (limited on Android without native).
      _handlePowerButtonPress();
      _companion.syncCurrentUserProfile();
      _syncRuntimeState();
      _startForegroundVoiceGuardian();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopForegroundVoiceGuardian();
    }
  }

  void _handlePowerButtonPress() {
    final now = DateTime.now();
    if (_lastPowerPress != null &&
        now.difference(_lastPowerPress!).inSeconds < 2) {
      _powerButtonPresses++;
      if (_powerButtonPresses >= 3) {
        _triggerEmergencyFlow('Power Button', playSiren: true);
        _powerButtonPresses = 0;
      }
    } else {
      _powerButtonPresses = 1;
    }
    _lastPowerPress = now;
  }

  Future<void> _triggerEmergencyFlow(
    String method, {
    required bool playSiren,
  }) async {
    if (_isSOSActive || _isSOSLaunching) return;
    _isSOSLaunching = true;
    if (mounted) {
      setState(() => _isSOSActive = true);
    }
    // Haptic feedback
    HapticFeedback.heavyImpact();
    await widget.sosController.activate(
      triggerSource: method,
      activateSirenImmediately: playSiren,
    );
    _isSOSLaunching = false;
    if (mounted) {
      setState(() => _isSOSActive = widget.sosController.isActive);
    }
  }

  void _openSafeZones() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SafeZonesScreen()));
  }

  void _openBatterySaver() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BatterySaverScreen()));
  }

  Future<void> _toggleSiren() async {
    await _setSiren(!_sirenOn);
  }

  Future<void> _setSiren(bool enabled) async {
    if (enabled) {
      await _siren.play();
    } else {
      await _siren.stop();
    }
    if (mounted) {
      setState(() => _sirenOn = enabled);
    }
    await _syncRuntimeState();
  }

  Future<void> _setBatteryMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _batteryMode = enabled);
    }
    await prefs.setBool('battery_mode', enabled);
    // Restart motion with new sensitivity and adjust location interval
    _startMotion();
    if (_shareLocation) {
      _startLocationSharing();
    }
    await _syncRuntimeState();
  }

  Future<void> _setMotionSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _motionSensitivity = value);
    }
    await prefs.setDouble('motion_sensitivity', value);
    _startMotion();
    await _syncRuntimeState();
  }

  Future<void> _toggleShareLocation() async {
    await _setShareLocation(!_shareLocation, announce: true);
  }

  Future<void> _setShareLocation(bool enabled, {required bool announce}) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _shareLocation = enabled);
    }
    await prefs.setBool('share_location', enabled);
    if (enabled) {
      // Start periodic sharing and send an initial SMS to contacts with current location
      _startLocationSharing();
      final pos = await _locationSvc.getCurrentPosition();
      if (announce) {
        // Notify via Android SMS if possible, otherwise via backend
        await EmergencyMessenger.pingTrusted(
          announceShare: true,
          backendBaseUrl: const String.fromEnvironment(
            'SECUREHER_API',
            defaultValue: '',
          ),
        );
        // Keep legacy composer path as secondary UX option
        await _alerts.notifyLocationShareStart(position: pos);
      }
      if (pos != null) {
        await _companion.publishCurrentPosition(pos);
      }
    } else {
      _stopLocationSharing();
    }
    await _syncRuntimeState();
  }

  Future<void> _checkInNow() async {
    final pos = await _locationSvc.getCurrentPosition();
    try {
      // Use silent Android SMS or backend
      await EmergencyMessenger.pingTrusted(
        announceShare: true,
        backendBaseUrl: const String.fromEnvironment(
          'SECUREHER_API',
          defaultValue: '',
        ),
      );
      // Keep existing composer-based safe message as a fallback
      await _alerts.sendSafeMessage(position: pos);
    } catch (_) {}
    setState(() {
      _lastCheckIn = 'Just now';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in sent to trusted contacts')),
      );
    }
    await _syncRuntimeState();
  }

  Future<void> _triggerRemoteFakeCall(Map<String, dynamic> payload) async {
    final callerName = (payload['name'] as String?)?.trim();
    final caller = (callerName == null || callerName.isEmpty)
        ? 'SecureHer Companion'
        : callerName;

    await NotificationService.showIncomingCallFullScreen(
      caller: caller,
      subtitle: 'Remote safety call',
    );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(caller: caller, playVoice: true),
        ),
      );
    }
  }

  Future<String?> _placeApprovedCall(Map<String, dynamic> payload) async {
    final phone = (payload['phone'] as String?)?.trim() ?? '';
    final name = (payload['name'] as String?)?.trim() ?? 'Trusted Contact';
    if (phone.isEmpty) {
      throw Exception(
        'The selected approved contact does not have a phone number.',
      );
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Unable to open the phone call flow for $name.');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Opened iPhone call confirmation for $name.';
    }
    return 'Opened Android call flow for $name.';
  }

  Future<String?> _handleRemoteCommand(
    String type,
    Map<String, dynamic> payload,
  ) async {
    switch (type) {
      case RemoteCommandType.startShareLocation:
        await _setShareLocation(true, announce: false);
        return 'Live location sharing started.';
      case RemoteCommandType.stopShareLocation:
        await _setShareLocation(false, announce: false);
        return 'Live location sharing stopped.';
      case RemoteCommandType.playSiren:
        await _setSiren(true);
        return 'Siren started.';
      case RemoteCommandType.stopSiren:
        await _setSiren(false);
        return 'Siren stopped.';
      case RemoteCommandType.placeApprovedCall:
        return _placeApprovedCall(payload);
      case RemoteCommandType.triggerFakeCall:
        await _triggerRemoteFakeCall(payload);
        return 'Remote fake call triggered.';
      case RemoteCommandType.startCheckIn:
        final minutes = (payload['minutes'] as num?)?.toInt() ?? 30;
        final message = (payload['message'] as String?)?.trim();
        await _checkIns.startCheckIn(
          Duration(minutes: minutes),
          message: message == null || message.isEmpty
              ? 'Remote companion check-in'
              : message,
        );
        setState(() => _lastCheckIn = 'Remote timer set');
        return 'Started a $minutes minute check-in.';
      case RemoteCommandType.cancelCheckIn:
        await _checkIns.cancel();
        setState(() => _lastCheckIn = 'No timer');
        return 'Cancelled the active check-in.';
      case RemoteCommandType.setBatterySaver:
        await _setBatteryMode(payload['enabled'] == true);
        return 'Battery saver ${payload['enabled'] == true ? 'enabled' : 'disabled'}.';
      case RemoteCommandType.setMotionSensitivity:
        final value =
            (payload['value'] as num?)?.toDouble() ?? _motionSensitivity;
        await _setMotionSensitivity(value);
        return 'Motion sensitivity set to ${value.toStringAsFixed(1)}.';
      default:
        throw Exception('Unsupported remote command: $type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Her'), centerTitle: true),
      body: PastelBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${_userName ?? ''}!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your safety is our priority.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RadialActions(
              onSos: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SosScreen())),
              onTrusted: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TrustedContactsScreen(),
                ),
              ),
              onRouteGuard: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RouteGuardScreen()),
              ),
              onSafeZones: _openSafeZones,
              onFakeCall: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FakeCallScreen())),
              onSiren: _toggleSiren,
              sirenOn: _sirenOn,
            ),
            const SizedBox(height: 16),
            Text(
              'Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // Quick actions
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Share live location with trusted contacts (periodic)',
                      ),
                      subtitle: Text(_shareLocation ? 'Active' : 'Off'),
                      value: _shareLocation,
                      onChanged: (_) => _toggleShareLocation(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _checkInNow,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Check-in now (notify contacts)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tips section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Safety Tips',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: const Text('Stay Safe at Night'),
                      subtitle: const Text(
                        'Essential tips for walking alone after dark',
                      ),
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => TipsScreen())),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => TipsScreen())),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View All Tips'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // AI status / status chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusChip(
                  icon: Icons.my_location_rounded,
                  label: 'Location',
                  value: _shareLocation ? 'Sharing' : 'Off',
                ),
                _StatusChip(
                  icon: Icons.battery_saver_rounded,
                  label: 'Battery Saver',
                  value: _batteryMode ? 'On' : 'Off',
                  onTap: _openBatterySaver,
                ),
                _StatusChip(
                  icon: Icons.timer_rounded,
                  label: 'Last Check-in',
                  value: _lastCheckIn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialActions extends StatelessWidget {
  final VoidCallback onSos;
  final VoidCallback onTrusted;
  final VoidCallback onRouteGuard;
  final VoidCallback onSafeZones;
  final VoidCallback onFakeCall;
  final VoidCallback onSiren;
  final bool sirenOn;
  const _RadialActions({
    required this.onSos,
    required this.onTrusted,
    required this.onRouteGuard,
    required this.onSafeZones,
    required this.onFakeCall,
    required this.onSiren,
    required this.sirenOn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double size = 320;
    const double radius = 120;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center SOS button
            GestureDetector(
              onLongPress: onSos,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF4D6D), Color(0xFFFF8DB1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF4D6D),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

            // Orbiting actions
            _orbit(
              angleDeg: -90,
              radius: radius,
              child: _bubble(
                icon: Icons.people_alt_rounded,
                label: 'Trusted',
                onTap: onTrusted,
                theme: theme,
              ),
            ),
            _orbit(
              angleDeg: -30,
              radius: radius,
              child: _bubble(
                icon: Icons.assistant_direction_rounded,
                label: 'Route',
                onTap: onRouteGuard,
                theme: theme,
              ),
            ),
            _orbit(
              angleDeg: 30,
              radius: radius,
              child: _bubble(
                icon: Icons.shield_rounded,
                label: 'Safe Zones',
                onTap: onSafeZones,
                theme: theme,
              ),
            ),
            _orbit(
              angleDeg: 90,
              radius: radius,
              child: _bubble(
                icon: Icons.call_rounded,
                label: 'Fake Call',
                onTap: onFakeCall,
                theme: theme,
              ),
            ),
            _orbit(
              angleDeg: 150,
              radius: radius,
              child: _bubble(
                icon: sirenOn
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                label: sirenOn ? 'Stop Siren' : 'Siren',
                onTap: onSiren,
                theme: theme,
              ),
            ),
            _orbit(
              angleDeg: 210,
              radius: radius,
              child: _bubble(
                icon: Icons.timer_rounded,
                label: 'Check-In',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                ),
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _orbit({
    required double angleDeg,
    required double radius,
    required Widget child,
  }) {
    final rad = angleDeg * math.pi / 180.0;
    final dx = radius * math.cos(rad);
    final dy = radius * math.sin(rad);
    return Transform.translate(offset: Offset(dx, dy), child: child);
  }

  static Widget _bubble({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 8),
              ],
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
