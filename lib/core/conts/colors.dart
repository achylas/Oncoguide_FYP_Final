import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS
  // ═══════════════════════════════════════════════════════════════════

  // Primary colors - soft, awareness-friendly
  static const primary = Color(0xFFFF6B9D); // Vibrant pink (ribbon)
  static const primaryLight = Color(0xFFFFB3CC); // Soft pink
  static const primaryDark = Color(0xFFE91E63); // Deep pink

  // Accent colors - complementary gentle tones
  static const accent = Color(0xFF74B9FF); // Light blue
  static const accentLight = Color(0xFFB3D9FF); // Soft baby blue
  static const accentPurple = Color(0xFFD1C4E9); // Light purple for contrast

  // Background colors (Light)
  static const background = Color(0xFFFDFDFD); // White-ish soft background
  static const cardBackground = Colors.white;
  static const surfaceLight = Color(0xFFFCE4EC); // Very light pink surface

  // Text colors (Light)
  static const textPrimary = Color(0xFF2D3436); // Charcoal
  static const textSecondary = Color(0xFF636E72); // Medium gray
  static const textTertiary = Color(0xFFB2BEC3); // Light gray

  // ═══════════════════════════════════════════════════════════════════
  // DARK THEME COLORS
  // ═══════════════════════════════════════════════════════════════════

  // Background colors (Dark)
  static const backgroundDark = Color(0xFF0A0E21); // Deep navy
  static const cardBackgroundDark = Color(0xFF1D1F33); // Dark card
  static const surfaceDark = Color(0xFF252842); // Elevated surface

  // Text colors (Dark)
  static const textPrimaryDark = Color(0xFFFFFFFF); // Pure white
  static const textSecondaryDark = Color(0xFFB0B3C5); // Light gray
  static const textTertiaryDark = Color(0xFF6C7080); // Muted gray

  // Border colors
  static const border = Color(0xFFE0E0E0);
  static const borderDark = Color(0xFF2A2D47);
  static const divider = Color(0xFFB0BEC5);
  static const dividerDark = Color(0xFF363A54);

  // ═══════════════════════════════════════════════════════════════════
  // STATUS COLORS (Works for both themes)
  // ═══════════════════════════════════════════════════════════════════

  static const success = Color(0xFF00B894); // Teal green
  static const successLight = Color(0xFFDFFFF7);
  static const successDark = Color(0xFF1A3D35);

  static const warning = Color(0xFFFDAA63); // Warm orange
  static const warningLight = Color(0xFFFFF4E6);
  static const warningDark = Color(0xFF3D2F1F);

  static const danger = Color(0xFFFF6B6B); // Soft red
  static const dangerLight = Color(0xFFFFE5E5);
  static const dangerDark = Color(0xFF3D1F1F);

  static const info = Color(0xFF74B9FF); // Soft blue
  static const infoLight = Color(0xFFE8F4FF);
  static const infoDark = Color(0xFF1F2C3D);

  // Medical specific colors
  static const medicalPink = Color(0xFFFFC1E3); // Gentle pink
  static const medicalBlue = Color(0xFFB3D9FF); // Gentle blue

  // Gradient colors (Enhanced for dark theme)
  static const gradientPink1 = Color(0xFFFFB3CC);
  static const gradientPink2 = Color(0xFFFF6B9D);
  static const gradientBlue1 = Color(0xFFB3D9FF);
  static const gradientBlue2 = Color(0xFF74B9FF);
  static const gradientPurple1 = Color(0xFFD1C4E9);
  static const gradientPurple2 = Color(0xFFE1BEE7);

  // Dark mode gradient colors
  static const gradientPinkDark1 = Color(0xFFFF6B9D);
  static const gradientPinkDark2 = Color(0xFFE91E63);
  static const gradientBlueDark1 = Color(0xFF74B9FF);
  static const gradientBlueDark2 = Color(0xFF5A9FDF);

  // Shadow colors
  static Color shadow = const Color(0xFFFF6B9D).withOpacity(0.12);
  static Color shadowLight = const Color(0xFF74B9FF).withOpacity(0.08);
  static Color shadowPink = const Color(0xFFFFB3CC).withOpacity(0.15);
  static Color shadowDark = const Color(0xFF000000).withOpacity(0.3);

  // ═══════════════════════════════════════════════════════════════════
  // THEME-AWARE GETTERS
  // ═══════════════════════════════════════════════════════════════════

  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : background;
  }

  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardBackgroundDark
        : cardBackground;
  }

  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDark
        : surfaceLight;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondary;
  }

  static Color getTextTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textTertiaryDark
        : textTertiary;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? borderDark
        : border;
  }

  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? dividerDark
        : divider;
  }

  static Color getShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? shadowDark
        : shadow;
  }

  static Color getSuccessBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? successDark
        : successLight;
  }

  static Color getWarningBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? warningDark
        : warningLight;
  }

  static Color getDangerBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? dangerDark
        : dangerLight;
  }

  static Color getInfoBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? infoDark
        : infoLight;
  }

  // ═══════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════

  static LinearGradient getPrimaryGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(
      colors: [gradientPinkDark1, gradientPinkDark2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : const LinearGradient(
      colors: [gradientPink1, gradientPink2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient getAccentGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(
      colors: [gradientBlueDark1, gradientBlueDark2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : const LinearGradient(
      colors: [gradientBlue1, gradientBlue2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Legacy gradient support
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientPink1, gradientPink2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [gradientBlue1, gradientBlue2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient healingGradient = LinearGradient(
    colors: [gradientPink1, gradientBlue2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [gradientPink2, gradientPurple2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [gradientBlue1, gradientBlue2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ribbonGradient = LinearGradient(
    colors: [gradientPink1, gradientPink2, gradientBlue2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════
  // STATUS & SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════

  static const statusCritical = Color(0xFFF41B1B);
  static const statusUnderTreatment = Color(0xFFFDAA63);
  static const statusStable = Color(0xFF00B894);
  static const statusRecovered = Color(0xFF6BCBA0);
  static const stageColor = Color(0xFF3F51B5);
  static const severityHigh = Color(0xFFB71C1C);
  static const severityMedium = Color(0xFFF57C00);
  static const severityLow = Color(0xFF2E7D32);

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'critical':
        return statusCritical;
      case 'under treatment':
        return statusUnderTreatment;
      case 'stable':
        return statusStable;
      case 'recovered':
        return statusRecovered;
      default:
        return textSecondary;
    }
  }

  static LinearGradient getGradient(String name) {
    switch (name.toLowerCase()) {
      case 'primary':
        return primaryGradient;
      case 'accent':
        return accentGradient;
      case 'healing':
        return healingGradient;
      case 'sunset':
        return sunsetGradient;
      case 'ocean':
        return oceanGradient;
      case 'ribbon':
        return ribbonGradient;
      default:
        return primaryGradient;
    }
  }

  // Chart colors
  static const List<Color> chartColors = [
    gradientPink2,
    gradientPurple2,
    gradientBlue2,
    Color(0xFFE91E63),
    Color(0xFF74B9FF),
    Color(0xFFB3D9FF),
  ];
}