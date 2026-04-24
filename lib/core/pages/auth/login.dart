import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/auth/signup_screen.dart';
import '../../conts/colors.dart';
import '../../widgets/app_text_feild.dart';
import '../../widgets/primary_button.dart';
import '../../utils/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required")));
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred";
      if (e.code == 'user-not-found') {
        message = "No user found for this email";
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "Incorrect email or password";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                colors: [
                  AppColors.backgroundDark,
                  AppColors.surfaceDark,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
                  : const LinearGradient(
                colors: [Color(0xFFFFF0F3), Color(0xFFFFC1CC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.accent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Login card
          Center(
            child: Container(
              width: size.width * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.getCardBackground(context),
                borderRadius: BorderRadius.circular(24),
                border: isDark
                    ? Border.all(color: AppColors.borderDark)
                    : null,
                boxShadow: isDark
                    ? null
                    : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Animations.fadeIn(
                    delay: 300,
                    child: Text(
                      "Welcome",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Animations.fadeIn(
                    delay: 450,
                    child: Text(
                      "Sign in to continue",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  Animations.slideUp(
                    delay: 600,
                    child: AppTextField(
                      hintText: "Email",
                      controller: emailController,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  Animations.slideUp(
                    delay: 700,
                    child: AppTextField(
                      hintText: "Password",
                      controller: passwordController,
                      isPassword: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  Animations.slideUp(
                    delay: 800,
                    child: PrimaryButton(
                      text: isLoading ? "Signing In..." : "Login",
                      onPressed: isLoading ? null : handleLogin,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Forgot password
                  Animations.fadeIn(
                    delay: 900,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Signup Option
                  Animations.fadeIn(
                    delay: 1000,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}