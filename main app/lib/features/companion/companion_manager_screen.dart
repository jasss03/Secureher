import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/companion_service.dart';

class CompanionManagerScreen extends StatefulWidget {
  const CompanionManagerScreen({super.key});

  @override
  State<CompanionManagerScreen> createState() => _CompanionManagerScreenState();
}

class _CompanionManagerScreenState extends State<CompanionManagerScreen> {
  final CompanionService _companionService = CompanionService();
  List<Map<String, dynamic>> _linkedCompanions = [];
  bool _isLoading = true;
  String? _linkCode;
  bool _generatingCode = false;

  @override
  void initState() {
    super.initState();
    _loadCompanions();
  }

  Future<void> _loadCompanions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final companions = await _companionService.getLinkedCompanions();
      setState(() {
        _linkedCompanions = companions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading companions: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _generateLinkCode() async {
    setState(() {
      _generatingCode = true;
    });

    try {
      final code = await _companionService.createLinkCode();
      setState(() {
        _linkCode = code;
        _generatingCode = false;
      });
    } catch (e) {
      setState(() {
        _generatingCode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating link code: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _removeCompanion(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Companion'),
        content: Text('Are you sure you want to remove $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _companionService.removeCompanion(id);
        _loadCompanions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Companion removed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing companion: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  void _copyCodeToClipboard() {
    if (_linkCode != null) {
      Clipboard.setData(ClipboardData(text: _linkCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link code copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Companion App'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Link New Companion',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate a code to link the SecureHer Companion app with this app. The code will expire after 10 minutes.',
                          ),
                          const SizedBox(height: 16),
                          if (_linkCode != null) ...[
                            Center(
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: _linkCode!,
                                    version: QrVersions.auto,
                                    size: 200,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Code: $_linkCode',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy Code'),
                                    onPressed: _copyCodeToClipboard,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _generatingCode
                                  ? null
                                  : _generateLinkCode,
                              child: _generatingCode
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Generate Link Code'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Linked Companions (${_linkedCompanions.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_linkedCompanions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No companion apps linked yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _linkedCompanions.length,
                      itemBuilder: (context, index) {
                        final companion = _linkedCompanions[index];
                        final lastActive = companion['lastActive'] != null
                            ? (companion['lastActive'] as Timestamp).toDate()
                            : null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.phone_android),
                            ),
                            title: Text(
                              companion['companionName'] ?? 'Companion App',
                            ),
                            subtitle: Text(
                              lastActive != null
                                  ? 'Last active: ${_formatDate(lastActive)}'
                                  : 'Never active',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeCompanion(
                                companion['id'],
                                companion['companionName'] ?? 'Companion App',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
