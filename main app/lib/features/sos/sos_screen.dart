import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../services/location_service.dart';
import '../../services/tts_service.dart';
import '../../services/notification_service.dart';
import '../../services/alert_service.dart';
import 'sos_service.dart';
import 'sos_controller.dart';
import '../../services/ai_assist_service.dart';
import '../../services/emergency_messenger.dart';
import '../../services/evidence_service.dart';
import '../../services/siren_service.dart';
import 'evidence_player_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shake/shake.dart';
import 'package:flutter/services.dart';
import 'manage_evidence_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.controller});

  final SosController? controller;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  const _PulsingIcon({required this.icon, this.color});
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _a = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _a,
      child: Icon(widget.icon, color: widget.color),
    );
  }
}

class _SosScreenState extends State<SosScreen> with WidgetsBindingObserver {
  late final SosService _sos;
  late final LocationService _location;
  late final TtsService _tts;
  final _alerts = AlertService();
  final _siren = SirenService();

  bool _isRecording = false;
  String? _alertId;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // GPS
  Position? _lastPos;
  double? _accuracy;
  StreamSubscription<Position>? _posSub;

  // AI assist (Singleton)
  final AiAssistService _ai = AiAssistService();
  bool _danger = false;
  String? _keyword;
  String? _triggerSource;
  String _lastTranscript = '';
  bool _voiceMonitoringActive = false;
  String? _voiceMonitoringIssue;

  // Recent evidence
  final EvidenceService _evidenceService = EvidenceService();
  List<EvidenceItem> _recent = [];
  bool _recentLoading = true;
  bool _permissionLoading = true;
  bool _micPermissionGranted = false;
  bool _speechPermissionGranted = false;
  bool _micNeedsSettings = false;
  bool _speechNeedsSettings = false;

  // Shake detector
  ShakeDetector? _shakeDetector;

  // Voice Check-in state
  int _checkInCountdown = -1;

  // Travel Alone auto-monitor
  bool _travelAloneActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sos = SosService();
    _location = LocationService();
    _tts = TtsService();
    NotificationService.init();
    _refreshPermissionState();
    _loadRecent();
    widget.controller?.bindStartHandler(_startSosFromController);

    // Initialize Shake-to-SOS
    try {
      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (_) {
          if (!_isRecording && mounted) {
            unawaited(HapticFeedback.heavyImpact().catchError((_) {}));
            unawaited(HapticFeedback.vibrate().catchError((_) {}));
            unawaited(
              _startSos(triggerSource: 'Shake', activateSirenImmediately: true),
            );
          }
        },
        shakeThresholdGravity: 2.7, // Requires a vigorous shake
      );
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleTravelAloneSync();
  }

  void _handleTravelAloneSync() {
    final acc = Provider.of<AccessibilityModel>(context);
    if (acc.travelAloneMode && !_isRecording && !_travelAloneActive) {
      _startTravelAloneMonitoring();
    } else if (!acc.travelAloneMode && _travelAloneActive && !_isRecording) {
      _stopTravelAloneMonitoring();
    }
  }

  Future<void> _startTravelAloneMonitoring() async {
    if (_travelAloneActive || _isRecording) return;
    final micGranted = await _sos.ensureMicrophonePermission(request: false);
    if (!micGranted) return;

    try {
      final ok = await _ai.startListening(requestPermissions: false);
      if (ok) {
        setState(() {
          _travelAloneActive = true;
          _voiceMonitoringActive = true;
        });
        _ai.transcripts.listen((t) {
          if (mounted) setState(() => _lastTranscript = t);
          if (_ai.dangerDetected && !_isRecording) {
            _startSos(
              triggerSource: 'Travel Alone Mode',
              activateSirenImmediately: true,
            );
          }
        });
        // Also listen for "Hey Bro" check-ins in travel mode
        _ai.checkInStatus.listen((count) {
          if (mounted) setState(() => _checkInCountdown = count);
          if (count == 0 && !_isRecording) {
            _startSos(
              triggerSource: 'Travel Alone Mode',
              activateSirenImmediately: true,
            );
          }
        });
      }
    } catch (_) {}
  }

  void _stopTravelAloneMonitoring() {
    try {
      _ai.stop();
    } catch (_) {}
    setState(() {
      _travelAloneActive = false;
      _voiceMonitoringActive = false;
      _checkInCountdown = -1;
    });
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    widget.controller?.unbindStartHandler(_startSosFromController);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _posSub?.cancel();
    _sos.dispose();
    _siren.stop(); // auto-stop on exit
    try {
      FlutterBackground.disableBackgroundExecution();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startSosFromController({
    String? triggerSource,
    bool activateSirenImmediately = false,
  }) {
    return _startSos(
      triggerSource: triggerSource,
      activateSirenImmediately: activateSirenImmediately,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState();
    }
  }

  Future<void> _refreshPermissionState() async {
    final micGranted = await _sos.ensureMicrophonePermission(request: false);
    final speechGranted = await _ai.ensureSpeechPermission(request: false);
    final micStatus = await Permission.microphone.status;
    if (!mounted) return;
    setState(() {
      _permissionLoading = false;
      _micPermissionGranted = micGranted;
      _speechPermissionGranted = speechGranted;
      _micNeedsSettings =
          micStatus.isPermanentlyDenied || micStatus.isRestricted;
      _speechNeedsSettings =
          !speechGranted &&
          (_ai.lastErrorMessage?.contains('Settings') ?? false);
    });
  }

  Future<bool> _ensureSosPermissions() async {
    final micGranted = await _sos.ensureMicrophonePermission(request: true);
    final speechGranted = await _ai.ensureSpeechPermission(request: true);

    await _refreshPermissionState();
    if (!mounted) return micGranted;

    if (!micGranted) {
      final micStatus = await Permission.microphone.status;
      if (!mounted) return false;
      final needsSettings =
          micStatus.isPermanentlyDenied || micStatus.isRestricted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsSettings
                ? 'Microphone access is off. Turn it on in Settings to record SOS evidence.'
                : 'Microphone access is required to record SOS evidence.',
          ),
          action: needsSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    openAppSettings();
                  },
                )
              : null,
        ),
      );
      return false;
    }

    if (!speechGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Speech recognition is unavailable. SOS will still record audio, but keyword detection is paused.',
          ),
          action: _speechNeedsSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    openAppSettings();
                  },
                )
              : null,
        ),
      );
    }

    return true;
  }

  String _permissionSummary() {
    if (_permissionLoading) {
      return 'Checking SOS audio and voice-monitoring access...';
    }
    if (!_micPermissionGranted && !_speechPermissionGranted) {
      return 'Allow microphone access so SOS can record evidence. Voice monitoring will be enabled when speech recognition is ready.';
    }
    if (!_micPermissionGranted) {
      return 'Allow microphone access so SOS can record emergency evidence.';
    }
    if (!_speechPermissionGranted) {
      return 'Recording is ready. Voice monitoring is unavailable until speech recognition becomes available.';
    }
    return 'SOS recording and voice monitoring are ready.';
  }

  String _voiceMonitoringSubtitle() {
    if (_danger) {
      return 'Matched keyword: "$_keyword"';
    }
    if (_lastTranscript.isNotEmpty) {
      return _lastTranscript;
    }
    if (!_micPermissionGranted) {
      return 'Microphone access is needed to record SOS evidence.';
    }
    if (!_speechPermissionGranted) {
      return _voiceMonitoringIssue ??
          'Recording is ready, but voice keyword monitoring is unavailable.';
    }
    if (_voiceMonitoringIssue != null) {
      return _voiceMonitoringIssue!;
    }
    return 'Waiting for voice...';
  }

  Future<void> _startSos({
    String? triggerSource,
    bool activateSirenImmediately = false,
  }) async {
    if (_isRecording) {
      if (activateSirenImmediately) {
        await _siren.play();
      }
      return;
    }

    final permissionReady = await _ensureSosPermissions();
    if (!permissionReady) return;
    if (!mounted) return;

    final acc = context.read<AccessibilityModel>();
    if (acc.voiceGuidance) {
      await _tts.speak('Starting SOS. Audio recording active.');
    }

    // Enable background
    try {
      const androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: 'SecureHer SOS Active',
        notificationText: 'Microphone & GPS monitoring...',
      );
      await FlutterBackground.initialize(androidConfig: androidConfig);
      await FlutterBackground.enableBackgroundExecution();
    } catch (_) {}

    // Start GPS
    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          if (mounted) {
            setState(() {
              _lastPos = pos;
              _accuracy = pos.accuracy;
            });
          }
        });
    _lastPos = await _location.getCurrentPosition();

    // Start Alert Session
    try {
      final res = await _alerts.startSosSession(position: _lastPos);
      _alertId = res.alertId;
    } catch (_) {}

    // Start Recording
    final started = await _sos.startRecording(checkPermission: false);
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to start SOS recording. Please check microphone access and try again.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _danger = false;
        _keyword = null;
        _triggerSource = triggerSource;
        _lastTranscript = '';
        _voiceMonitoringActive = false;
        _voiceMonitoringIssue = null;
        _checkInCountdown = -1;
      });
    }

    widget.controller?.setActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // AI Keyword Listener
    if (_speechPermissionGranted) {
      try {
        final ok = await _ai.startListening(requestPermissions: false);
        if (ok) {
          if (mounted) {
            setState(() {
              _voiceMonitoringActive = true;
              _voiceMonitoringIssue = null;
            });
          }
          _ai.transcripts.listen((t) async {
            final prevDanger = _danger;
            if (mounted) {
              setState(() {
                _lastTranscript = t;
                _danger = _ai.dangerDetected;
                _keyword = _ai.matchedKeyword;
              });
            }

            if (!prevDanger && _danger) {
              // TRANSITION TO DANGER: Trigger LOCAL Siren & REMOTE Siren
              await _siren.play().catchError((_) {});
              if (_alertId != null) {
                await _alerts.triggerRemoteSiren(_alertId!).catchError((_) {});
              }
              await EmergencyMessenger.pingTrusted(announceShare: false)
                  .catchError((_) {});
            }
          });

          // NEW: Listen for "Hey Bro" safety check-ins
          _ai.checkInStatus.listen((count) async {
            if (mounted) {
              setState(() => _checkInCountdown = count);
              if (count == 5) {
                await HapticFeedback.heavyImpact().catchError((_) {});
                await _tts.speak(
                  'Security check active. Say any word to cancel.',
                ).catchError((_) {});
              } else if (count == 0) {
                await HapticFeedback.vibrate().catchError((_) {});
                final prevDanger = _danger;
                if (mounted) {
                  setState(() {
                    _danger = true;
                    _keyword = _ai.matchedKeyword ?? 'Voice safety timeout';
                  });
                }
                if (!prevDanger) {
                  await _siren.play().catchError((_) {});
                  if (_alertId != null) {
                    await _alerts.triggerRemoteSiren(_alertId!).catchError((_) {});
                  }
                  await EmergencyMessenger.pingTrusted(announceShare: false)
                      .catchError((_) {});
                }
              }
            }
          });
        } else if (mounted) {
          setState(() {
            _voiceMonitoringActive = false;
            _voiceMonitoringIssue =
                _ai.lastErrorMessage ??
                'Voice keyword monitoring is temporarily unavailable.';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _voiceMonitoringActive = false;
            _voiceMonitoringIssue =
                _ai.lastErrorMessage ??
                'Voice keyword monitoring is temporarily unavailable.';
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _voiceMonitoringActive = false;
        _voiceMonitoringIssue =
            'Speech recognition is unavailable, so keyword monitoring is paused.';
      });
    }

    // Initial alert SMS
    await EmergencyMessenger.pingTrusted(announceShare: false);

    if (activateSirenImmediately) {
      await _siren.play();
      if (_alertId != null) {
        await _alerts.triggerRemoteSiren(_alertId!);
      }
    }

    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      if (_alertId != null && _elapsed.inSeconds % 5 == 0) {
        final pos = await _location.getCurrentPosition();
        if (pos != null) await _alerts.updateLiveLocation(_alertId!, pos);
      }
    });

    await NotificationService.showImmediate(
      title: 'SecureHer SOS Active',
      body: 'Listening for distress keywords...',
    );
  }

  Future<void> _stopSos() async {
    final acc = context.read<AccessibilityModel>();
    try {
      await _ai.stop();
    } catch (_) {}
    await _posSub?.cancel();
    await _siren.stop().catchError((_) {});

    final pos = await _location.getCurrentPosition();
    final savedPath = await _sos.stopAndSaveEncrypted(
      metadata: {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'position': pos == null
            ? null
            : {'lat': pos.latitude, 'lng': pos.longitude},
        'trigger': _triggerSource,
        'ai': {
          'danger': _danger,
          'keyword': _keyword,
          'lastTranscript': _lastTranscript,
          'monitoringActive': _voiceMonitoringActive,
          'monitoringIssue': _voiceMonitoringIssue,
        },
        'type': 'audio_only',
      },
    );

    try {
      if (_alertId != null) {
        await _alerts.closeSosSession(_alertId!, position: pos);
      }
      await _alerts.sendSafeMessage(position: pos);
    } catch (_) {}

    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _checkInCountdown = -1;
    });
    widget.controller?.setActive(false);
    await _loadRecent();
    if (mounted) {
      final status = _danger
          ? 'Keyword "$_keyword" recognized.'
          : _voiceMonitoringActive
          ? 'No distress keywords detected.'
          : (_voiceMonitoringIssue ??
                'Voice keyword monitoring was unavailable.');
      final backupStatus = savedPath == null
          ? ' Audio evidence could not be saved.'
          : ' Encrypted audio evidence saved.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS stopped. $status$backupStatus')),
      );
    }
    if (acc.voiceGuidance) await _tts.speak('SOS stopped.');
  }

  Future<void> _loadRecent() async {
    setState(() => _recentLoading = true);
    final items = await _evidenceService.listRecent(limit: 10);
    if (mounted) {
      setState(() {
        _recent = items;
        _recentLoading = false;
      });
    }
  }

  Future<void> _openItem(EvidenceItem item) async {
    final f = await _evidenceService.decryptForPlayback(item);
    if (f == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This SOS log has metadata, but its encrypted audio file is missing.',
          ),
        ),
      );
      return;
    }
    if (mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EvidencePlayerScreen(file: f)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsedStr = _formatDuration(_elapsed);
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _isRecording
                ? GestureDetector(
                    onLongPress: _stopSos,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: const StadiumBorder(),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.stop_circle_rounded, size: 28),
                      label: Text(
                        'HOLD TO CANCEL • $elapsedStr',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _startSos,
                    icon: const Icon(
                      Icons.radio_button_checked_rounded,
                      size: 28,
                    ),
                    label: const Text(
                      'ONE-TAP SOS',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
            if (_permissionLoading ||
                !_micPermissionGranted ||
                !_speechPermissionGranted) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(
                    _micPermissionGranted
                        ? Icons.verified_user_rounded
                        : Icons.mic_off_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('SOS Permissions'),
                  subtitle: Text(_permissionSummary()),
                  trailing: TextButton(
                    onPressed: () {
                      if (_micNeedsSettings || _speechNeedsSettings) {
                        openAppSettings();
                        return;
                      }
                      _ensureSosPermissions();
                    },
                    child: Text(
                      (_micNeedsSettings || _speechNeedsSettings)
                          ? 'Open Settings'
                          : 'Allow Access',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.gps_fixed_rounded),
                title: Text(
                  _lastPos == null
                      ? 'GPS: locating...'
                      : 'GPS: ${_lastPos!.latitude.toStringAsFixed(5)}, ${_lastPos!.longitude.toStringAsFixed(5)}',
                ),
                subtitle: Text(
                  _accuracy == null
                      ? '—'
                      : 'Accuracy: ±${_accuracy!.toStringAsFixed(0)} m',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_shared_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageEvidenceScreen(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: _danger ? 8 : 1,
              color: _danger
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: _danger
                    ? BorderSide(color: theme.colorScheme.error, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: _PulsingIcon(
                  icon: _isRecording
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  color: _danger
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                title: Text(_danger ? 'DISTRESS DETECTED' : 'Voice Monitoring'),
                subtitle: Text(_voiceMonitoringSubtitle()),
                trailing: _danger
                    ? Icon(
                        Icons.warning_rounded,
                        color: theme.colorScheme.error,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recent SOS logs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recentLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_recent.isEmpty
                        ? const Center(child: Text('No recent SOS logs.'))
                        : ListView.separated(
                            itemCount: _recent.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = _recent[i];
                              final meta = item.metadata ?? {};
                              final danger = (meta['ai'] is Map)
                                  ? ((meta['ai']['danger'] ?? false) as bool)
                                  : false;
                              final keyword = (meta['ai'] is Map)
                                  ? (meta['ai']['keyword']?.toString() ?? '')
                                  : '';
                              final monitoringActive = (meta['ai'] is Map)
                                  ? ((meta['ai']['monitoringActive'] ?? false)
                                        as bool)
                                  : false;
                              final monitoringIssue = (meta['ai'] is Map)
                                  ? (meta['ai']['monitoringIssue']
                                            ?.toString() ??
                                        '')
                                  : '';
                              final subtitle = !item.hasPlayableMedia
                                  ? 'Metadata saved, but the encrypted audio file is missing'
                                  : danger && keyword.isNotEmpty
                                  ? 'Distress keyword detected: $keyword'
                                  : !monitoringActive &&
                                        monitoringIssue.isNotEmpty
                                  ? 'Audio saved. Voice monitoring was unavailable.'
                                  : 'Encrypted audio backup saved';
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    !item.hasPlayableMedia
                                        ? Icons.warning_amber_rounded
                                        : danger
                                        ? Icons.warning_amber_rounded
                                        : item.isAudio
                                        ? Icons.audio_file_rounded
                                        : Icons.event_available_rounded,
                                    color: danger || !item.hasPlayableMedia
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                                  title: Text(item.formattedTime),
                                  subtitle: Text(subtitle),
                                  trailing: Icon(
                                    item.hasPlayableMedia
                                        ? Icons.play_circle_fill_rounded
                                        : Icons.info_outline_rounded,
                                  ),
                                  onTap: item.hasPlayableMedia
                                      ? () => _openItem(item)
                                      : null,
                                ),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
      floatingActionButton: _checkInCountdown > 0
          ? Container(
              margin: const EdgeInsets.only(bottom: 80, left: 32, right: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(blurRadius: 12, color: Colors.black26),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulsingIcon(
                    icon: Icons.warning_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SAFETY CHECK IN PROGRESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Siren will trigger in $_checkInCountdown seconds. Say any word to cancel.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
