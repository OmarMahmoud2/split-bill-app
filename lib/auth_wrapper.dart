import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/home_screen.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/phone_input_screen.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/services/permission_flow.dart';
import 'package:split_bill_app/services/guest_session.dart';
import 'package:split_bill_app/services/public_profile_service.dart';

/// Setup is done once the user saved a phone number or chose "Not now".
bool isAccountSetupComplete(Map<String, dynamic>? data) {
  if (data == null) return false;
  final phone = data['phoneNumber']?.toString() ?? '';
  return phone.isNotEmpty || data['phonePromptSkippedAt'] != null;
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<bool> _onboardingStatus;
  final Stream<User?> _authChanges = FirebaseAuth.instance.authStateChanges();

  // Cached per uid so rebuilds don't refetch the user doc or flash a loader.
  String? _userDocUid;
  Future<DocumentSnapshot>? _userDocFuture;

  Future<DocumentSnapshot> _userDocFor(String uid) {
    if (_userDocUid != uid || _userDocFuture == null) {
      _userDocUid = uid;
      _userDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .then((doc) {
            if (isAccountSetupComplete(doc.data())) {
              // The rewarded ad warms up when PermissionGate finishes (after
              // the ATT answer).
              PublicProfileService.syncFromUserDoc();
            }
            return doc;
          });
    }
    return _userDocFuture!;
  }

  @override
  void initState() {
    super.initState();
    _onboardingStatus = _checkOnboardingStatus();
  }

  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Return true if onboarding is complete
    return (prefs.getBool('onboarding_complete_v2') ?? false) ||
        (prefs.getBool('onboarding_complete') ?? false);
  }

  @override
  Widget build(BuildContext context) => _buildMainContent();

  Widget _buildMainContent() {
    // Check onboarding status first
    return FutureBuilder<bool>(
      future: _onboardingStatus,
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: LoadingStateWidget(message: 'checking_onboarding'.tr()),
          );
        }

        // If onboarding not complete, show new onboarding
        if (!(onboardingSnapshot.data ?? false)) {
          return const NewOnboardingScreen();
        }

        // Otherwise proceed with normal auth flow
        return StreamBuilder<User?>(
          stream: _authChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: LoadingStateWidget(
                  message: 'setting_up_secure_connection'.tr(),
                ),
              );
            }

            if (memberOrNull(snapshot.data) != null) {
              return FutureBuilder<DocumentSnapshot>(
                future: _userDocFor(snapshot.data!.uid),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      body: LoadingStateWidget(message: 'signing_you_in'.tr()),
                    );
                  }

                  final data =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  // Phone is optional: ask once, until saved or skipped.
                  if (!isAccountSetupComplete(data)) {
                    return const PhoneInputScreen();
                  }

                  return const PermissionGate(child: HomeScreen());
                },
              );
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}
