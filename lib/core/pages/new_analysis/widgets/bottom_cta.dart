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

    // Check if CC is selected but MLO is missing (density requires both)
    final bool ccSelected  = selectedImaging.contains(ImagingType.mammogram);
    final bool mloSelected = selectedImaging.contains(ImagingType.mammogramMlo);

    // Mammogram CC and MLO are always required together — no exceptions
    final bool needsMlo = ccSelected && !mloSelected;
    final bool needsCc  = mloSelected && !ccSelected;
    final bool mammogramIncomplete = needsMlo || needsCc;

    // Ready only when tabular added, at least one imaging, and mammogram pair is complete
    final bool readyToStart = canProceed && !mammogramIncomplete;

    String hintMessage = '';
    if (!tabularAdded) {
      hintMessage = 'Add clinical data to continue';
    } else if (selectedImaging.isEmpty) {
      hintMessage = 'Select at least one imaging type';
    } else if (needsMlo) {
      hintMessage = 'Mammogram requires both CC and MLO views — please upload the MLO view';
    } else if (needsCc) {
      hintMessage = 'Mammogram requires both CC and MLO views — please upload the CC view';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!readyToStart)
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
                      hintMessage,
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
              gradient: readyToStart
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6F91), Color(0xFFFF8FA3)])
                  : null,
              color: readyToStart
                  ? null
                  : (isDark
                      ? const Color(0xFF2A2D47)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(18),
              boxShadow: readyToStart
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
                onTap: readyToStart ? onStartAnalysis : null,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: readyToStart
                            ? Colors.white
                            : AppColors.getTextSecondary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _buttonLabel(selectedImaging),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: readyToStart
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

// Returns a context-aware button label based on what's selected
String _buttonLabel(Set<ImagingType> selected) {
  final hasMammo = selected.contains(ImagingType.mammogram) ||
      selected.contains(ImagingType.mammogramMlo);
  final hasUs = selected.contains(ImagingType.ultrasound);
  if (hasMammo && hasUs) return 'Start Multi-Modal Analysis';
  if (hasMammo) return 'Start Mammogram Analysis';
  if (hasUs)    return 'Start Ultrasound Analysis';
  return 'Start AI Analysis';
}