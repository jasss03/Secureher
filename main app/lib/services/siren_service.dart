import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

class SirenService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play() async {
    try {
      // FORCE SYSTEM VOLUME TO 100%
      await PerfectVolumeControl.setVolume(1.0);
      
      // 1. Try playing as an Alarm (highest priority, ignores silent mode on many devices)
      await FlutterRingtonePlayer().play(
        fromAsset: 'assets/sounds/siren.mp3',
        ios: IosSounds.alarm,
        android: AndroidSounds.alarm,
        volume: 1.0, // Full stream volume
        looping: true,
        asAlarm: true,
      );
    } catch (_) {
      // 2. Fallback to audioplayers if the above fails
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/siren.mp3'));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await FlutterRingtonePlayer().stop();
      await _player.stop();
    } catch (_) {}
  }
}
