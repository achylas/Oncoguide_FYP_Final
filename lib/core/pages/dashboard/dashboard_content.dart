import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/dashboard/patient_card.dart';
import 'package:oncoguide_v2/core/pages/dashboard/quick_actions.dart';
import 'package:oncoguide_v2/core/pages/dashboard/report_card.dart';
import 'package:oncoguide_v2/core/pages/history/report_detail_screen.dart';
import 'package:oncoguide_v2/core/pages/patients/patient_profile_screen.dart';
import '../../conts/colors.dart';
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
          onNotificationTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── 1. Hero banner ────────────────────────────────────────
                const _HeroBanner(),
                const SizedBox(height: 24),

                // ── 2. Stats grid ─────────────────────────────────────────
                _SectionLabel('Overview'),
                const SizedBox(height: 12),
                const StatisticsHorizontal(),
                const SizedBox(height: 24),

                // ── 3. Quick Actions ──────────────────────────────────────
                _SectionLabel('Quick Access'),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: EnhancedQuickActions(),
                ),
                const SizedBox(height: 28),

                // ── 4. Recent Scans ───────────────────────────────────────
                _SectionLabelWithAction(
                  'Recent Scans',
                  onTap: () => Navigator.pushNamed(context, '/scan_history'),
                ),
                const SizedBox(height: 12),
                _RecentScansRow(uid: _uid),
                const SizedBox(height: 28),

                // ── 5. Recent Patients ────────────────────────────────────
                _SectionLabelWithAction(
                  'Recent Patients',
                  onTap: () => Navigator.pushNamed(context, '/patients_hub'),
                ),
                const SizedBox(height: 12),
                const _RecentPatientsRow(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner — richer design with decorative elements
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6F91).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'AI-Assisted Oncology',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Breast Cancer\nEarly Detection',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Powered by Machine Learning',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Brain icon in glassy circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Scans
// ─────────────────────────────────────────────────────────────────────────────
class _RecentScansRow extends StatelessWidget {
  final String uid;
  const _RecentScansRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mammogram_reports')
          .where('doctorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, mammoSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ultrasound_reports')
              .where('doctorId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(20)
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

            final seen   = <String>{};
            final unique = <Map<String, dynamic>>[];
            for (final r in all) {
              final pid = r['patientId']?.toString() ?? r['id']?.toString() ?? '';
              if (!seen.contains(pid)) { seen.add(pid); unique.add(r); }
            }

            final recent = unique.take(6).toList();

            if (recent.isEmpty) {
              return _EmptyState(
                icon: Icons.description_outlined,
                message: 'No scans yet',
                sub: 'Generate a report from a patient record',
              );
            }

            return SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recent.length,
                itemBuilder: (_, i) {
                  final r      = recent[i];
                  final isUS   = r['type'] == 'ultrasound';
                  final usPred = r['usPrediction']?.toString() ??
                      r['prediction']?.toString();
                  final riskLbl = r['riskLabel']?.toString();
                  final status  = usPred ?? riskLbl ?? 'Unknown';

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailScreen(reportData: r),
                      ),
                    ),
                    child: CompactReportCard(
                      reportName: isUS ? 'Ultrasound' : 'Mammogram',
                      patientName: r['patientName']?.toString() ?? 'Unknown',
                      date: _fmtDate(r['createdAt']),
                      status: status,
                      index: i,
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

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    }
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Patients — with navigation fix
// ─────────────────────────────────────────────────────────────────────────────
class _RecentPatientsRow extends StatelessWidget {
  const _RecentPatientsRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline_rounded,
            message: 'No patients yet',
            sub: 'Patients added via the web portal appear here',
          );
        }

        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final p   = docs[i].data();
              final pid = docs[i].id;
              final age = (p['age'] as num?)?.toInt() ?? 0;
              final name = p['name']?.toString() ?? 'Unknown';

              return _PatientCardWithStatus(
                patientId: pid,
                name: name,
                age: age,
                createdAt: p['createdAt'],
                index: i,
              );
            },
          ),
        );
      },
    );
  }
}

class _PatientCardWithStatus extends StatelessWidget {
  final String patientId;
  final String name;
  final int age;
  final dynamic createdAt;
  final int index;

  const _PatientCardWithStatus({
    required this.patientId,
    required this.name,
    required this.age,
    required this.createdAt,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mammogram_reports')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, mammoSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ultrasound_reports')
              .where('patientId', isEqualTo: patientId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, usSnap) {
            Map<String, dynamic>? latestReport;
            Timestamp? latestTs;

            final mammoDoc = mammoSnap.data?.docs.firstOrNull;
            final usDoc    = usSnap.data?.docs.firstOrNull;

            if (mammoDoc != null) {
              final ts = mammoDoc.data()['createdAt'];
              if (ts is Timestamp) latestTs = ts;
              latestReport = {
                'type': 'mammogram',
                'id': mammoDoc.id,
                ...mammoDoc.data()
              };
            }
            if (usDoc != null) {
              final ts = usDoc.data()['createdAt'];
              if (ts is Timestamp &&
                  (latestTs == null || ts.compareTo(latestTs) > 0)) {
                latestReport = {
                  'type': 'ultrasound',
                  'id': usDoc.id,
                  ...usDoc.data()
                };
              }
            }

            String status = 'No Reports';
            if (latestReport != null) {
              final usPred  = latestReport['usPrediction']?.toString() ??
                  latestReport['prediction']?.toString();
              final riskLbl = latestReport['riskLabel']?.toString();
              if (usPred == 'Malignant')       status = 'Malignant';
              else if (usPred == 'Benign')     status = 'Benign';
              else if (usPred == 'Normal')     status = 'Normal';
              else if (riskLbl == 'High Risk') status = 'High Risk';
              else if (riskLbl != null)        status = riskLbl;
            }

            return EnhancedPatientCard(
              name: name,
              lastCheckup: _fmtDate(createdAt),
              age: age,
              stage: status,
              status: status == 'Malignant'
                  ? 'Critical'
                  : status == 'High Risk'
                      ? 'High Risk'
                      : 'Active',
              index: index,
              // ── Navigation fix ──────────────────────────────────────────
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientProfileScreen(
                    patientId: patientId,
                    patientName: name,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    }
    return 'N/A';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.getBorder(context).withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _SectionLabel(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
      ),
    );

Widget _SectionLabelWithAction(String title, {required VoidCallback onTap}) =>
    Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(context),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

// Legacy aliases — keep other files compiling
Widget SectionTitle(String text) => _SectionLabel(text);
Widget SectionHeader(String title, {required VoidCallback onTap}) =>
    _SectionLabelWithAction(title, onTap: onTap);
