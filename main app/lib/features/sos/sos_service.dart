import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../services/cloud_upload_service.dart';
import '../../services/storage_service.dart';

class SosService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _activeRecordingPath;

  Future<bool> ensureMicrophonePermission({bool request = true}) async {
    if (kIsWeb) return false;
    try {
      final hasRecorderPermission = await _recorder.hasPermission(
        request: request,
      );
      if (hasRecorderPermission) {
        return true;
      }
    } catch (_) {}

    var status = await Permission.microphone.status;
    if (!status.isGranted && request) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      return false;
    }

    try {
      return await _recorder.hasPermission(request: false);
    } catch (_) {
      return true;
    }
  }

  Future<bool> startRecording({bool checkPermission = true}) async {
    if (checkPermission && !await ensureMicrophonePermission()) return false;
    if (await _recorder.isRecording()) return false;

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1);
      await _recorder.start(config, path: path);
      _isRecording = true;
      _activeRecordingPath = path;
      return true;
    } catch (error) {
      debugPrint('SOS startRecording failed: $error');
      return false;
    }
  }

  Future<String?> stopAndSaveEncrypted({Map<String, dynamic>? metadata}) async {
    if (!_isRecording) return null;
    final storage = StorageService();
    try {
      final path = await _recorder.stop() ?? _activeRecordingPath;
      _isRecording = false;
      _activeRecordingPath = null;
      if (path == null) return null;

      final file = await _waitForRecordedFile(path);
      if (file == null || !await file.exists() || await file.length() == 0) {
        debugPrint('SOS audio file was empty or missing after stop: $path');
        return null;
      }

      final bytes = await file.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final baseName = 'sos_$ts';
      final encName = '$baseName.m4a.enc';

      // 1. Save locally (encrypted)
      final saved = await storage.saveEncryptedBytes(encName, bytes);

      // 2. Try cloud upload
      CloudUploadResult? uploadResult;
      try {
        final alertId = metadata?['alertId']?.toString();
        uploadResult = await CloudUploadService().uploadEvidenceFile(
          file,
          customMetadata: alertId != null ? {'alertId': alertId} : null,
        );
      } catch (error) {
        debugPrint('SOS cloud upload failed: $error');
      }

      // 3. Save sidecar metadata with storage details
      final sidecar = <String, dynamic>{
        ...?metadata,
        'type': metadata?['type'] ?? 'audio_only',
        'storage': {
          'savedLocally': true,
          'localEncryptedPath': saved.path,
          'uploadedToCloud': uploadResult != null,
          if (uploadResult?.path != null) 'remotePath': uploadResult!.path,
          if (uploadResult?.url != null) 'remoteUrl': uploadResult!.url,
          'contentType': 'audio/m4a',
        },
      };
      await storage.saveJsonSidecar(baseName, sidecar);

      // 4. Delete plaintext temporary file
      try {
        await file.delete();
      } catch (error) {
        debugPrint('Failed to delete SOS temp file: $error');
      }

      return saved.path;
    } catch (error) {
      debugPrint('SOS stopAndSaveEncrypted failed: $error');
      return null;
    }
  }

  Future<File?> _waitForRecordedFile(String path) async {
    final file = File(path);
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return file;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  void dispose() {
    _recorder.dispose();
    _activeRecordingPath = null;
  }
}
