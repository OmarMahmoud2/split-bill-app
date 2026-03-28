import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/home_screen.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:split_bill_app/phone_input_screen.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/animated_splash_screen.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Show splash for a brief moment, then proceed
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _initAppTracking();
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
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
    return prefs.getBool('onboarding_complete') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Show animated splash first
    if (_showSplash) {
      return AnimatedSplashScreen(nextScreen: _buildMainContent());
    }

    return _buildMainContent();
  }

  Widget _buildMainContent() {
    // Check onboarding status first
    return FutureBuilder<bool>(
      future: _checkOnboardingStatus(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingStateWidget(message: "Checking onboarding..."),
          );
        }

        // If onboarding not complete, show new onboarding
        if (!(onboardingSnapshot.data ?? false)) {
          return const NewOnboardingScreen();
        }

        // Otherwise proceed with normal auth flow
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: LoadingStateWidget(
                  message: "Setting up secure connection...",
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: LoadingStateWidget(message: "Signing you in..."),
                    );
                  }

                  final data =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  // CRITICAL CHECK: If phone number is missing, force setup
                  if (data == null ||
                      data['phoneNumber'] == null ||
                      data['phoneNumber'] == "") {
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
