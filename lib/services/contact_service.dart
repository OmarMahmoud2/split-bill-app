import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactService {
  Future<List<Contact>?> getAllContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return null;
    }
    return await FlutterContacts.getContacts(withProperties: true);
  }

  Future<List<Map<String, dynamic>>> identifyUsers(
    List<Contact> contacts,
  ) async {
    List<Map<String, dynamic>> results = [];
    final db = FirebaseFirestore.instance;

    // 1. Prepare a map of normalized phone -> Contact for easy lookup
    // We'll store multiple variations to check against DB
    Map<String, Contact> phoneToContactMap = {};
    List<String> allVariationsToCheck = [];

    for (var contact in contacts) {
      if (contact.phones.isEmpty) continue;
      String rawPhone = contact.phones.first.number;
      List<String> variations = _generateSmartVariations(rawPhone);

      for (var v in variations) {
        phoneToContactMap[v] = contact;
        allVariationsToCheck.add(v);
      }
    }

    if (allVariationsToCheck.isEmpty) return [];

    // 2. Batch Query Firestore (chunked by 10 due to 'whereIn' limit)
    Set<String> foundPhoneNumbers = {};
    List<List<String>> chunks = [];
    for (int i = 0; i < allVariationsToCheck.length; i += 10) {
      chunks.add(
        allVariationsToCheck.sublist(
          i,
          (i + 10) < allVariationsToCheck.length
              ? (i + 10)
              : allVariationsToCheck.length,
        ),
      );
    }

    for (var chunk in chunks) {
      QuerySnapshot query = await db
          .collection('users')
          .where('phoneNumber', whereIn: chunk)
          .get();

      for (var doc in query.docs) {
        var userData = doc.data() as Map<String, dynamic>;
        userData['uid'] = doc.id;
        String matchPhone = userData['phoneNumber'];

        // Mark as found
        foundPhoneNumbers.add(matchPhone);

        // Add to results
        results.add({'type': 'app_user', 'data': userData});

        // Remove from potential list so we don't add as guest later
        // Note: This logic is slightly complex because one contact has multiple variations.
        // Simplified: The DB match is definitive.
      }
    }

    // 3. Process matches and guests
    results.clear(); // Ensure clean slate

    // We need a map of Variation -> UserData from DB
    Map<String, Map<String, dynamic>> dbMatches = {};
    for (var chunk in chunks) {
      QuerySnapshot query = await db
          .collection('users')
          .where('phoneNumber', whereIn: chunk)
          .get();

      for (var doc in query.docs) {
        var userData = doc.data() as Map<String, dynamic>;
        userData['uid'] = doc.id;
        String dbPhone = userData['phoneNumber'];
        dbMatches[dbPhone] = userData;
      }
    }

    for (var contact in contacts) {
      if (contact.phones.isEmpty) continue;
      String rawPhone = contact.phones.first.number;
      List<String> variations = _generateSmartVariations(rawPhone);

      Map<String, dynamic>? match;

      for (var v in variations) {
        if (dbMatches.containsKey(v)) {
          match = dbMatches[v];
          break;
        }
      }

      if (match != null) {
        results.add({'type': 'app_user', 'data': match});
      } else {
        results.add({
          'type': 'guest',
          'data': {
            'uid':
                'guest_${DateTime.now().millisecondsSinceEpoch}_${results.length}',
            'displayName': contact.displayName,
            'phoneNumber': rawPhone,
            'photoUrl': null,
          },
        });
      }
    }

    return results;
  }

  Future<Map<String, dynamic>?> pickAndFindUser() async {
    // 1. Request Permission
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return null;
    }

    // 2. Open Picker
    final Contact? contact = await FlutterContacts.openExternalPick();
    if (contact == null || contact.phones.isEmpty) return null;

    String rawPhone = contact.phones.first.number;
    String displayName = contact.displayName;

    // 3. Normalize & Generate Search Variations
    List<String> variations = _generateSmartVariations(rawPhone);

    // 4. Query Firestore
    // We check if the DB contains ANY of our calculated E.164 variations
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', whereIn: variations)
        .get();

    if (query.docs.isNotEmpty) {
      // MATCH FOUND!
      var userData = query.docs.first.data() as Map<String, dynamic>;
      userData['uid'] = query.docs.first.id;
      return {'type': 'app_user', 'data': userData};
    } else {
      // NO MATCH -> Guest
      return {
        'type': 'guest',
        'data': {
          'uid': 'guest_${DateTime.now().millisecondsSinceEpoch}',
          'displayName': displayName,
          'phoneNumber': rawPhone,
          'photoUrl': null,
        },
      };
    }
  }

  /// THE ALGORITHM
  List<String> _generateSmartVariations(String rawPhone) {
    // 1. Strip everything except digits and +
    String cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    Set<String> variations = {};

    // Variation A: Exact match (if they saved it as +2010...)
    variations.add(cleaned);

    // Variation B: If it starts with local prefix '01' (Egypt specific standard)
    // Replace '01' with '+201'
    if (cleaned.startsWith('01')) {
      variations.add('+20${cleaned.substring(1)}');
    }

    // Variation C: Assume they typed it without country code but no leading zero (10xxxx)
    if (!cleaned.startsWith('+') && !cleaned.startsWith('0')) {
      variations.add('+20$cleaned');
    }

    // Variation D: Assume they typed international but forgot the '+' (2010...)
    if (cleaned.startsWith('201')) {
      variations.add('+$cleaned');
    }

    // Variation E: Handle '00' international prefix (002010...)
    if (cleaned.startsWith('00')) {
      variations.add('+${cleaned.substring(2)}');
    }

    return variations.toList();
  }
}
