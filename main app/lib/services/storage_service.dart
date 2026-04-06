import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';

class StorageService {
  // In a real app, derive/store the key securely (e.g., from Keychain/Keystore)
  final enc.Key _key = enc.Key.fromUtf8('32charssecretkey32charssecretkey');
  final enc.IV _iv = enc.IV.fromLength(16);

  Future<Directory> _evidenceDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/evidence');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> evidenceDir() => _evidenceDir();

  Future<File> saveEncryptedBytes(String filename, List<int> data) async {
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encryptBytes(data, iv: _iv).bytes;
    final dir = await _evidenceDir();
    final file = File('${dir.path}/$filename');
    return file.writeAsBytes(encrypted, flush: true);
  }

  Future<File> saveJsonSidecar(
    String baseNameWithoutExt,
    Map<String, dynamic> json,
  ) async {
    final dir = await _evidenceDir();
    final file = File('${dir.path}/$baseNameWithoutExt.json');
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
  }

  Future<File?> decryptToTempFile(File encryptedFile) async {
    try {
      if (!await encryptedFile.exists()) {
        debugPrint('Decryption failed: Encrypted file not found at ${encryptedFile.path}');
        return null;
      }
      final bytes = await encryptedFile.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('Decryption failed: Encrypted file is empty.');
        return null;
      }

      final encrypter = enc.Encrypter(enc.AES(_key));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(bytes), iv: _iv);
      
      final tempDir = await getTemporaryDirectory();
      final name = encryptedFile.path.split('/').last;
      final base = name.endsWith('.enc')
          ? name.substring(0, name.length - 4)
          : name;
      
      // Use temporary directory instead of documents to avoid clutter
      final out = File('${tempDir.path}/play_$base');
      await out.writeAsBytes(decrypted, flush: true);
      return out;
    } catch (e) {
      debugPrint('Decryption Exception: $e');
      return null;
    }
  }
}
