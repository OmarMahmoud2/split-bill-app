import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart'; // THE NEW PACKAGE
import 'home_screen.dart';
import 'services/user_preferences_service.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  String? _fullPhoneNumber; // Stores +201012345678
  String _isoCode = 'EG'; // Default Country
  bool _isLoading = false;

  Future<void> _savePhone() async {
    if (_fullPhoneNumber == null || _fullPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    final localeCode = Localizations.localeOf(context).languageCode;
    setState(() => _isLoading = true);

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 🔍 CHECK IF PHONE NUMBER ALREADY EXISTS
      final existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: _fullPhoneNumber)
          .get();

      // Filter out current user (in case they're updating)
      final otherUsers = existingUsers.docs
          .where((doc) => doc.id != user.uid)
          .toList();

      if (otherUsers.isNotEmpty) {
        // Phone number already exists for another user
        setState(() => _isLoading = false);

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Phone Number Already Exists",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Text(
                "This phone number ($_fullPhoneNumber) is already associated with another account.\n\n"
                "If this is your number and you have another account, please use that account to sign in.\n\n"
                "Otherwise, please enter a different phone number.",
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Try Different Number"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Clear the current phone input
                    setState(() {
                      _fullPhoneNumber = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Clear & Retry"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ✅ PHONE NUMBER IS UNIQUE - PROCEED TO SAVE
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': _fullPhoneNumber,
        'isoCode': _isoCode,
        'photoUrl': user.photoURL,
        'displayName': user.displayName ?? "User",
        'email': user.email,
        'points': 7, // 🎁 Start with 7 free points
        'isPremium': false, // Default to free tier
        'themeMode': UserPreferencesService.defaultThemeMode,
        'localeCode': localeCode,
        'currencyCode': UserPreferencesService.defaultCurrencyCode,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Setup")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Let's verify your number",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "This allows friends to find you by your contact details.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // --- SMART INPUT FIELD ---
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(borderSide: BorderSide()),
              ),
              initialCountryCode:
                  'EG', // Default to Egypt (or your target market)
              onChanged: (phone) {
                // phone.completeNumber contains the full E.164 string (+20...)
                setState(() {
                  _fullPhoneNumber = phone.completeNumber;
                  _isoCode = phone.countryISOCode;
                });
              },
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
