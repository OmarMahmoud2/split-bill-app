import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/home_screen.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:split_bill_app/phone_input_screen.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/services/guest_session.dart';
import 'package:split_bill_app/services/public_profile_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<bool> _onboardingStatus;
  bool _startupFinished = false;
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
            if (_hasPhoneNumber(doc.data())) {
              // Preload rewarded ad for free users as soon as we know they're logged in
              RewardedAdHelper.warmUpIfEligible();
              PublicProfileService.syncFromUserDoc();
            }
            return doc;
          });
    }
    return _userDocFuture!;
  }

  static bool _hasPhoneNumber(Map<String, dynamic>? data) =>
      data != null && data['phoneNumber'] != null && data['phoneNumber'] != "";

  @override
  void initState() {
    super.initState();
    _onboardingStatus = _checkOnboardingStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishStartup());
  }

  Future<void> _finishStartup() async {
    try {
      await _initAppTracking();
    } catch (error) {
      debugPrint('Tracking authorization unavailable: $error');
    } finally {
      if (mounted) setState(() => _startupFinished = true);
    }
  }

  Future<void> _initAppTracking() async {
    // If the system can show an authorization request dialog
    if (await AppTrackingTransparency.trackingAuthorizationStatus ==
        TrackingStatus.notDetermined) {
      // Wait for dialog...
      await Future.delayed(const Duration(milliseconds: 200));
      // Request system's tracking authorization dialog
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // Return true if onboarding is complete
    return (prefs.getBool('onboarding_complete_v2') ?? false) ||
        (prefs.getBool('onboarding_complete') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_startupFinished) {
      return const Scaffold(
        body: Center(
          child: Image(
            image: AssetImage('assets/logo.png'),
            width: 96,
            height: 96,
          ),
        ),
      );
    }

    return _buildMainContent();
  }

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

                  // CRITICAL CHECK: If phone number is missing, force setup
                  if (!_hasPhoneNumber(data)) {
                    return const PhoneInputScreen();
                  }

                  return const HomeScreen();
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
