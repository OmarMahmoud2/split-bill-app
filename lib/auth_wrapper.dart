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
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// Setup is done once the user saved a phone number or chose "Not now".
bool isAccountSetupComplete(Map<String, dynamic>? data) {
  if (data == null) return false;
  final phone = data['phoneNumber']?.toString() ?? '';
  return phone.isNotEmpty || data['phonePromptSkippedAt'] != null;
}

/// What the signed-in user sees, from their user document.
enum AccountGate { loadError, suspended, needsSetup, ready }

AccountGate accountGateFor({Object? error, Map<String, dynamic>? data}) {
  // A failed read is not a new user: ask to retry instead of the phone prompt.
  if (error != null) return AccountGate.loadError;
  if (data?['suspended'] == true) return AccountGate.suspended;
  if (!isAccountSetupComplete(data)) return AccountGate.needsSetup;
  return AccountGate.ready;
}

/// "We couldn't load your account", with retry and a way to sign out.
class AccountLoadErrorScreen extends StatelessWidget {
  const AccountLoadErrorScreen({
    super.key,
    required this.onRetry,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: SafeArea(
      child: ErrorState(
        onRetry: onRetry,
        secondaryLabel: 'prof_sign_out'.tr(),
        onSecondary: onSignOut,
      ),
    ),
  );
}

/// Shown instead of the app when `users/{uid}.suspended` is true.
class SuspendedAccountScreen extends StatelessWidget {
  const SuspendedAccountScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: SafeArea(
      child: ErrorState(
        icon: Icons.block_rounded,
        title: 'account_suspended_title'.tr(),
        message: 'account_suspended_message'.tr(
          namedArgs: {'email': AppLinks.supportEmail},
        ),
        retryLabel: 'prof_sign_out'.tr(),
        onRetry: onSignOut,
      ),
    ),
  );
}

/// Lets flows that change what [AuthWrapper] shows (onboarding done, phone
/// saved, signed in or out) hand control back to it without replacing the
/// root route, so BrandIntro and CustomUpgrader stay above it.
class AuthFlow {
  AuthFlow._();

  /// Bumped to make [AuthWrapper] re-read onboarding status and the user doc.
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  /// Re-evaluates the gate and pops back to the root (AuthWrapper).
  static void backToRoot(BuildContext context, {bool reload = true}) {
    if (reload) refresh.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<bool> _onboardingStatus;
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
    AuthFlow.refresh.addListener(_onRefresh);
  }

  @override
  void dispose() {
    AuthFlow.refresh.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (!mounted) return;
    setState(() {
      _onboardingStatus = _checkOnboardingStatus();
      _userDocUid = null;
      _userDocFuture = null;
    });
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

                  switch (accountGateFor(
                    error: userSnapshot.error,
                    data: data,
                  )) {
                    case AccountGate.loadError:
                      return AccountLoadErrorScreen(
                        onRetry: () => setState(() {
                          _userDocUid = null;
                          _userDocFuture = null;
                        }),
                        onSignOut: () => AuthService().signOut(),
                      );
                    case AccountGate.suspended:
                      return SuspendedAccountScreen(
                        onSignOut: () => AuthService().signOut(),
                      );
                    // Phone is optional: ask once, until saved or skipped.
                    case AccountGate.needsSetup:
                      return const PhoneInputScreen();
                    case AccountGate.ready:
                      return const PermissionGate(child: HomeScreen());
                  }
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
