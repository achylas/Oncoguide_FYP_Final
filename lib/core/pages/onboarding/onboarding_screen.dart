import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../conts/colors.dart';
import '../auth/login.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'AI-Powered Breast Cancer Detection',
      description: 'Advanced machine learning algorithms analyze mammograms and ultrasounds with high accuracy',
      icon: Icons.psychology_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFFFB3CC), Color(0xFFFF6B9D)], // App's pink gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      illustration: '🔬',
    ),
    OnboardingPage(
      title: 'Comprehensive Risk Assessment',
      description: 'Personalized risk analysis based on clinical data, family history, and lifestyle factors',
      icon: Icons.analytics_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFB3D9FF), Color(0xFF74B9FF)], // App's blue gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      illustration: '📊',
    ),
    OnboardingPage(
      title: 'Smart Recommendations',
      description: 'Evidence-based clinical recommendations tailored to each patient\'s unique profile',
      icon: Icons.fact_check_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFFFB3CC), Color(0xFF74B9FF)], // App's healing gradient (pink to blue)
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      illustration: '✅',
    ),
    OnboardingPage(
      title: 'Secure & HIPAA Compliant',
      description: 'Your patient data is encrypted and protected with enterprise-grade security',
      icon: Icons.security_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFFF6B9D), Color(0xFFE91E63)], // App's primary dark gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      illustration: '🔒',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FadeInLeft(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB3CC), Color(0xFFFF6B9D)], // App's pink gradient
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'OncoGuide',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_currentPage < _pages.length - 1)
                    FadeInRight(
                      duration: const Duration(milliseconds: 600),
                      child: TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(
                    page: _pages[index],
                    isDark: isDark,
                  );
                },
              ),
            ),

            // Page indicators
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
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
                        gradient: _currentPage == index
                            ? _pages[index].gradient
                            : null,
                        color: _currentPage == index
                            ? null
                            : AppColors.getTextSecondary(context).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Next/Get Started button
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _pages[_currentPage].gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_currentPage].gradient.colors.first.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final String illustration;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.illustration,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final OnboardingPage page;
  final bool isDark;

  const _OnboardingPageWidget({
    required this.page,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated illustration
          FadeInDown(
            duration: const Duration(milliseconds: 800),
            child: ZoomIn(
              duration: const Duration(milliseconds: 800),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: page.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient.colors.first.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing background circles
                    Pulse(
                      infinite: true,
                      duration: const Duration(seconds: 2),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Pulse(
                      infinite: true,
                      duration: const Duration(seconds: 2),
                      delay: const Duration(milliseconds: 500),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Icon
                    Icon(
                      page.icon,
                      size: 80,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 60),

          // Title
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            delay: const Duration(milliseconds: 200),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Description
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            delay: const Duration(milliseconds: 400),
            child: Text(
              page.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.getTextSecondary(context),
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Feature badges
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            delay: const Duration(milliseconds: 600),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _getFeatureBadges(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getFeatureBadges() {
    final features = <String>[];
    
    if (page.title.contains('AI-Powered')) {
      features.addAll(['Machine Learning', 'High Accuracy', 'Fast Results']);
    } else if (page.title.contains('Risk Assessment')) {
      features.addAll(['Personalized', 'Clinical Data', 'SHAP Analysis']);
    } else if (page.title.contains('Recommendations')) {
      features.addAll(['Evidence-Based', 'WHO Guidelines', 'Actionable']);
    } else if (page.title.contains('Secure')) {
      features.addAll(['Encrypted', 'HIPAA Compliant', 'Private']);
    }

    return features.map((feature) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // White background for contrast
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: page.gradient.colors.first.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: page.gradient.colors.first.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          feature,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: page.gradient.colors.last, // Use darker gradient color for text
          ),
        ),
      );
    }).toList();
  }
}

// Extension to scale gradient opacity
extension GradientScale on Gradient {
  Gradient scale(double opacity) {
    if (this is LinearGradient) {
      final linear = this as LinearGradient;
      return LinearGradient(
        colors: linear.colors.map((c) => c.withOpacity(opacity)).toList(),
        begin: linear.begin,
        end: linear.end,
      );
    }
    return this;
  }
}
