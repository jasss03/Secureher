import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'companion_contract.dart';

class ContactEntry {
  final String? id;
  final String name;
  final String phone;
  final String? email;
  final String? relationship;
  ContactEntry({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.relationship,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'relationship': relationship,
  };

  static ContactEntry fromJson(Map<String, dynamic> j) => ContactEntry(
    id: j['id'] as String?,
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'] as String?,
    relationship: j['relationship'] as String?,
  );
}

class ContactsService {
  static const _key = 'trusted_contacts_v1';

  bool get _cloudEnabled =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  CollectionReference<Map<String, dynamic>>? get _itemsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(CompanionCollections.trustedContacts)
        .doc(uid)
        .collection('items');
  }

  String _makeId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _saveLocal(List<ContactEntry> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(contacts.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<List<ContactEntry>> getContacts() async {
    if (_cloudEnabled && _itemsRef != null) {
      final snapshot = await _itemsRef!.get();
      final contacts = snapshot.docs
          .map(
            (doc) => ContactEntry(
              id: doc.id,
              name: doc.data()['name'] ?? '',
              phone: doc.data()['phone'] ?? '',
              email: doc.data()['email'] as String?,
              relationship: doc.data()['relationship'] as String?,
            ),
          )
          .toList();
      await _saveLocal(contacts);
      return contacts;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(ContactEntry.fromJson).toList();
  }

  Future<void> saveContacts(List<ContactEntry> contacts) async {
    final normalized = contacts
        .map(
          (contact) => ContactEntry(
            id: contact.id ?? _makeId(),
            name: contact.name,
            phone: contact.phone,
            email: contact.email,
            relationship: contact.relationship,
          ),
        )
        .toList();
    await _saveLocal(normalized);

    if (_cloudEnabled && _itemsRef != null) {
      final existing = await _itemsRef!.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existing.docs) {
        if (!normalized.any((contact) => contact.id == doc.id)) {
          batch.delete(doc.reference);
        }
      }
      for (final contact in normalized) {
        batch.set(_itemsRef!.doc(contact.id), {
          'kind': 'trusted_contact',
          'mainUserId': FirebaseAuth.instance.currentUser!.uid,
          'name': contact.name,
          'phone': contact.phone,
          'email': contact.email,
          'relationship': contact.relationship,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> addContact(ContactEntry c) async {
    final contact = ContactEntry(
      id: c.id ?? _makeId(),
      name: c.name,
      phone: c.phone,
      email: c.email,
      relationship: c.relationship,
    );
    final list = await getContacts();
    list.add(contact);
    await _saveLocal(list);

    if (_cloudEnabled && _itemsRef != null) {
      await _itemsRef!.doc(contact.id).set({
        'kind': 'trusted_contact',
        'mainUserId': FirebaseAuth.instance.currentUser!.uid,
        'name': contact.name,
        'phone': contact.phone,
        'email': contact.email,
        'relationship': contact.relationship,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeAt(int index) async {
    final list = await getContacts();
    if (index < 0 || index >= list.length) return;
    final removed = list.removeAt(index);
    await _saveLocal(list);

    if (_cloudEnabled && _itemsRef != null && removed.id != null) {
      await _itemsRef!.doc(removed.id).delete();
    }
  }
}
