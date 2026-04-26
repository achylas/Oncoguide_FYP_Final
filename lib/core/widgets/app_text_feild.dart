import 'package:flutter/material.dart';

import '../conts/colors.dart';

class AppTextField extends StatelessWidget {
  final String hintText;
  final String? label; // <-- optional label
  final IconData? icon; // <-- optional icon
  final int maxLines;
  final bool isPassword;
  final TextEditingController controller;
  final TextInputType? keyboardType; // ← add this
  final String? Function(String?)? validator; //

  const AppTextField({
    super.key,
    this.label,
    this.icon,
    this.maxLines = 1,
    required this.hintText,
    this.isPassword = false,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1D1F33) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final hintColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE0E0E0);

    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      cursorColor: AppColors.accent,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 1.8),
        ),
      ),
    );
  }
}
