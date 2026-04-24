import 'package:flutter/material.dart';

import '../../../conts/colors.dart';

class TabularDataCard extends StatelessWidget {
  final bool tabularAdded;
  final Map<String, dynamic>? selectedPatient;
  final VoidCallback onNewPatient;
  final VoidCallback onSelectExisting;
  final VoidCallback onEditPatient;

  const TabularDataCard({
    super.key,
    required this.tabularAdded,
    required this.selectedPatient,
    required this.onNewPatient,
    required this.onSelectExisting,
    required this.onEditPatient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tabularAdded
              ? (isDark
              ? [
            AppColors.success.withOpacity(0.15),
            const Color(0xFF1D1F33),
          ]
              : [
            const Color(0xFF2ECC71).withOpacity(0.12),
            Colors.white,
          ])
              : (isDark
              ? [const Color(0xFF1D1F33), const Color(0xFF1D1F33)]
              : [Colors.white, Colors.white]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tabularAdded
              ? AppColors.success
              : AppColors.getBorder(context),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: tabularAdded
                ? AppColors.success.withOpacity(isDark ? 0.3 : 0.2)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tabularAdded
                        ? [AppColors.success, const Color(0xFF58D68D)]
                        : [const Color(0xFF6C63FF), const Color(0xFF8B84FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (tabularAdded
                          ? AppColors.success
                          : const Color(0xFF6C63FF))
                          .withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  tabularAdded
                      ? Icons.check_circle_rounded
                      : Icons.table_chart_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clinical Data",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabularAdded
                          ? "Patient data selected ✓"
                          : "Required for analysis",
                      style: TextStyle(
                        fontSize: 13,
                        color: tabularAdded
                            ? AppColors.success
                            : const Color(0xFFFFA726),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (tabularAdded)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.success.withOpacity(0.25)
                        : AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "READY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildDataOptionButton(
                  context: context,
                  icon: Icons.person_add_rounded,
                  title: "New Patient",
                  subtitle: "Add new data",
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6F91), Color(0xFFFF8FA3)]),
                  onTap: onNewPatient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDataOptionButton(
                  context: context,
                  icon: Icons.folder_open_rounded,
                  title: "Existing",
                  subtitle: "Choose patient",
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)]),
                  onTap: onSelectExisting,
                ),
              ),
            ],
          ),
          if (tabularAdded && selectedPatient != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                    AppColors.success.withOpacity(0.15),
                    AppColors.success.withOpacity(0.08),
                  ]
                      : [
                    AppColors.success.withOpacity(0.1),
                    AppColors.success.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.success.withOpacity(isDark ? 0.4 : 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.success, Color(0xFF58D68D)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPatient!['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        if (selectedPatient!['age'] != 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            "${selectedPatient!['age']} years • ${selectedPatient!['medicalHistory'] ?? selectedPatient!['status'] ?? 'No history'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    onPressed: onEditPatient,
                  ),
                ],
              ),
            ),
          ],
          if (!tabularAdded) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0E21).withOpacity(0.5)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.getTextSecondary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Demographics, medical history & clinical parameters",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataOptionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                gradient.colors[0].withOpacity(0.2),
                gradient.colors[1].withOpacity(0.1),
              ]
                  : [
                gradient.colors[0].withOpacity(0.12),
                gradient.colors[1].withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gradient.colors[0].withOpacity(isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors[0].withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}