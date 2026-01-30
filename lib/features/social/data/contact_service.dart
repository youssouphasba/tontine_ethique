import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contactServiceProvider = Provider<ContactService>((ref) {
  return ContactService(FirebaseFirestore.instance);
});

class ContactService {
  final FirebaseFirestore _firestore;

  ContactService(this._firestore);

  /// Requests permission to access contacts.
  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  /// Fetches contacts, normalizes phone numbers, and finds matches in Firestore.
  /// Returns a list of [ContactMatch] containing the registered user data and the contact name.
  Future<List<ContactMatch>> findRegisteredContacts() async {
    // 1. Check/Request Permission
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      throw Exception('Permission denied');
    }

    // 2. Fetch Device Contacts (with phones)
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) return [];

    // 3. Normalize Phones & Map to Contact Name
    // Map<NormalizedPhone, ContactName>
    final Map<String, String> phoneToContactName = {};
    
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        final normalized = _normalizePhone(phone.number);
        if (normalized.length >= 8) { // Basic filter for valid-ish numbers
          // Keep the first name found for this number
          phoneToContactName.putIfAbsent(normalized, () => contact.displayName);
        }
      }
    }

    if (phoneToContactName.isEmpty) return [];

    // 4. Batch Query Firestore (chunks of 10 for 'whereIn')
    final List<String> allPhones = phoneToContactName.keys.toList();
    final List<ContactMatch> matches = [];
    
    // Process in chunks of 10
    for (var i = 0; i < allPhones.length; i += 10) {
      final end = (i + 10 < allPhones.length) ? i + 10 : allPhones.length;
      final chunk = allPhones.sublist(i, end);
      
      try {
        // Query users where 'phone' is in this chunk
        // Note: This relies on 'phone' in Firestore being normalized similarly/compatible.
        // If Firestore phones have country codes (+33...) and contacts don't, this might miss.
        // For this MVP, we assume basic matching. Future: Use hash or standardized format.
        
        final querySnapshot = await _firestore
            .collection('users')
            .where('phone', whereIn: chunk)
            .get();

        for (var doc in querySnapshot.docs) {
          final userData = doc.data();
          final userPhone = userData['phone'] as String?;
          
          if (userPhone != null && phoneToContactName.containsKey(userPhone)) {
             matches.add(ContactMatch(
               userId: doc.id,
               userData: userData,
               contactName: phoneToContactName[userPhone]!,
             ));
          }
        }
      } catch (e) {
        debugPrint('Error querying contacts chunk: $e');
      }
    }

    return matches;
  }

  String _normalizePhone(String phone) {
    // Remove spaces, dashes, parentheses
    return phone.replaceAll(RegExp(r'[ \-\(\)]'), '');
  }
}

class ContactMatch {
  final String userId;
  final Map<String, dynamic> userData;
  final String contactName; // Name from device address book

  ContactMatch({
    required this.userId, 
    required this.userData, 
    required this.contactName
  });
}
