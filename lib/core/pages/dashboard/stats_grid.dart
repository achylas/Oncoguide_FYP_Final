import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../conts/colors.dart';

class StatisticsHorizontal extends StatelessWidget {
  const StatisticsHorizontal({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').snapshots(),
      builder: (context, patientsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mammogram_reports')
              .where('doctorId', isEqualTo: _uid)
              .snapshots(),
          builder: (context, mammoSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ultrasound_reports')
                  .where('doctorId', isEqualTo: _uid)
                  .snapshots(),
              builder: (context, usSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('cancer_patients')
                      .where('flaggedBy', isEqualTo: _uid)
                      .snapshots(),
                  builder: (context, cancerSnap) {
                    final totalPatients = patientsSnap.data?.docs.length ?? 0;
                    final mammoReports  = mammoSnap.data?.docs.length ?? 0;
                    final usReports     = usSnap.data?.docs.length ?? 0;
                    final totalReports  = mammoReports + usReports;
                    final cancerPatients = cancerSnap.data?.docs.length ?? 0;

                    final now     = DateTime.now();
                    final weekAgo = now.subtract(const Duration(days: 7));
                    int thisWeek  = 0;
                    for (final doc in [
                      ...mammoSnap.data?.docs ?? [],
                      ...usSnap.data?.docs ?? [],
                    ]) {
                      final ts = doc['createdAt'];
                      if (ts is Timestamp && ts.toDate().isAfter(weekAgo)) thisWeek++;
                    }

                    final stats = [
                      _StatData('Total Patients', '$totalPatients', Icons.people_rounded,
                          const LinearGradient(colors: [Color(0xFFFF6F91), Color(0xFFFF8FA3)])),
                      _StatData('Total Reports', '$totalReports', Icons.local_hospital_rounded,
                          const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)])),
                      _StatData('Cancer Cases', '$cancerPatients', Icons.coronavirus_rounded,
                          const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF87171)])),
                      _StatData('This Week', '$thisWeek', Icons.calendar_today_rounded,
                          const LinearGradient(colors: [Color(0xFF26C6DA), Color(0xFF4DD0E1)])),
                    ];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.7,
                        children: stats
                            .map((s) => StatCard(
                                  title: s.title,
                                  value: s.value,
                                  icon: s.icon,
                                  gradient: s.gradient,
                                ))
                            .toList(),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  const _StatData(this.title, this.value, this.icon, this.gradient);
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final bool isPositive; // kept for backward compat

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final borderColor = gradient.colors.last.withOpacity(isDark ? 0.4 : 0.25);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
