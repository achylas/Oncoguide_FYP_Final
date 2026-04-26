import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/utils/nav_bar.dart';

// ── Issue 2 fix: "All Patients" switches to the nav bar Patients tab (index 1)
// instead of pushing a new route (which would lose the bottom nav bar).
class EnhancedQuickActions extends StatelessWidget {
  const EnhancedQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        title: 'All Patients',
        subtitle: 'View records',
        icon: Icons.people_rounded,
        onTap: () {
          // Switch to Patients tab (index 1) in the nav bar
          mainScreenKey.currentState?.switchTab(1);
        },
        colors: [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)],
      ),
      _ActionData(
        title: 'Reports',
        subtitle: 'Scan history',
        icon: Icons.assessment_rounded,
        onTap: () => Navigator.pushNamed(context, '/scan_history'),
        colors: [const Color(0xFFFF6F91), const Color(0xFFFF9AB0)],
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions.map((a) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: a == actions.last ? 0 : 12),
              child: _ActionTile(action: a),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> colors;

  const _ActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.colors,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionData action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: action.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: action.colors.first.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
