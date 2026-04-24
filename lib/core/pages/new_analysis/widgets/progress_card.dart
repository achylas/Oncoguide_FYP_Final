import 'package:flutter/material.dart';

import '../../../conts/colors.dart';
import '../screens/new_analysis_screen.dart';

class ProgressCard extends StatelessWidget {
  final bool tabularAdded;
  final Set<ImagingType> selectedImaging;

  const ProgressCard({
    super.key,
    required this.tabularAdded,
    required this.selectedImaging,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSteps = 2;
    final completedSteps =
        (tabularAdded ? 1 : 0) + (selectedImaging.isNotEmpty ? 1 : 0);
    final progress = completedSteps / totalSteps;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1F33) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Progress",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$completedSteps of $totalSteps steps completed",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progress == 1.0
                        ? [AppColors.success, const Color(0xFF58D68D)]
                        : [const Color(0xFFFFA726), const Color(0xFFFFB74D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (progress == 1.0
                          ? AppColors.success
                          : const Color(0xFFFFA726))
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0E21)
                    : AppColors.background,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: progress == 1.0
                          ? [AppColors.success, const Color(0xFF58D68D)]
                          : [const Color(0xFFFF6F91), const Color(0xFFFF8FA3)],
                    ),
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