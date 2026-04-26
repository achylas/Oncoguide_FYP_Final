import 'package:flutter/material.dart';
import '../conts/colors.dart';
import '../pages/dashboard/dashboard_content.dart';
import '../pages/patients/patients_hub_screen.dart';
import '../pages/profile.dart';

/// Global key so any widget can switch the nav bar tab from outside MainScreen.
final mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardContent(),
    PatientsHubScreen(),
    DoctorProfileScreen(),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Switch to a specific tab from outside this widget.
  void switchTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ────────────────────────────────────────────────

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ─── Background pill ───────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1D1F33)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: isDark
                        ? Border.all(
                      color: const Color(0xFF2A2D47),
                      width: 1.5,
                    )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.11),
                        blurRadius: isDark ? 20 : 16,
                        offset: Offset(0, isDark ? 8 : 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        isSelected: selectedIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      const SizedBox(width: 80),
                      _NavItem(
                        icon: Icons.person_outline,
                        isSelected: selectedIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Floating Patients Button ──────────────────────────
              Positioned(
                bottom: 28,
                child: GestureDetector(
                  onTap: () => onTap(1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: selectedIndex == 1 ? 78 : 72,
                    width: selectedIndex == 1 ? 78 : 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                          const Color(0xFFBA6BFA),
                          const Color(0xFFFF6B6B),
                        ]
                            : [
                          const Color(0xFFBA6BFA),
                          const Color(0xFFFF6B6B),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(
                              isDark ? 0.5 : 0.4
                          ),
                          blurRadius: selectedIndex == 1 ? 18 : 12,
                          spreadRadius: selectedIndex == 1 ? 4 : 0,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.people_rounded,
                      color: Colors.white,
                      size: selectedIndex == 1 ? 38 : 34,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.12)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? AppColors.primary
              : (isDark
              ? const Color(0xFF6C7080)
              : Colors.grey.shade500),
          size: isSelected ? 30 : 26,
        ),
      ),
    );
  }
}