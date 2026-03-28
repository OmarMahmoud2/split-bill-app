import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:lottie/lottie.dart';
import 'widgets/loading_state_widget.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/widgets/sign_up_modal.dart';
import 'auth_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  // Note: _isRegistering is now mainly used for internal state if needed,
  // but the UI uses a Modal for registration, so the main form is always Login.
  // We keep it if we want to toggle the main form, but the plan is to use the modal.
  // Actually, the plan says "Implementing the sign-up process via a modal bottom sheet instead of an in-line form."
  // So the main screen is ALWAYS Login.

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _floatingController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    // Floating animation for logo
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Slide up animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _floatingController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // --- GOOGLE LOGIN ---
  Future<void> _signInWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      HapticFeedback.mediumImpact();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Sign-In Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- APPLE LOGIN ---
  Future<void> _signInWithApple() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final authCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(authCredential);
      HapticFeedback.mediumImpact();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Apple Sign-In Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EMAIL AUTH METHODS ---

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackbar("Please enter email and password.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackbar("Please enter your email first.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(_emailController.text.trim());
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent! Check your inbox."),
          backgroundColor: Color(0xFF667EEA),
        ),
      );
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingStateWidget(message: "Signing in..."));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // Prevent background squish
      body: Stack(
        children: [
          // 🌌 ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFF667EEA),
                        const Color(0xFF764BA2),
                        (_particleController.value * 2) % 1,
                      )!,
                      Color.lerp(
                        const Color(0xFF764BA2),
                        const Color(0xFFF093FB),
                        (_particleController.value * 2) % 1,
                      )!,
                      Color.lerp(
                        const Color(0xFFF093FB),
                        const Color(0xFF4FACFE),
                        (_particleController.value * 2) % 1,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // ✨ FLOATING PARTICLES
          ...List.generate(15, (index) {
            return AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                final offset = (_particleController.value + index * 0.1) % 1;
                return Positioned(
                  left: (index * 50.0) % MediaQuery.of(context).size.width,
                  top: MediaQuery.of(context).size.height * offset,
                  child: Opacity(
                    opacity: 0.3,
                    child: Container(
                      width: 4 + (index % 3) * 2,
                      height: 4 + (index % 3) * 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 📱 MAIN CONTENT (Compact UI)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48), // Adjusted top spacing
                  // 🎨 ANIMATED LOGO WITH FLOATING EFFECT
                  AnimatedBuilder(
                    animation: _floatingController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          math.sin(_floatingController.value * 2 * math.pi) * 6,
                        ),
                        child: FadeTransition(
                          opacity: _fadeController,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                height: 60,
                                width: 60,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 60,
                                  color: Color(0xFF667EEA),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 💬 ANIMATED TITLE WITH LOTTIE
                  FadeTransition(
                    opacity: _fadeController,
                    child: Lottie.asset(
                      'assets/animations/welcome.json',
                      height: 100, // Reduced Size
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(height: 60),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🎯 GLASSMORPHIC LOGIN CARD
                  SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _slideController,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // EMAIL FIELD (High Contrast)
                            _buildGlassTextField(
                              controller: _emailController,
                              hintText: "Email Address",
                              icon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 12),

                            // PASSWORD FIELD (High Contrast)
                            _buildGlassTextField(
                              controller: _passwordController,
                              hintText: "Password",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                            ),

                            // Forgot Password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: Colors.white70,
                                ),
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // SIGN IN BUTTON
                            _buildGlassButton(
                              label: "Sign In",
                              icon: Icons.login_rounded,
                              onPressed: _signIn,
                              gradientColors: const [
                                Color(0xFF667EEA),
                                Color(0xFF764BA2),
                              ],
                              textColor: Colors.white,
                              fullWidth: true,
                            ),

                            const SizedBox(height: 20),

                            // OR DIVIDER
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    "OR",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // SOCIAL BUTTONS ROW (Compact)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSocialButton(
                                    label: "Google",
                                    icon: Icons.g_mobiledata,
                                    onPressed: _signInWithGoogle,
                                    bgColor: Colors.white,
                                    textColor: Colors.black87,
                                  ),
                                ),
                                if (Platform.isIOS) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSocialButton(
                                      label: "Apple",
                                      icon: Icons.apple,
                                      onPressed: _signInWithApple,
                                      bgColor: Colors.black,
                                      textColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 📞 CONTACT US (Inside Card)
                            TextButton.icon(
                              onPressed: () =>
                                  ProfileDialogs.showContactUs(context),
                              icon: Icon(
                                Icons.help_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                              label: Text(
                                "Need Help? Contact Us",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CREATE ACCOUNT LABEL (Triggers Modal)
                  TextButton(
                    onPressed: _showSignUpModal,
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SIGN UP MODAL ---
  void _showSignUpModal() {
    SignUpModal.show(
      context,
      onSignUp: (name, email, password) async {
        // We handle the loading state INSIDE the modal first (it awaits this future).
        // Actual Auth Logic:
        try {
          await _authService.signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
          HapticFeedback.mediumImpact();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account created! Please verify your email."),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        } catch (e) {
          _showErrorSnackbar(e.toString());
          rethrow; // To let the modal stop loading (though modal handles validation errors mostly)
        }
      },
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper for Glass Input Fields (High Contrast)
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Opaque white background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        // Dark text for high contrast on white background
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          // Grey hint text
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
    required Color textColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: textColor),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
