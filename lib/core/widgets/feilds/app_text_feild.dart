import 'package:flutter/material.dart';
import '../../conts/colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final int maxLines;
  final IconData? icon;
  final TextEditingController? controller;

  const AppTextField({
    super.key,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.icon,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent, width: 2)),
      ),
    );
  }
}
