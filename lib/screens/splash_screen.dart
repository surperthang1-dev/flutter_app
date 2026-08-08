import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/coffee_logo.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  Timer? _animationTimer;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    // Start animations shortly after mounting
    _animationTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _animate = true);
      }
    });

    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.coffeeDark, AppColors.coffee, AppColors.caramel],
            stops: [0.1, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _animate ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _animate ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  child: const CoffeeLogo(size: 114),
                ),
              ),
              const SizedBox(height: 34),
              AnimatedOpacity(
                opacity: _animate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: Column(
                  children: [
                    Text(
                      'Cà Phê Việt 24H',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Đậm vị Việt, giao tận nơi',
                      style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
