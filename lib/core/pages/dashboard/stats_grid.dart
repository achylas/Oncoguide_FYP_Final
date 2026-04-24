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
                    final totalPatients =
                        patientsSnap.data?.docs.length ?? 0;
                    final mammoReports =
                        mammoSnap.data?.docs.length ?? 0;
                    final usReports =
                        usSnap.data?.docs.length ?? 0;
                    final totalReports = mammoReports + usReports;
                    final cancerPatients =
                        cancerSnap.data?.docs.length ?? 0;

                    // This week count
                    final now = DateTime.now();
                    final weekAgo =
                        now.subtract(const Duration(days: 7));
                    int thisWeek = 0;
                    for (final doc in [
                      ...mammoSnap.data?.docs ?? [],
                      ...usSnap.data?.docs ?? [],
                    ]) {
                      final ts = doc['createdAt'];
                      if (ts is Timestamp) {
                        if (ts.toDate().isAfter(weekAgo)) thisWeek++;
                      }
                    }

                    final stats = [
                      {
                        'title': 'Total Patients',
                        'value': '$totalPatients',
                        'icon': Icons.people_rounded,
                        'gradient': const LinearGradient(colors: [Color(0xFFFF6F91), Color(0xFFFF8FA3)]),
                        'percentage': '',
                        'isPositive': true,
                      },
                      {
                        'title': 'Total Reports',
                        'value': '$totalReports',
                        'icon': Icons.local_hospital_rounded,
                        'gradient': const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)]),
                        'percentage': '',
                        'isPositive': true,
                      },
                      {
                        'title': 'Cancer Cases',
                        'value': '$cancerPatients',
                        'icon': Icons.coronavirus_rounded,
                        'gradient': const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF87171)]),
                        'percentage': '',
                        'isPositive': false,
                      },
                      {
                        'title': 'This Week',
                        'value': '$thisWeek',
                        'icon': Icons.calendar_today_rounded,
                        'gradient': const LinearGradient(colors: [Color(0xFF26C6DA), Color(0xFF4DD0E1)]),
                        'percentage': '',
                        'isPositive': true,
                      },
                    ];

                    return SizedBox(
                      height: 100,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: stats.asMap().entries.map((entry) {
                            final i = entry.key;
                            final stat = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                  right: i == stats.length - 1 ? 0 : 10),
                              child: StatCard(
                                title: stat['title'] as String,
                                value: stat['value'] as String,
                                icon: stat['icon'] as IconData,
                                gradient: stat['gradient'] as LinearGradient,
                                isPositive: stat['isPositive'] as bool,
                              ),
                            );
                          }).toList(),
                        ),
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

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final bool isPositive;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = gradient.colors.last.withOpacity(isDark ? 0.5 : 0.35);

    return Container(
      width: 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
