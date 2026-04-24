import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/dashboard/patient_card.dart';
import 'package:oncoguide_v2/core/pages/dashboard/quick_actions.dart';
import 'package:oncoguide_v2/core/pages/dashboard/report_card.dart';
import 'package:oncoguide_v2/core/pages/history/scan_history_screen.dart';
import 'package:oncoguide_v2/core/pages/history/report_detail_screen.dart';
import '../../conts/colors.dart';
import '../../utils/animations.dart';
import 'top_bar.dart';
import 'stats_grid.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EnhancedTopBar(
          onProfileTap: () => Navigator.pushNamed(context, '/profile'),
          onNotificationTap: () =>
              Navigator.pushNamed(context, '/notifications'),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                SectionTitle('Overview Statistics'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StatisticsHorizontal(),
                ),
                const SizedBox(height: 28),
                SectionTitle('Quick Actions'),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: EnhancedQuickActions(),
                ),
                const SizedBox(height: 32),

                // ── Recent Scans (from Firestore) ─────────────────────────
                SectionHeader(
                  'Recent Scans',
                  onTap: () => Navigator.pushNamed(context, '/scan_history'),
                ),
                const SizedBox(height: 12),
                _RecentScansRow(uid: _uid),
                const SizedBox(height: 28),

                // ── Recent Patients (from Firestore) ──────────────────────
                SectionHeader(
                  'Recent Patients',
                  onTap: () => Navigator.pushNamed(context, '/patients_hub'),
                ),
                const SizedBox(height: 12),
                _RecentPatientsRow(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Scans — last 6 reports from Firestore
// ─────────────────────────────────────────────────────────────────────────────
class _RecentScansRow extends StatelessWidget {
  final String uid;
  const _RecentScansRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    // Merge mammogram + ultrasound, take latest 6
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mammogram_reports')
          .where('doctorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, mammoSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ultrasound_reports')
              .where('doctorId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, usSnap) {
            final mammoDocs = mammoSnap.data?.docs ?? [];
            final usDocs    = usSnap.data?.docs ?? [];

            final all = [
              ...mammoDocs.map((d) => {'id': d.id, 'type': 'mammogram', ...d.data()}),
              ...usDocs.map((d) => {'id': d.id, 'type': 'ultrasound', ...d.data()}),
            ];

            all.sort((a, b) {
              final ta = a['createdAt'];
              final tb = b['createdAt'];
              if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
              return 0;
            });

            final recent = all.take(6).toList();

            if (recent.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'No scans yet. Start a new analysis.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recent.length,
                itemBuilder: (_, i) {
                  final r = recent[i];
                  final isUS = r['type'] == 'ultrasound';
                  final status = isUS
                      ? (r['prediction']?.toString() ?? 'Unknown')
                      : (r['riskLabel']?.toString() ?? 'Unknown');
                  return Animations.slideUp(
                    delay: i * 100,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(reportData: r),
                        ),
                      ),
                      child: CompactReportCard(
                        reportName: isUS ? 'Ultrasound Report' : 'Mammogram Report',
                        patientName: r['patientName']?.toString() ?? 'Unknown',
                        date: _formatDate(r['createdAt']),
                        status: status,
                        index: i,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}-${_month(dt.month)}-${dt.year}';
    }
    return '';
  }

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Patients — last 4 from Firestore
// ─────────────────────────────────────────────────────────────────────────────
class _RecentPatientsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .orderBy('createdAt', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No patients yet. Add your first patient.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          );
        }

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final p = docs[i].data();
              final age = (p['age'] as num?)?.toInt() ?? 0;
              // Derive status from risk_patients collection if needed
              final status = p['status']?.toString() ?? 'Active';
              return Animations.slideUp(
                delay: i * 100,
                child: EnhancedPatientCard(
                  name: p['name']?.toString() ?? 'Unknown',
                  lastCheckup: _formatDate(p['createdAt']),
                  age: age,
                  stage: p['stage']?.toString() ?? '—',
                  status: status,
                  index: i,
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day}-${months[dt.month - 1]}-${dt.year}';
    }
    return 'N/A';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────
Widget SectionTitle(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

Widget SectionHeader(String title, {required VoidCallback onTap}) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
