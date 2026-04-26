import 'package:flutter/material.dart';
import '../../conts/colors.dart';

class CompactReportCard extends StatelessWidget {
  final String reportName;
  final String patientName;
  final String date;
  final String status;
  final int index;

  const CompactReportCard({
    super.key,
    required this.reportName,
    required this.patientName,
    required this.date,
    required this.status,
    required this.index,
  });

  Color _statusColor() {
    switch (status) {
      case 'Malignant':
        return const Color(0xFFEF4444);
      case 'High Risk':
        return const Color(0xFFEF4444);
      case 'Benign':
        return const Color(0xFFF59E0B);
      case 'Normal':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _statusIcon() {
    switch (status) {
      case 'Malignant':
      case 'High Risk':
        return Icons.warning_rounded;
      case 'Benign':
        return Icons.info_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  bool get _isMammo => reportName.toLowerCase().contains('mammo');

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final color   = _statusColor();
    final accent  = _isMammo ? const Color(0xFFFF6F91) : const Color(0xFF6C63FF);

    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient top strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.6)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isMammo
                            ? Icons.monitor_heart_outlined
                            : Icons.waves_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(), size: 10, color: color),
                          const SizedBox(width: 3),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Report type
                Text(
                  reportName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  patientName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                Divider(
                  height: 1,
                  color: AppColors.getBorder(context).withOpacity(0.5),
                ),
                const SizedBox(height: 10),

                // Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
