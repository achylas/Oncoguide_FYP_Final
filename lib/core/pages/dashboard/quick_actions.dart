import 'package:flutter/material.dart';

class EnhancedQuickActions extends StatelessWidget {
  const EnhancedQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        title: "Add Patient",
        icon: Icons.person_add_rounded,
        route: '/add_patient',
        startColor: const Color(0xFFFF6F91),
        endColor: const Color(0xFFFF8FA3),
      ),
      _ActionData(
        title: "All Patients",
        icon: Icons.person,
        route: '/patients_hub',
        startColor: const Color(0xFF6C63FF),
        endColor: const Color(0xFF8B84FF),
      ),
      _ActionData(
        title: "New Scan",
        icon: Icons.document_scanner_rounded,
        route: '/new_analysis',
        startColor: const Color(0xFF6C63FF),
        endColor: const Color(0xFF8B84FF),
      ),
      _ActionData(
        title: "Reports",
        icon: Icons.assessment_rounded,
        route: '/scan_history',
        startColor: const Color(0xFFFFA726),
        endColor: const Color(0xFFFFB74D),
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: actions.length,
        itemBuilder: (context, i) {
          final action = actions[i];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CompactActionChip(
              title: action.title,
              icon: action.icon,
              startColor: action.startColor,
              endColor: action.endColor,
              onTap: action.route != null
                  ? () => Navigator.pushNamed(context, action.route!)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _ActionData {
  final String title;
  final IconData icon;
  final String? route;
  final Color startColor;
  final Color endColor;

  _ActionData({
    required this.title,
    required this.icon,
    this.route,
    required this.startColor,
    required this.endColor,
  });
}

class _CompactActionChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final VoidCallback? onTap;

  const _CompactActionChip({
    required this.title,
    required this.icon,
    required this.startColor,
    required this.endColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                startColor.withOpacity(0.8),
                endColor.withOpacity(0.8),
              ]
                  : [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: startColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}