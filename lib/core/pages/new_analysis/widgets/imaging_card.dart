import 'dart:io';
import '../../../conts/colors.dart';

import 'package:flutter/material.dart';

import '../../../utils/scan_input_handler.dart';
import '../../../widgets/scan/scan_input_sheet.dart';
import '../screens/new_analysis_screen.dart';
import '../screens/scan_preview_page.dart';

class ImagingCard extends StatelessWidget {
  final ImagingType type;
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final bool isSelected;
  final bool isDisabled;
  final File? uploadedFile;
  final ValueChanged<File?> onToggle;

  const ImagingCard({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.isSelected,
    required this.isDisabled,
    required this.uploadedFile,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isDisabled
            ? null
            : () async {
          if (isSelected) {
            final remove = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF1D1F33)
                    : Colors.white,
                title: Text(
                  "Remove image?",
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                content: Text(
                  "This will clear the uploaded scan.",
                  style: TextStyle(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "Remove",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (remove == true) {
              onToggle(null);
            }
            return;
          }

          final selectedType = await showModalBottomSheet<ScanInputType>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ScanInputSheet(
              title: "Upload $title",
              onSelected: (_) {},
            ),
          );

          if (selectedType == null) return;

          final file =
          await ScanInputHandler.handleInput(context, selectedType);
          if (file == null) return;

          final returnedFile = await Navigator.push<File?>(
            context,
            MaterialPageRoute(
              builder: (context) => ScanPreviewPage(
                imageFile: file,
                scanType: title,
              ),
            ),
          );

          if (returnedFile != null) {
            onToggle(returnedFile);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: isSelected ? gradient : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF1D1F33) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : gradient.colors[0].withOpacity(isDark ? 0.4 : 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? gradient.colors[0].withOpacity(0.3)
                    : Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: isSelected ? 20 : 12,
                offset: Offset(0, isSelected ? 8 : 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : gradient.colors[0].withOpacity(isDark ? 0.2 : 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: isSelected ? Colors.white : gradient.colors[0],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSelected
                              ? "Uploaded • ${uploadedFile?.path.split('/').last ?? 'file'}"
                              : "Tap to upload",
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white.withOpacity(0.9)
                                : gradient.colors[0],
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.white : gradient.colors[0],
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: gradient.colors[0],
                    )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.15)
                      : (isDark
                      ? const Color(0xFF0A0E21).withOpacity(0.5)
                      : AppColors.background.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}