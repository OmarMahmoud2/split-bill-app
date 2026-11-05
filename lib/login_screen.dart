import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'widgets/loading_state_widget.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/widgets/sign_up_modal.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_wrapper.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Hint/icon grey inside the white auth fields (light mode).
  static const _authMuted = Color(0xFF6B7280);

  // Login sits on an always-colored brand gradient in both themes, so the
  // glass chrome on top of it (white overlays/text) stays white on purpose.
  static const _deepBrand = Color(0xFF006064); // cyan 900

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _floatingController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

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

  Future<void> _signInWithGoogle() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null || !mounted) return;
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
            content: Text(e.toString()),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithApple();
      if (result == null || !mounted) return;
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
            content: Text(e.toString()),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackbar('please_enter_email_and_password'.tr());
      return;
    }

    FocusScope.of(context).unfocus();
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
      _showErrorSnackbar('please_enter_your_email_first'.tr());
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(_emailController.text.trim());
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('password_reset_email_sent_check_your_inbox').tr(),
          backgroundColor: context.palette.primary,
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
      return Scaffold(body: LoadingStateWidget(message: 'signing_in'.tr()));
    }

    final p = context.palette;
    final g0 = p.primaryGradient.colors.first;
    final g1 = p.primaryGradient.colors.last;
    final g2 = Color.lerp(g1, _deepBrand, 0.6)!;
    final authTheme = Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // light icons over the brand gradient
      child: Theme(
        data: authTheme,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
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
                            g0,
                            g1,
                            (_particleController.value * 2) % 1,
                          )!,
                          Color.lerp(
                            g1,
                            g2,
                            (_particleController.value * 2) % 1,
                          )!,
                          Color.lerp(
                            g2,
                            g0,
                            (_particleController.value * 2) % 1,
                          )!,
                        ],
                      ),
                    ),
                  );
                },
              ),
              ...List.generate(15, (index) {
                return AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    final offset =
                        (_particleController.value + index * 0.1) % 1;
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
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              math.sin(
                                    _floatingController.value * 2 * math.pi,
                                  ) *
                                  6,
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
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
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
                                    // White backdrop for the logo artwork.
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.shadow.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 60,
                                    width: 60,
                                    errorBuilder: (c, e, s) => Icon(
                                      Icons.receipt_long_rounded,
                                      size: 60,
                                      color: p.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeController,
                        child: Lottie.asset(
                          'assets/animations/welcome.json',
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(height: 60),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                                  color: p.shadow.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildGlassTextField(
                                  controller: _emailController,
                                  hintText: 'email_address'.tr(),
                                  icon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 12),
                                _buildGlassTextField(
                                  controller: _passwordController,
                                  hintText: 'password'.tr(),
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                ),
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
                                    child: Text(
                                      'forgot_password',
                                      style: TextStyle(fontSize: 12),
                                    ).tr(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildGlassButton(
                                  label: 'sign_in'.tr(),
                                  icon: Icons.login_rounded,
                                  onPressed: _signIn,
                                  gradientColors: const [
                                    AppColors.primaryDark,
                                    _deepBrand,
                                  ],
                                  textColor: p.onPrimary,
                                  fullWidth: true,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ).tr(),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    OutlinedButton.icon(
                                      key: const ValueKey('sign-in-google'),
                                      onPressed: _signInWithGoogle,
                                      icon: Image.asset(
                                        'assets/images/google_logo.png',
                                        width: 20,
                                        height: 20,
                                      ),
                                      label: Text('sign_in_with_google'.tr()),
                                      style: OutlinedButton.styleFrom(
                                        // Google sign-in branding: light and
                                        // dark button variants.
                                        backgroundColor: p.isDark
                                            ? const Color(0xFF131314)
                                            : Colors.white,
                                        foregroundColor: p.isDark
                                            ? const Color(0xFFE3E3E3)
                                            : const Color(0xFF1F1F1F),
                                        side: BorderSide(
                                          color: p.isDark
                                              ? const Color(0xFF8E918F)
                                              : const Color(0xFF747775),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (Platform.isIOS) ...[
                                      const SizedBox(height: 12),
                                      SignInWithAppleButton(
                                        key: const ValueKey('sign-in-apple'),
                                        text: 'sign_in_with_apple'.tr(),
                                        onPressed: _signInWithApple,
                                        height: 52,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TextButton.icon(
                                  onPressed: () =>
                                      ProfileDialogs.showContactUs(context),
                                  icon: Icon(
                                    Icons.help_outline_rounded,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  label: Text(
                                    'need_help_contact_us',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ).tr(),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _showSignUpModal,
                        child: RichText(
                          text: TextSpan(
                            text: '${'don_t_have_an_account'.tr()} ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'sign_up'.tr(),
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
        ),
      ),
    );
  }

  void _showSignUpModal() {
    SignUpModal.show(
      context,
      onSignUp: (name, email, password) async {
        try {
          await _authService.signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
          HapticFeedback.mediumImpact();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('account_created_please_verify_your_email').tr(),
              backgroundColor: context.palette.success,
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        } catch (e) {
          _showErrorSnackbar(e.toString());
          rethrow;
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
        backgroundColor: context.palette.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    final p = context.palette;
    final muted = p.isDark ? p.textSecondary : _authMuted;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        autofillHints: [
          isPassword ? AutofillHints.password : AutofillHints.username,
        ],
        textInputAction: isPassword
            ? TextInputAction.done
            : TextInputAction.next,
        autocorrect: false,
        enableSuggestions: !isPassword,
        onSubmitted: isPassword ? (_) => _signIn() : null,
        style: TextStyle(color: p.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          filled: false,
          fillColor: Colors.transparent,
          hintStyle: TextStyle(color: muted),
          prefixIcon: Icon(icon, color: muted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
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
}
