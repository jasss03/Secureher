import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/branding.dart';
import '../../services/notification_service.dart';
import '../../services/cloud_upload_service.dart';
class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final _name = TextEditingController(text: 'Mom');
  final _delayCtrl = TextEditingController(text: '5');
  bool _voice = true;
  bool _fullscreenNotification = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final delay = int.tryParse(_delayCtrl.text.trim()) ?? 5;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: delay), () async {
      final caller = _name.text.trim().isEmpty ? 'Unknown' : _name.text.trim();
      if (_fullscreenNotification) {
        await NotificationService.showIncomingCallFullScreen(caller: caller);
      } else {
        // In-app fallback UI
        // ignore: use_build_context_synchronously
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                IncomingCallScreen(caller: caller, playVoice: _voice),
          ),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fake call scheduled in $delay seconds')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fake Call')),
      body: PastelBackground(
        child: Center(
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded, size: 40),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Caller name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _delayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Delay (seconds)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _voice,
                    onChanged: (v) => setState(() => _voice = v),
                    title: const Text('Play ringtone'),
                  ),
                  SwitchListTile(
                    value: _fullscreenNotification,
                    onChanged: (v) =>
                        setState(() => _fullscreenNotification = v),
                    title: const Text(
                      'Use Android full-screen incoming call style',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.call),
                    label: const Text('Start Fake Call'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IncomingCallScreen extends StatefulWidget {
  final String caller;
  final bool playVoice;

  const IncomingCallScreen({
    super.key,
    required this.caller,
    required this.playVoice,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  FlutterRingtonePlayer? _ring;
  bool _showCallOptions = false;

  @override
  void initState() {
    super.initState();
    if (widget.playVoice) {
      _ring = FlutterRingtonePlayer();
      _ring!.playRingtone(looping: true, volume: 1.0, asAlarm: false);
    }

    // Show call options after a short delay to simulate Android 15 behavior
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showCallOptions = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _ring?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF121212), Colors.black],
              ),
            ),
          ),

          // Call content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Caller info
                AnimatedOpacity(
                  opacity: _showCallOptions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      // Caller avatar with ripple effect
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ripple effects
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),

                          // Avatar
                          const CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Caller name
                      Text(
                        widget.caller,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Call status
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_in_talk,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Mobile • Incoming call',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Call actions
                AnimatedOpacity(
                  opacity: _showCallOptions ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      // Quick actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildQuickAction(Icons.message, 'Text'),
                          const SizedBox(width: 32),
                          _buildQuickAction(Icons.alarm, 'Remind me'),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Call buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCallButton(
                            icon: Icons.call_end_rounded,
                            color: Colors.red,
                            onPressed: () => Navigator.of(context).pop(),
                            label: 'Decline',
                          ),
                          _buildCallButton(
                            icon: Icons.call_rounded,
                            color: Colors.green,
                            onPressed: () {
                              // Stop ringtone when call is accepted
                              _ring?.stop();
                              // Navigate to active call screen instead of popping
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ActiveCallScreen(caller: widget.caller),
                                ),
                              );
                            },
                            label: 'Accept',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.only(bottom: 8),
          child: FloatingActionButton(
            heroTag: label,
            backgroundColor: color,
            onPressed: onPressed,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

class ActiveCallScreen extends StatefulWidget {
  final String caller;

  const ActiveCallScreen({super.key, required this.caller});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final Stopwatch _callDuration = Stopwatch();
  String _durationText = "00:00";
  Timer? _durationTimer;
  bool _isMuted = false;
  bool _isSpeaker = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordFilePath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _callDuration.start();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final minutes = _callDuration.elapsed.inMinutes;
          final seconds = _callDuration.elapsed.inSeconds % 60;
          _durationText =
              "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        });
      }
    });
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordFilePath = '${dir.path}/fake_call_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: _recordFilePath!
        );
        if (mounted) setState(() => _isRecording = true);
        print("FakeCall: Recording started at $_recordFilePath");
      } else {
        print("FakeCall: Microphone permission denied or unavailable.");
      }
    } catch (e) {
      print("FakeCall: Failed to start recording: $e");
    }
  }

  Future<void> _endCall() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          _recordFilePath = path; // Capture the final returned path
        }
        print("FakeCall: Recording stopped, final path: $_recordFilePath");
      } catch (e) {
        print("FakeCall: Error stopping recording: $e");
      }
    }
    
    if (_recordFilePath != null) {
      final file = File(_recordFilePath!);
      if (file.existsSync()) {
        final user = FirebaseAuth.instance.currentUser;
        print("FakeCall: Handing over recording to CloudUploadService...");
        // Do not await, let it upload in background
        CloudUploadService().uploadRecordingFile(file, user);
      } else {
        print("FakeCall: The file does not exist at path: $_recordFilePath");
      }
    } else {
      print("FakeCall: _recordFilePath is null.");
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callDuration.stop();
    _durationTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF121212), Colors.black],
              ),
            ),
          ),

          // Call content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Caller info
                Column(
                  children: [
                    // Caller avatar
                    const CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 44),
                    ),

                    const SizedBox(height: 24),

                    // Caller name
                    Text(
                      widget.caller,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Call duration
                    Text(
                      _durationText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Call actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Call control buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: Icons.mic_off,
                            label: 'Mute',
                            isActive: _isMuted,
                            onPressed: () =>
                                setState(() => _isMuted = !_isMuted),
                          ),
                          _buildControlButton(
                            icon: Icons.dialpad,
                            label: 'Keypad',
                            onPressed: () {},
                          ),
                          _buildControlButton(
                            icon: Icons.volume_up,
                            label: 'Speaker',
                            isActive: _isSpeaker,
                            onPressed: () =>
                                setState(() => _isSpeaker = !_isSpeaker),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // End call button
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: FloatingActionButton(
                          backgroundColor: Colors.red,
                          onPressed: _endCall,
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const Text(
                        'End call',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
