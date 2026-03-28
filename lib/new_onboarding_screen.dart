import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_wrapper.dart';

class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key});

  @override
  State<NewOnboardingScreen> createState() => _NewOnboardingScreenState();
}

class _NewOnboardingScreenState extends State<NewOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _particleController;
  late AnimationController _gradientController;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      image:
          'assets/onboarding/onboarding_scan_receipt_1767296144198-removebg-preview.png',
      title: 'Scan Receipts\nInstantly',
      description:
          'Just snap a photo and let AI extract all items and prices automatically.',
      gradientColors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    OnboardingPageData(
      image:
          'assets/onboarding/onboarding_split_bill_1767296158711-removebg-preview.png',
      title: 'Split Bills\nFairly',
      description:
          'Assign items to friends or split evenly. Everyone pays what they owe.',
      gradientColors: [Color(0xFFEC008C), Color(0xFFFC6767)],
    ),
    OnboardingPageData(
      image:
          'assets/onboarding/onboarding_track_payments_1767296176070-removebg-preview.png',
      title: 'Track Payments\nEasily',
      description: 'See who paid and who hasn\'t. Send reminders with one tap.',
      gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    OnboardingPageData(
      image:
          'assets/onboarding/onboarding_notifications_1767296191753-removebg-preview.png',
      title: 'Stay Updated\nAlways',
      description:
          'Get instant notifications when bills are shared or payments confirmed.',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFA500)],
    ),
    OnboardingPageData(
      image:
          'assets/onboarding/onboarding_ready_1767296205493-removebg-preview.png',
      title: 'Ready to\nGet Started?',
      description:
          'Join thousands splitting bills effortlessly. No more awkward math!',
      gradientColors: [Color(0xFF667EEA), Color(0xFF4FACFE)],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGradient = _pages[_currentPage].gradientColors;

    return Scaffold(
      body: Stack(
        children: [
          // 🌈 ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        currentGradient[0],
                        currentGradient[1],
                        (_gradientController.value * 2) % 1,
                      )!,
                      Color.lerp(
                        currentGradient[1],
                        currentGradient[0].withValues(alpha: 0.7),
                        (_gradientController.value * 2) % 1,
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
                    opacity: 0.2,
                    child: Container(
                      width: 4 + (index % 3) * 2,
                      height: 4 + (index % 3) * 2,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 📱 MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                // SKIP BUTTON
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // PAGE VIEW
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], index);
                    },
                  ),
                ),

                // PAGE INDICATOR
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // NEXT/GET STARTED BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: currentGradient[0],
                        elevation: 8,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started 🚀'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(50 * (1 - value), 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // IMAGE
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Image.asset(
                          page.image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported_outlined,
                              size: 150,
                              color: Colors.white.withValues(alpha: 0.5),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // TITLE
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFFFF3E0)],
                    ).createShader(bounds),
                    child: Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DESCRIPTION
                  Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingPageData {
  final String image;
  final String title;
  final String description;
  final List<Color> gradientColors;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
