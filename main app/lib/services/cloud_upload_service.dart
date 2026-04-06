import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;

class CloudUploadResult {
  final String? url;
  final String? path;
  CloudUploadResult({this.url, this.path});
}

class CloudUploadService {
  Future<CloudUploadResult?> uploadEvidenceFile(File file, {Map<String, String>? customMetadata}) async {
    try {
      final name = p.basename(file.path);
      final ref = FirebaseStorage.instance.ref().child('evidence/$name');
      
      SettableMetadata? metadata;
      if (customMetadata != null) {
        metadata = SettableMetadata(customMetadata: customMetadata);
      }
      
      final task = await ref.putFile(file, metadata);
      final url = await task.ref.getDownloadURL();
      return CloudUploadResult(url: url, path: task.ref.fullPath);
    } catch (_) {
      return null;
    }
  }

  Future<CloudUploadResult?> uploadRecordingFile(File file, User? user) async {
    try {
      if (!file.existsSync()) {
        print("CloudUploadService: File does not exist at ${file.path}");
        return null;
      }
      
      final name = p.basename(file.path);
      final ref = FirebaseStorage.instance.ref().child('recordings/${user?.uid ?? 'unknown'}/$name');
      
      final metadata = SettableMetadata(
        customMetadata: {
          'userId': user?.uid ?? 'unknown',
          'email': user?.email ?? 'unknown',
          'displayName': user?.displayName ?? 'unknown',
        },
      );

      print("CloudUploadService: Starting upload to ${ref.fullPath}");
      final task = await ref.putFile(file, metadata);
      final url = await task.ref.getDownloadURL();
      print("CloudUploadService: Upload successful! $url");
      return CloudUploadResult(url: url, path: task.ref.fullPath);
    } catch (e, stackTrace) {
      print("CloudUploadService Error: $e");
      print("CloudUploadService StackTrace: $stackTrace");
      return null;
    }
  }
}
