import 'package:flutter/material.dart';
import '../../conts/colors.dart';

class AppDropdownField extends StatelessWidget {
  final String label;
  final List<String> items;
  final TextEditingController controller;
  final IconData? icon;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.controller,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.text.isEmpty ? null : controller.text,
          hint: Text('Select $label'),
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => controller.text = value ?? '',
        ),
      ),
    );
  }
}
