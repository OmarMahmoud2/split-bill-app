import 'dart:async';

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const AnimatedSplashScreen({super.key, required this.nextScreen});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();

    // Logo floating animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Text typewriter animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Gradient animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Auto-navigate after 4.5 seconds
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.nextScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌌 ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _gradientController,
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
                        (_gradientController.value * 2) % 1,
                      )!,
                      Color.lerp(
                        const Color(0xFF764BA2),
                        const Color(0xFFF093FB),
                        (_gradientController.value * 2) % 1,
                      )!,
                      Color.lerp(
                        const Color(0xFFF093FB),
                        const Color(0xFF4FACFE),
                        (_gradientController.value * 2) % 1,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // ✨ FLOATING PARTICLES
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                final offset = (_particleController.value + index * 0.05) % 1;
                return Positioned(
                  left: (index * 40.0) % MediaQuery.of(context).size.width,
                  top: MediaQuery.of(context).size.height * offset,
                  child: Opacity(
                    opacity: 0.3,
                    child: Container(
                      width: 3 + (index % 4) * 2,
                      height: 3 + (index % 4) * 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 🎯 MAIN CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🎨 FLOATING LOGO
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        math.sin(_logoController.value * math.pi) * 15,
                      ),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            math.sin(_logoController.value * math.pi) * 0.05,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 30,
                                  offset: Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 100,
                              height: 100,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.receipt_long_rounded,
                                size: 100,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // ✍️ ANIMATED SUBTITLE
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    const fullText = "Split expenses.\nShare smiles.";
                    final displayText = fullText.substring(
                      0,
                      (fullText.length * _textController.value).toInt(),
                    );

                    return ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFF3E0)],
                      ).createShader(bounds),
                      child: Text(
                        displayText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),

                // 📊 LOADING INDICATOR
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
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
}
