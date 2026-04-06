import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ManageEvidenceScreen extends StatefulWidget {
  const ManageEvidenceScreen({super.key});
  @override
  State<ManageEvidenceScreen> createState() => _ManageEvidenceScreenState();
}

class _ManageEvidenceScreenState extends State<ManageEvidenceScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dir = await getApplicationDocumentsDirectory();
    final ev = Directory('${dir.path}/evidence');
    if (!await ev.exists()) {
      setState(() {
        _files = [];
        _loading = false;
      });
      return;
    }
    final list = await ev.list().toList();
    list.sort((a, b) => b.path.compareTo(a.path));
    setState(() {
      _files = list;
      _loading = false;
    });
  }

  Future<void> _delete(FileSystemEntity f) async {
    try {
      await f.delete();
    } catch (_) {}
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Evidence')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? const Center(child: Text('No evidence saved.'))
          : ListView.separated(
              itemCount: _files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final f = _files[i];
                final name = f.path.split('/').last;
                final size = (f is File) ? f.lengthSync() : 0;
                return ListTile(
                  title: Text(name),
                  subtitle: Text('${(size / (1024)).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _delete(f),
                  ),
                );
              },
            ),
    );
  }
}
