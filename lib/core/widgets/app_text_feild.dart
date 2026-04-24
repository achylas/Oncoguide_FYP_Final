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
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType, // ← forward it
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
