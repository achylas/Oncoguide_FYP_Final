import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/all_patients/all_patients.dart';
import 'package:oncoguide_v2/core/pages/history/scan_history_screen.dart';
import 'package:oncoguide_v2/core/pages/patients/patients_hub_screen.dart';

import '../pages/auth/login.dart';
import '../pages/dashboard/dashboard_screen.dart';
import '../pages/new_analysis/screens/new_analysis_screen.dart';
import '../pages/profile.dart';
import '../pages/quickaccess/addpatient.dart';

class AppRoutes {
  static const String dashboard    = '/';
  static const String addPatient   = '/add_patient';
  static const String profile      = '/profile';
  static const String new_analysis = '/new_analysis';
  static const String login        = '/login';
  static const String all_patients = '/all_patients';
  static const String scanHistory  = '/scan_history';
  static const String patientsHub  = '/patients_hub';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case all_patients:
        return MaterialPageRoute(builder: (_) => const AllPatientsScreen());
      case patientsHub:
        return MaterialPageRoute(builder: (_) => const PatientsHubScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case addPatient:
        return MaterialPageRoute(builder: (_) => const AddPatientScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const DoctorProfileScreen());
      case login:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case new_analysis:
        return MaterialPageRoute(builder: (_) => const NewAnalysisScreen());
      case scanHistory:
        return MaterialPageRoute(builder: (_) => const ScanHistoryScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
