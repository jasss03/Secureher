import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

class AiAssistService {
  static final AiAssistService _instance = AiAssistService._internal();
  factory AiAssistService() => _instance;
  AiAssistService._internal();

  final stt.SpeechToText _stt = stt.SpeechToText();
  StreamController<String> _transcriptCtrl = StreamController.broadcast();
  Timer? _kick;

  bool _listening = false;
  bool _isRestarting = false;
  bool _isInitializing = false;
  bool dangerDetected = false;
  String? matchedKeyword;
  String? lastErrorMessage;
  String? lastStatus;

  // Safety Check state
  bool isCheckInActive = false;
  int checkInCountdown = 0;
  Timer? _checkInTimer;
  final StreamController<int> _checkInCtrl = StreamController<int>.broadcast();

  // Keywords to watch for
  final List<String> keywords = const [
    'help',
    'help me',
    'bachao',
    'madad',
    'save',
    'save me',
    'police',
    'emergency',
    'danger',
    'stay away',
    "don't touch me",
    'leave me alone',
    'mummy',
    'papa',
  ];
  final List<String> checkInTriggers = [
    'hey bro',
    "i'll be late",
    "i will be late",
    "hey bro i'll be late",
  ];

  Stream<String> get transcripts => _transcriptCtrl.stream;
  Stream<int> get checkInStatus => _checkInCtrl.stream;

  Future<bool> ensureSpeechPermission({bool request = true}) async {
    if (kIsWeb) return false;
    if (_isInitializing) return _stt.isAvailable;
    _isInitializing = true;
    lastErrorMessage = null;
    
    try {
      if (!request) {
        final hasPermission = await _stt.hasPermission;
        if (!hasPermission) {
          lastErrorMessage = 'Speech recognition permission is disabled in Settings.';
          return false;
        }
        if (_stt.isAvailable) return true;
      }

      final available = await _stt.initialize(
        onError: (error) {
          lastErrorMessage = _describeError(error);
          debugPrint('STT Initialization Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          lastStatus = status;
          debugPrint('STT Status: $status');
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (!available && lastErrorMessage == null) {
        final hasPermission = await _stt.hasPermission;
        lastErrorMessage = hasPermission
            ? 'Speech recognition is not available right now.'
            : 'Speech recognition permission is disabled in Settings.';
      }
      return available;
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> startListening({bool requestPermissions = true}) async {
    if (kIsWeb) return false;

    final available = await ensureSpeechPermission(request: requestPermissions);
    if (!available) return false;
    dangerDetected = false;
    matchedKeyword = null;
    isCheckInActive = false;
    _listening = true;

    // Start continuous listening with periodic restarts to avoid timeouts
    Future<void> beginListeningCycle() async {
      if (_isRestarting) return;
      _isRestarting = true;
      try {
        await _stt.listen(
          onResult: (res) {
            final text = res.recognizedWords.toLowerCase();
            if (text.isNotEmpty) {
              _handleSpeech(text);
            }
          },
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
          ),
        );
      } finally {
        _isRestarting = false;
      }
    }

    await beginListeningCycle();
    _kick?.cancel();
    _kick = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_listening) return;
      // CRITICAL: On iOS, calling listen right after stop/cancel crashes.
      // We must await a full reset.
      try {
        await _stt.cancel();
        // Give the audio engine a breath
        await Future.delayed(const Duration(milliseconds: 500));
        if (_listening) {
          await beginListeningCycle();
        }
      } catch (e) {
        debugPrint('STT Restart Error: $e');
      }
    });
    return true;
  }

  void _handleSpeech(String text) {
    _transcriptCtrl.add(text);

    // If we were waiting for a check-in, ANY speech cancels it
    if (isCheckInActive) {
      _cancelCheckIn();
      return;
    }

    // 1. Check for immediate danger keywords
    for (final k in keywords) {
      if (text.contains(k)) {
        dangerDetected = true;
        matchedKeyword = k;
        return;
      }
    }

    // 2. Check for "Hey Bro" safety check triggers
    for (final trigger in checkInTriggers) {
      if (text.contains(trigger)) {
        _startCheckIn();
        return;
      }
    }
  }

  void _startCheckIn() {
    if (isCheckInActive) return;
    isCheckInActive = true;
    checkInCountdown = 5;
    _checkInCtrl.add(checkInCountdown);

    _checkInTimer?.cancel();
    _checkInTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      checkInCountdown--;
      _checkInCtrl.add(checkInCountdown);

      if (checkInCountdown <= 0) {
        timer.cancel();
        _triggerCheckInDanger();
      }
    });
  }

  void _cancelCheckIn() {
    isCheckInActive = false;
    _checkInTimer?.cancel();
    _checkInCtrl.add(-1); // Signal cancellation
  }

  void _triggerCheckInDanger() {
    if (!isCheckInActive) return;
    isCheckInActive = false;
    dangerDetected = true;
    matchedKeyword = "Hey Bro - Silence Detection";
  }

  String _describeError(SpeechRecognitionError error) {
    switch (error.errorMsg) {
      case 'error_speech_recognizer_disabled':
        return 'Speech recognition is disabled on this iPhone.';
      case 'error_permission':
        return 'Speech recognition permission is disabled in Settings.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Speech recognition needs a stronger network connection.';
      case 'error_no_match':
        return 'Listening started, but no speech was recognized yet.';
      default:
        return 'Speech recognition is temporarily unavailable.';
    }
  }

  Future<void> stop() async {
    _listening = false;
    _kick?.cancel();
    _cancelCheckIn();
    try {
      await _stt.stop();
    } catch (_) {}
    await _transcriptCtrl.close();
    _transcriptCtrl = StreamController.broadcast();
  }
}
