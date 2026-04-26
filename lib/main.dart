import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:oncoguide_v2/core/pages/all_patients/all_patients.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User, Session, AuthState, AuthChangeEvent;

import 'core/conts/theme.dart';
import 'core/pages/auth/login.dart';
import 'core/pages/history/scan_history_screen.dart';
import 'core/pages/new_analysis/screens/new_analysis_screen.dart';
import 'core/pages/patients/patients_hub_screen.dart';
import 'core/pages/quickaccess/addpatient.dart';
import 'core/utils/nav_bar.dart';
export 'core/utils/nav_bar.dart' show mainScreenKey;
import 'core/widgets/resuable_top_bar.dart' show SettingsScreen;
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OncoGuide',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
      routes: {
        '/login'        : (context) => LoginScreen(),
        '/add_patient'  : (context) => const AddPatientScreen(),
        '/settings'     : (context) => const SettingsScreen(),
        '/new_analysis' : (context) => const NewAnalysisScreen(),
        '/all_patients' : (context) => const AllPatientsScreen(),
        '/scan_history' : (context) => const ScanHistoryScreen(),
        '/patients_hub' : (context) => const PatientsHubScreen(),
      },
    );
  }
}

/// Checks Firebase auth state on startup.
/// - Already logged in → go straight to Dashboard
/// - Not logged in → show splash then Login
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Logged in — go to main screen (has nav bar)
        if (snapshot.hasData && snapshot.data != null) {
          return MainScreen(key: mainScreenKey);
        }
        // Not logged in — show splash then login
        return const LandingPage();
      },
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late AnimationController _textController;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Logo scale animation (slow float)
    _logoController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _logoScaleAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    // Text slide + fade animation
    _textController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textFadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_textController);

    _textController.forward();

    // Navigate to login after 9 seconds
    Future.delayed(const Duration(seconds: 9), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Slow, gentle animated background
          const AnimatedBackground(),

          // Centered content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Image.asset(
                    'assets/images/applogo.png',
                    width: 180,
                    height: 180,
                  ),
                ),
                const SizedBox(height: 30),
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: const Text(
                      'OncoGuide',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE91E63)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30.0),
                      child: Text(
                        'Empowering Doctors to Diagnose, Stage, and Treat Breast Cancer Efficiently',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
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
}

// Gentle animated background
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Slow horizontal float
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat(reverse: true);
    _animation = Tween<double>(begin: -50, end: 50)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: BackgroundPainter(_animation.value),
          child: Container(),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double offset;

  BackgroundPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFFFB3D9).withOpacity(0.3);
    canvas.drawCircle(
        Offset(size.width * 0.3 + offset, size.height * 0.2), 120, paint);

    paint.color = const Color(0xFFE91E63).withOpacity(0.3);
    canvas.drawCircle(
        Offset(size.width * 0.7 - offset, size.height * 0.6), 150, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
