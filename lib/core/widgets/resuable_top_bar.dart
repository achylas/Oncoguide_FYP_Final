import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../conts/colors.dart';
import '../conts/theme.dart';
import '../pages/settings_subpages.dart';

class ReusableTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showSettingsButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSettingsPressed;
  final List<Widget>? additionalActions;
  final bool useGradient;
  final Color? backgroundColor;
  final Widget? subtitle;

  const ReusableTopBar({
    Key? key,
    required this.title,
    this.showBackButton = true,
    this.showSettingsButton = true,
    this.onBackPressed,
    this.onSettingsPressed,
    this.additionalActions,
    this.useGradient = true,
    this.backgroundColor,
    this.subtitle,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 72 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: hasSubtitle ? 72 : kToolbarHeight,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: useGradient
              ? const LinearGradient(
                  colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: useGradient ? null : (backgroundColor ?? AppColors.primary),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6F91).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              padding: const EdgeInsets.all(8),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
            )
          : null,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 2),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: subtitle!,
            ),
          ],
        ],
      ),
      centerTitle: true,
      actions: [
        if (additionalActions != null) ...additionalActions!,
        if (showSettingsButton)
          IconButton(
            padding: const EdgeInsets.all(8),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            onPressed: onSettingsPressed ?? () => _navigateToSettings(context),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Settings Screen - Full Page
// ═══════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: const ReusableTopBar(
        title: 'Settings',
        showSettingsButton: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Settings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Customize your experience',
                          style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Appearance'),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBackgroundDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dark Mode',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                      const SizedBox(height: 3),
                      Text(themeProvider.isDarkMode ? 'Dark theme is active' : 'Light theme is active',
                          style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
                    ],
                  ),
                ),
                Switch(value: themeProvider.isDarkMode, onChanged: themeProvider.toggleTheme, activeColor: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Account'),
          const SizedBox(height: 12),
          _buildSettingCard(context, icon: Icons.person_outline, title: 'Profile', subtitle: 'Manage your account',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsPage()))),
          _buildSettingCard(context, icon: Icons.lock_outline, title: 'Privacy & Security', subtitle: 'Change password',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityPage()))),
          const SizedBox(height: 24),
          _buildSectionTitle('Preferences'),
          const SizedBox(height: 12),
          _buildSettingCard(context, icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Coming soon', onTap: () {}),
          _buildSettingCard(context, icon: Icons.language_outlined, title: 'Language', subtitle: 'English (US)', onTap: () {}),
          const SizedBox(height: 24),
          _buildSectionTitle('Support'),
          const SizedBox(height: 12),
          _buildSettingCard(context, icon: Icons.help_outline, title: 'Help & Support', subtitle: 'FAQs and guidance',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()))),
          _buildSettingCard(context, icon: Icons.feedback_outlined, title: 'Send Feedback', subtitle: 'Share your thoughts',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendFeedbackPage()))),
          _buildSettingCard(context, icon: Icons.info_outline, title: 'About', subtitle: 'Version 1.0.0',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
          const SizedBox(height: 24),
          _buildSectionTitle('Account Actions'),
          const SizedBox(height: 12),
          _buildSettingCard(context, icon: Icons.logout_outlined, title: 'Logout', subtitle: 'Sign out of your account',
              iconColor: AppColors.danger, onTap: () => _showLogoutDialog(context)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
      );

  Widget _buildSettingCard(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBackgroundDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.getTextTertiary(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
