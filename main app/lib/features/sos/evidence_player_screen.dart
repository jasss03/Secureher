import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

class EvidencePlayerScreen extends StatefulWidget {
  const EvidencePlayerScreen({super.key, required this.file});
  final File file;

  @override
  State<EvidencePlayerScreen> createState() => _EvidencePlayerScreenState();
}

class _EvidencePlayerScreenState extends State<EvidencePlayerScreen> {
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  bool _audioPlaying = false;

  bool get _isVideo => widget.file.path.toLowerCase().endsWith('.mp4');

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _initialized = true);
          _videoController!.play();
        });
    } else {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _audioPlaying = state == PlayerState.playing;
          _initialized = true;
        });
      });
      _audioPlayer.play(DeviceFileSource(widget.file.path));
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    try {
      widget.file.delete();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Recording')),
      body: Center(
        child: _initialized
            ? (_isVideo
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _audioPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.audio_file_rounded,
                          size: 96,
                        ),
                        const SizedBox(height: 16),
                        const Text('SOS Audio Evidence'),
                        const SizedBox(height: 8),
                        Text(
                          _audioPlaying ? 'Playing encrypted backup' : 'Paused',
                        ),
                      ],
                    ))
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              onPressed: () {
                if (_isVideo) {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                } else {
                  _audioPlaying
                      ? _audioPlayer.pause()
                      : _audioPlayer.play(DeviceFileSource(widget.file.path));
                }
              },
              child: Icon(
                _isVideo
                    ? (_videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow)
                    : (_audioPlaying ? Icons.pause : Icons.play_arrow),
              ),
            )
          : null,
    );
  }
}
