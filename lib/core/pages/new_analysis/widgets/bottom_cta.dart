import 'package:flutter/material.dart';

import '../../../conts/colors.dart';
import '../screens/new_analysis_screen.dart';

class BottomCTA extends StatelessWidget {
  final bool tabularAdded;
  final Set<ImagingType> selectedImaging;
  final VoidCallback onStartAnalysis;

  const BottomCTA({
    super.key,
    required this.tabularAdded,
    required this.selectedImaging,
    required this.onStartAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canProceed = tabularAdded && selectedImaging.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canProceed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3D2F1F)
                    : const Color(0xFFFFA726).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFA726).withOpacity(isDark ? 0.4 : 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withOpacity(isDark ? 0.25 : 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFFFA726),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !tabularAdded
                          ? "Add clinical data to continue"
                          : "Select at least one imaging type",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            height: 62,
            decoration: BoxDecoration(
              gradient: canProceed
                  ? const LinearGradient(
                  colors: [Color(0xFFFF6F91), Color(0xFFFF8FA3)])
                  : null,
              color: canProceed
                  ? null
                  : (isDark
                  ? const Color(0xFF2A2D47)
                  : AppColors.border),
              borderRadius: BorderRadius.circular(18),
              boxShadow: canProceed
                  ? [
                BoxShadow(
                  color: const Color(0xFFFF6F91).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canProceed ? onStartAnalysis : null,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: canProceed
                            ? Colors.white
                            : AppColors.getTextSecondary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Start AI Analysis",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: canProceed
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}