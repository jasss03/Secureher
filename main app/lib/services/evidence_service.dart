import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'storage_service.dart';

class EvidenceItem {
  EvidenceItem({
    required this.baseName,
    required this.timestamp,
    this.encryptedMediaPath,
    this.mediaExtension,
    this.sizeBytes,
    this.metadata,
  });

  final String baseName;
  final DateTime timestamp;
  final String? encryptedMediaPath;
  final String? mediaExtension;
  final int? sizeBytes;
  final Map<String, dynamic>? metadata;

  String get formattedTime => DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  bool get hasPlayableMedia => encryptedMediaPath != null;
  bool get isAudio =>
      mediaExtension == '.m4a' ||
      mediaExtension == '.aac' ||
      mediaExtension == '.wav' ||
      metadata?['type'] == 'audio_only';
}

class EvidenceService {
  final StorageService _storage = StorageService();

  Future<List<EvidenceItem>> listRecent({int limit = 10}) async {
    final dir = await _storage.evidenceDir();
    if (!await dir.exists()) return [];
    final entries = await dir.list().toList();
    final jsonFiles = entries
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>();

    final items = <EvidenceItem>[];
    const extensions = ['.m4a.enc', '.mp4.enc', '.aac.enc', '.wav.enc'];
    for (final jf in jsonFiles) {
      try {
        final name = p.basenameWithoutExtension(jf.path);
        final content = await jf.readAsString();
        final meta = jsonDecode(content) as Map<String, dynamic>;
        final ts =
            DateTime.tryParse(meta['timestamp']?.toString() ?? '') ??
            (await jf.lastModified());
        String? mediaPath;
        String? mediaExtension;
        int? size;
        for (final ext in extensions) {
          final candidate = File(p.join(dir.path, '$name$ext'));
          if (await candidate.exists()) {
             final length = await candidate.length();
             if (length > 0) {
               mediaPath = candidate.path;
               mediaExtension = ext.replaceAll('.enc', '');
               size = length;
               break;
             }
          }
        }
        items.add(
          EvidenceItem(
            baseName: name,
            timestamp: ts,
            encryptedMediaPath: mediaPath,
            mediaExtension: mediaExtension,
            sizeBytes: size,
            metadata: meta,
          ),
        );
      } catch (_) {
        // Skip malformed
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (items.length > limit) return items.sublist(0, limit);
    return items;
  }

  Future<File?> decryptForPlayback(EvidenceItem item) async {
    if (item.encryptedMediaPath == null) return null;
    final f = File(item.encryptedMediaPath!);
    return StorageService().decryptToTempFile(f);
  }
}
