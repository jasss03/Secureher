import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/contacts_service.dart';
import '../../widgets/branding.dart';

// ─── Indian phone validator ───────────────────────────────────────────────────
String? _validateIndianPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Phone number is required';
  String d = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (d.startsWith('+91'))       d = d.substring(3);
  else if (d.startsWith('0091')) d = d.substring(4);
  else if (d.startsWith('091'))  d = d.substring(3);
  else if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  if (d.length != 10) return 'Enter exactly 10 digits';
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(d)) return 'Invalid Indian mobile number';
  return null;
}

String _normalizeIndian(String raw) {
  String d = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (d.startsWith('+91'))       d = d.substring(3);
  else if (d.startsWith('0091')) d = d.substring(4);
  else if (d.startsWith('091'))  d = d.substring(3);
  else if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  return '+91$d';
}

// ─── Native contact channel ───────────────────────────────────────────────────
const _contactChannel = MethodChannel('com.secureher/contacts');

Future<Map<String, dynamic>?> _pickNativeContact() async {
  final result = await _contactChannel.invokeMethod<Map>('pickContact');
  if (result == null) return null;
  return {
    'name': result['name'] as String? ?? '',
    'phones': List<String>.from((result['phones'] as List?) ?? []),
    'emails': List<String>.from((result['emails'] as List?) ?? []),
  };
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _svc = ContactsService();
  List<ContactEntry> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _svc.getContacts();
    if (mounted) setState(() { _contacts = list; _loading = false; });
  }

  Future<void> _addManually() async {
    final res = await showDialog<ContactEntry>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (res != null) { await _svc.addContact(res); await _load(); }
  }

  Future<void> _pickFromContacts() async {
    try {
      final data = await _pickNativeContact();
      if (data == null || !mounted) return; // cancelled

      final name   = data['name'] as String;
      final phones = data['phones'] as List<String>;
      final emails = data['emails'] as List<String>;

      if (phones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This contact has no phone number.')),
        );
        return;
      }

      // If multiple numbers, let user pick
      String selectedRaw;
      if (phones.length == 1) {
        selectedRaw = phones.first;
      } else {
        final chosen = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(name.isEmpty ? 'Choose number' : name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: phones.map((p) => ListTile(
                leading: const Icon(Icons.phone),
                title: Text(p),
                onTap: () => Navigator.pop(ctx, p),
              )).toList(),
            ),
            actions: [TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            )],
          ),
        );
        if (chosen == null || !mounted) return;
        selectedRaw = chosen;
      }

      // Validate Indian number; if invalid open manual dialog pre-filled
      final err = _validateIndianPhone(selectedRaw);
      if (err != null) {
        final corrected = await showDialog<ContactEntry>(
          context: context,
          builder: (_) => _AddContactDialog(
            prefillName: name,
            prefillPhone: selectedRaw.replaceAll(RegExp(r'[\s\-+]'), ''),
          ),
        );
        if (corrected != null) { await _svc.addContact(corrected); await _load(); }
        return;
      }

      // Confirm before adding
      final entry = ContactEntry(
        name: name.trim().isEmpty ? 'Contact' : name,
        phone: _normalizeIndian(selectedRaw),
        email: emails.isNotEmpty ? emails.first : null,
      );
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add trusted contact?'),
          content: ListTile(
            leading: CircleAvatar(
              child: Text(entry.name[0].toUpperCase()),
            ),
            title: Text(entry.name),
            subtitle: Text(entry.phone),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Add')),
          ],
        ),
      );
      if (ok == true) { await _svc.addContact(entry); await _load(); }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open contacts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        actions: [
          if (_contacts.length < 5)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'pick' ? _pickFromContacts() : _addManually(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Add contact',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pick',
                  child: ListTile(leading: Icon(Icons.contacts), title: Text('From Contacts'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'manual',
                  child: ListTile(leading: Icon(Icons.edit),    title: Text('Enter manually'), contentPadding: EdgeInsets.zero)),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Chip(label: const Text('Max 5'),
                backgroundColor: theme.colorScheme.surfaceVariant),
            ),
        ],
      ),
      body: PastelBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline, size: 64,
                              color: theme.colorScheme.primary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('No trusted contacts yet', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('Add up to 5 people who will be alerted\nin an emergency.',
                              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 24),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            FilledButton.icon(
                              onPressed: _pickFromContacts,
                              icon: const Icon(Icons.contacts),
                              label: const Text('From Contacts'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _addManually,
                              icon: const Icon(Icons.edit),
                              label: const Text('Manually'),
                            ),
                          ]),
                        ]),
                      )
                    : ListView.separated(
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = _contacts[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(c.phone),
                                  if (c.relationship != null)
                                    Text(c.relationship!,
                                        style: TextStyle(fontSize: 11,
                                            color: theme.colorScheme.primary)),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remove contact?'),
                                      content: Text('Remove ${c.name}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) { await _svc.removeAt(i); await _load(); }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}

// ─── Manual Add Dialog ────────────────────────────────────────────────────────
class _AddContactDialog extends StatefulWidget {
  final String? prefillName;
  final String? prefillPhone;
  const _AddContactDialog({this.prefillName, this.prefillPhone});
  @override State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _email = TextEditingController();
  final _rel   = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name  = TextEditingController(text: widget.prefillName  ?? '');
    _phone = TextEditingController(text: widget.prefillPhone ?? '');
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _email.dispose(); _rel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Trusted Contact'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: const Icon(Icons.phone),
                prefix: const Text('+91 '),
                counterText: '${_phone.text.length}/10',
                helperText: '10-digit Indian mobile (6–9XXXXXXXXX)',
              ),
              onChanged: (_) => setState(() {}),
              validator: _validateIndianPhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rel,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
                prefixIcon: Icon(Icons.favorite_border),
                hintText: 'e.g. Mother, Friend'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(ContactEntry(
                name:         _name.text.trim(),
                phone:        _normalizeIndian(_phone.text.trim()),
                email:        _email.text.trim().isEmpty ? null : _email.text.trim(),
                relationship: _rel.text.trim().isEmpty   ? null : _rel.text.trim(),
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
