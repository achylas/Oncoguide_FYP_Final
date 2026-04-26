import 'package:flutter/material.dart';
import 'dashboard_content.dart';

/// Thin wrapper kept so the '/dashboard' named route still works.
/// The actual nav bar lives in MainScreen (nav_bar.dart).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const DashboardContent();
}
