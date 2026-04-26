import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/core/pages/comparison/select_reports_screen.dart';
import 'package:oncoguide_v2/core/pages/history/report_detail_screen.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/analysis_loading_screen.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/new_analysis_screen.dart';
import 'package:oncoguide_v2/core/widgets/resuable_top_bar.dart';
import 'package:oncoguide_v2/services/patient_images_service.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PatientProfileScreen — 3 tabs: Clinical Data | Reports | Images
// Generate Report is a FAB that opens a dedicated full-screen page
// ─────────────────────────────────────────────────────────────────────────────

class PatientProfileScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const PatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: _GenerateReportFAB(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('patients')
            .doc(widget.patientId)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final patient = snap.data?.exists == true
              ? {'id': snap.data!.id, ...snap.data!.data()!}
              : <String, dynamic>{};

          return Column(
            children: [
              // ── Patient hero header ──────────────────────────────────────
              _PatientHero(
                patient: patient,
                patientId: widget.patientId,
              ),

              // ── Tab bar ──────────────────────────────────────────────────
              Container(
                color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.getTextSecondary(context),
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline_rounded, size: 18), text: 'Clinical'),
                    Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Reports'),
                    Tab(icon: Icon(Icons.photo_library_outlined, size: 18), text: 'Images'),
                  ],
                ),
              ),

              // ── Tab views ────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ClinicalDataTab(patient: patient),
                    _ReportsTab(patientId: widget.patientId),
                    _ImagesTab(patientId: widget.patientId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate Report FAB
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateReportFAB extends StatelessWidget {
  final String patientId;
  final String patientName;
  const _GenerateReportFAB({
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F91).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _GenerateReportScreen(
                patientId: patientId,
                patientName: patientName,
              ),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Generate Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Hero Header
// ─────────────────────────────────────────────────────────────────────────────

class _PatientHero extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String patientId;
  const _PatientHero({required this.patient, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final name     = patient['name']?.toString() ?? 'Unknown';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Patient Record',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              _LatestStatusBadge(patientId: patientId),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestStatusBadge extends StatelessWidget {
  final String patientId;
  const _LatestStatusBadge({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ultrasound_reports')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, usSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('mammogram_reports')
              .where('patientId', isEqualTo: patientId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, mammoSnap) {
            String label = 'No Scan';
            Color color  = Colors.white.withOpacity(0.3);

            final usDoc    = usSnap.data?.docs.firstOrNull;
            final mammoDoc = mammoSnap.data?.docs.firstOrNull;

            Map<String, dynamic>? latest;
            Timestamp? latestTs;

            if (mammoDoc != null) {
              final ts = mammoDoc.data()['createdAt'];
              if (ts is Timestamp) latestTs = ts;
              latest = mammoDoc.data();
            }
            if (usDoc != null) {
              final ts = usDoc.data()['createdAt'];
              if (ts is Timestamp &&
                  (latestTs == null || ts.compareTo(latestTs) > 0)) {
                latest = usDoc.data();
              }
            }

            if (latest != null) {
              final pred = latest['usPrediction']?.toString() ??
                  latest['prediction']?.toString();
              final risk = latest['riskLabel']?.toString();
              if (pred == 'Malignant') {
                label = 'Malignant';
                color = const Color(0xFFEF4444);
              } else if (pred == 'Benign') {
                label = 'Benign';
                color = const Color(0xFFF59E0B);
              } else if (pred == 'Normal') {
                label = 'Normal';
                color = const Color(0xFF10B981);
              } else if (risk == 'High Risk') {
                label = 'High Risk';
                color = const Color(0xFFEF4444);
              } else if (risk != null && risk.isNotEmpty) {
                label = risk;
                color = const Color(0xFF10B981);
              } else {
                label = 'Scanned';
                color = Colors.white.withOpacity(0.4);
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.6), width: 1.5),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Clinical Data
// ─────────────────────────────────────────────────────────────────────────────

class _ClinicalDataTab extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _ClinicalDataTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    if (patient.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 56,
                color: AppColors.getTextSecondary(context).withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No clinical data available',
                style: TextStyle(color: AppColors.getTextSecondary(context))),
          ],
        ),
      );
    }

    final repro    = patient['reproductive'] as Map<String, dynamic>? ?? {};
    final clinical = patient['clinicalAssessment'] as Map<String, dynamic>? ?? {};

    final sections = [
      _ClinicalSection(
        title: 'Demographics',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF6366F1),
        fields: {
          'Name'  : patient['name']?.toString() ?? '—',
          'Age'   : '${patient['age'] ?? '—'} years',
          'Weight': '${patient['weight'] ?? '—'} kg',
          'BMI'   : clinical['imc']?.toString() ?? patient['imc']?.toString() ?? '—',
        },
      ),
      _ClinicalSection(
        title: 'Reproductive History',
        icon: Icons.favorite_outline_rounded,
        color: const Color(0xFFFF6F91),
        fields: {
          'Age at Menarche'     : repro['menarche']?.toString() ?? '—',
          'Menopause Age'       : repro['menopauseAge']?.toString() ?? '—',
          'Menopause Status'    : repro['menopauseStatus'] == 1 ? 'Yes' : 'No',
          'Pregnancy'           : repro['pregnancy'] == 1 ? 'Yes' : 'No',
          'Age at 1st Pregnancy': repro['ageFirstPregnancy']?.toString() ?? '—',
          'No. of Children'     : repro['numberOfChildren']?.toString() ?? '—',
          'Breastfeeding'       : repro['breastfeeding'] == 1 ? 'Yes' : 'No',
        },
      ),
      _ClinicalSection(
        title: 'Family & Lifestyle',
        icon: Icons.groups_outlined,
        color: const Color(0xFF10B981),
        fields: {
          'Family History'       : patient['familyHistory'] == 1 ? 'Yes' : 'No',
          'Family History Count' : patient['familyHistoryCount']?.toString() ?? '—',
          'Family History Degree': patient['familyHistoryDegree']?.toString() ?? '—',
          'Regular Exercise'     : patient['exerciseRegular'] == 1 ? 'Yes' : 'No',
        },
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: sections.map((s) => _ClinicalCard(section: s)).toList(),
    );
  }
}

class _ClinicalSection {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> fields;
  const _ClinicalSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
  });
}

class _ClinicalCard extends StatelessWidget {
  final _ClinicalSection section;
  const _ClinicalCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: section.color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(section.icon, color: section.color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: AppColors.getBorder(context).withOpacity(0.5),
          ),
          ...section.fields.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Reports (Radiologist + Doctor, sectioned)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  final String patientId;
  const _ReportsTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('radiologist_reports')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, radioSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('mammogram_reports')
              .where('patientId', isEqualTo: patientId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, mammoSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('ultrasound_reports')
                  .where('patientId', isEqualTo: patientId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, usSnap) {
                final isLoading =
                    radioSnap.connectionState == ConnectionState.waiting ||
                    mammoSnap.connectionState == ConnectionState.waiting ||
                    usSnap.connectionState == ConnectionState.waiting;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (mammoSnap.hasError || usSnap.hasError) {
                  return _IndexErrorState(
                    error: (mammoSnap.error ?? usSnap.error).toString(),
                  );
                }

                final radiologistReports = (radioSnap.data?.docs ?? [])
                    .map((d) => {'id': d.id, 'source': 'radiologist', ...d.data()})
                    .toList();

                final doctorReports = [
                  ...(mammoSnap.data?.docs ?? []).map(
                      (d) => {'id': d.id, 'type': 'mammogram', 'source': 'doctor', ...d.data()}),
                  ...(usSnap.data?.docs ?? []).map(
                      (d) => {'id': d.id, 'type': 'ultrasound', 'source': 'doctor', ...d.data()}),
                ];
                doctorReports.sort((a, b) {
                  final ta = a['createdAt'];
                  final tb = b['createdAt'];
                  if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                  return 0;
                });

                final hasAny = radiologistReports.isNotEmpty || doctorReports.isNotEmpty;

                if (!hasAny) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.description_outlined,
                              size: 48, color: AppColors.primary.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 16),
                        Text('No reports yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextSecondary(context),
                            )),
                        const SizedBox(height: 6),
                        Text('Generate a report using the button below',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(context).withOpacity(0.6),
                            )),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // ── Compare Reports Button ───────────────────────────
                    if (doctorReports.length >= 2) ...[
                      _CompareReportsButton(
                        patientId: patientId,
                        patientName: radiologistReports.isNotEmpty
                            ? radiologistReports.first['patientName']?.toString() ?? 'Unknown'
                            : doctorReports.first['patientName']?.toString() ?? 'Unknown',
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Radiologist Reports ──────────────────────────────
                    _ReportSectionHeader(
                      label: 'Radiologist Reports',
                      icon: Icons.local_hospital_rounded,
                      color: const Color(0xFF6C63FF),
                      count: radiologistReports.length,
                    ),
                    const SizedBox(height: 10),
                    if (radiologistReports.isEmpty)
                      _EmptySectionNote('No radiologist reports yet')
                    else
                      ...radiologistReports.map((r) => _RadiologistReportCard(data: r)),
                    const SizedBox(height: 20),

                    // ── Doctor Reports ───────────────────────────────────
                    _ReportSectionHeader(
                      label: 'Doctor Reports',
                      icon: Icons.medical_services_outlined,
                      color: const Color(0xFFFF6F91),
                      count: doctorReports.length,
                    ),
                    const SizedBox(height: 10),
                    if (doctorReports.isEmpty)
                      _EmptySectionNote('No doctor reports yet')
                    else
                      ...doctorReports.map((r) => _DoctorReportCard(data: r)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  const _ReportSectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySectionNote extends StatelessWidget {
  final String message;
  const _EmptySectionNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.getTextSecondary(context),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// Radiologist report card
class _RadiologistReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RadiologistReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final densityLabel = data['densityLabel']?.toString() ?? '';
    final riskLabel    = data['riskLabel']?.toString() ?? '';
    final scanLabel    = data['scanLabel']?.toString() ?? 'Scan';
    final ccUrl        = data['ccImageUrl']?.toString();
    final mloUrl       = data['mloImageUrl']?.toString();
    final thumbUrl     = ccUrl ?? mloUrl;
    final confidence   = (data['densityConfidence'] as num?)?.toDouble() ?? 0.0;

    String dateStr = '';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateStr = '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportData: data)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.1 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 80,
                height: 88,
                child: thumbUrl != null
                    ? Image.network(thumbUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(
                            const Color(0xFF6C63FF), Icons.monitor_heart_outlined))
                    : _thumbPlaceholder(
                        const Color(0xFF6C63FF), Icons.monitor_heart_outlined),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Radiologist',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scanLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (densityLabel.isNotEmpty)
                          _MiniChip(densityLabel, const Color(0xFF6C63FF)),
                        if (riskLabel.isNotEmpty)
                          _MiniChip(
                            riskLabel,
                            riskLabel == 'High Risk'
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        if (confidence > 0)
                          _MiniChip(
                            '${confidence.toStringAsFixed(0)}% conf',
                            Colors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// Doctor report card
class _DoctorReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DoctorReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final type        = data['type']?.toString() ?? 'mammogram';
    final isMammo     = type == 'mammogram';
    final color       = isMammo ? const Color(0xFFFF6F91) : const Color(0xFF6C63FF);
    final icon        = isMammo ? Icons.monitor_heart_outlined : Icons.waves_rounded;
    final riskLabel   = data['riskLabel']?.toString() ?? '';
    final riskPct     = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final prediction  = data['usPrediction']?.toString() ?? data['prediction']?.toString();
    final imageUrl    = data['mammogramUrl']?.toString() ?? data['ultrasoundUrl']?.toString();

    final isHighRisk  = riskLabel == 'High Risk';
    final isMalignant = prediction == 'Malignant';
    final isBenign    = prediction == 'Benign';
    final badgeColor  = isMalignant
        ? const Color(0xFFEF4444)
        : isBenign
            ? const Color(0xFFF59E0B)
            : isHighRisk
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981);
    final badgeText   = prediction ??
        (isHighRisk ? 'High Risk' : riskLabel.isNotEmpty ? riskLabel : 'Low Risk');

    String dateStr = '';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateStr = '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportData: data)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.08 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 80,
                height: 88,
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(color, icon))
                    : _thumbPlaceholder(color, icon),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Doctor',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(icon, size: 12, color: color),
                        const SizedBox(width: 3),
                        Text(
                          isMammo ? 'Mammogram' : 'Ultrasound',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (badgeText.isNotEmpty)
                          _MiniChip(badgeText, badgeColor),
                        if (riskPct > 0)
                          _MiniChip(
                            '${riskPct.toStringAsFixed(0)}% risk',
                            Colors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _thumbPlaceholder(Color color, IconData icon) => Container(
      color: color.withOpacity(0.1),
      child: Center(child: Icon(icon, color: color, size: 28)),
    );

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Images (date-grouped, lightbox on tap)
// ─────────────────────────────────────────────────────────────────────────────

class _ImagesTab extends StatelessWidget {
  final String patientId;
  const _ImagesTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PatientImagesService.patientImagesStream(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      size: 48, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No images yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Images are uploaded by the radiologist\nfrom the web portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        // Group by image type (mammogram vs ultrasound)
        final mammograms = <Map<String, dynamic>>[];
        final ultrasounds = <Map<String, dynamic>>[];
        
        for (final doc in docs) {
          final data = {'id': doc.id, ...doc.data()};
          final imageType = data['imageType']?.toString() ?? '';
          
          if (imageType == 'mammogram') {
            mammograms.add(data);
          } else if (imageType == 'ultrasound') {
            ultrasounds.add(data);
          }
        }

        // Sort each group by date (most recent first)
        mammograms.sort((a, b) {
          final aTs = a['uploadedAt'] as Timestamp?;
          final bTs = b['uploadedAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });
        
        ultrasounds.sort((a, b) {
          final aTs = a['uploadedAt'] as Timestamp?;
          final bTs = b['uploadedAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (mammograms.isNotEmpty)
              _ImageTypeGroup(
                typeLabel: 'Mammograms',
                images: mammograms,
                isMammogram: true,
              ),
            if (ultrasounds.isNotEmpty)
              _ImageTypeGroup(
                typeLabel: 'Ultrasounds',
                images: ultrasounds,
                isMammogram: false,
              ),
          ],
        );
      },
    );
  }
}

class _ImageTypeGroup extends StatelessWidget {
  final String typeLabel;
  final List<Map<String, dynamic>> images;
  final bool isMammogram;
  const _ImageTypeGroup({
    required this.typeLabel,
    required this.images,
    required this.isMammogram,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isMammogram ? const Color(0xFFFF6F91) : const Color(0xFF6C63FF);
    final icon = isMammogram ? Icons.monitor_heart_outlined : Icons.waves_rounded;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${images.length} scan${images.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 10),
                  height: 1,
                  color: AppColors.getBorder(context).withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scroll of image cards
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (ctx, i) => _ImageCard(data: images[i]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ImageCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final url        = data['imageUrl']?.toString() ?? '';
    final label      = data['scanLabel']?.toString() ?? '';
    final score      = (data['validationScore'] as num?)?.toInt() ?? 0;
    final isMammo    = data['imageType'] == 'mammogram';
    final accentColor = isMammo ? const Color(0xFFFF6F91) : const Color(0xFF6C63FF);

    Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF10B981);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = const Color(0xFFEF4444);
    }

    return GestureDetector(
      onTap: () => _showLightbox(context, url, label, score, isMammo),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: url.isNotEmpty
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: accentColor.withOpacity(0.1),
                              child: Icon(
                                isMammo ? Icons.monitor_heart_outlined : Icons.waves_rounded,
                                color: accentColor,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            color: accentColor.withOpacity(0.1),
                            child: Icon(
                              isMammo ? Icons.monitor_heart_outlined : Icons.waves_rounded,
                              color: accentColor,
                              size: 28,
                            ),
                          ),
                  ),
                  // Score badge
                  if (score > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ),
                  // Type badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isMammo ? 'Mammo' : 'US',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                label.isNotEmpty ? label : 'Scan',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLightbox(BuildContext context, String url, String label, int score, bool isMammo) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (ctx) => _ImageLightbox(
        url: url,
        label: label,
        score: score,
        isMammo: isMammo,
      ),
    );
  }
}

class _ImageLightbox extends StatelessWidget {
  final String url;
  final String label;
  final int score;
  final bool isMammo;
  const _ImageLightbox({
    required this.url,
    required this.label,
    required this.score,
    required this.isMammo,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isMammo ? const Color(0xFFFF6F91) : const Color(0xFF6C63FF);
    Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF10B981);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = const Color(0xFFEF4444);
    }

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Image centered
            Center(
              child: GestureDetector(
                onTap: () {}, // prevent close on image tap
                child: Hero(
                  tag: url,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Info
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label.isNotEmpty ? label : 'Scan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (score > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'AI: $score%',
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
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
// Generate Report Screen — full page, image selection + analysis launch
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateReportScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const _GenerateReportScreen({
    required this.patientId,
    required this.patientName,
  });

  @override
  State<_GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<_GenerateReportScreen> {
  Map<String, dynamic>? _selectedCc;
  Map<String, dynamic>? _selectedMlo;
  Map<String, dynamic>? _selectedUs;
  bool _isLoading = false;

  Future<File?> _downloadToFile(Map<String, dynamic> doc) async {
    final url = doc['imageUrl']?.toString() ?? '';
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      final dir  = await getTemporaryDirectory();
      final name = doc['fileName']?.toString() ??
          'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startAnalysis(Map<String, dynamic> patient) async {
    if (_selectedCc == null && _selectedUs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one image to generate a report.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final File? ccFile  = _selectedCc  != null ? await _downloadToFile(_selectedCc!)  : null;
      final File? mloFile = _selectedMlo != null ? await _downloadToFile(_selectedMlo!) : null;
      final File? usFile  = _selectedUs  != null ? await _downloadToFile(_selectedUs!)  : null;

      if (!mounted) return;

      final Set<ImagingType> imagingTypes = {};
      if (ccFile  != null) imagingTypes.add(ImagingType.mammogram);
      if (mloFile != null) imagingTypes.add(ImagingType.mammogramMlo);
      if (usFile  != null) imagingTypes.add(ImagingType.ultrasound);

      final Map<ImagingType, File?> uploadedImages = {
        ImagingType.mammogram:    ccFile,
        ImagingType.mammogramMlo: mloFile,
        ImagingType.ultrasound:   usFile,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisLoadingScreen(
            selectedPatient: patient,
            uploadedImages: uploadedImages,
            selectedImagingTypes: imagingTypes,
            skipValidation: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load images: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8),
      appBar: ReusableTopBar(
        title: 'Generate Report',
        subtitle: Text(widget.patientName),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('patients')
            .doc(widget.patientId)
            .get(),
        builder: (context, patientSnap) {
          final patient = patientSnap.data?.exists == true
              ? {'id': patientSnap.data!.id, ...patientSnap.data!.data()!}
              : <String, dynamic>{};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('patient_images')
                .where('patientId', isEqualTo: widget.patientId)
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs
                      .map((d) => {'id': d.id, ...d.data()})
                      .toList() ??
                  [];

              final mammograms = docs
                  .where((d) => d['imageType'] == 'mammogram')
                  .toList();
              final ultrasounds = docs
                  .where((d) => d['imageType'] == 'ultrasound')
                  .toList();

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.image_search_rounded,
                              size: 56,
                              color: AppColors.primary.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No images available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Images are uploaded by the radiologist\nfrom the web portal. Once uploaded,\nyou can select them here to generate a report.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(
                                isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Images below are pre-validated by the radiologist. Select the scans you want to analyse.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mammogram CC
                        if (mammograms.isNotEmpty) ...[
                          _SelectionSectionHeader(
                            label: 'Mammogram (CC)',
                            icon: Icons.monitor_heart_outlined,
                            color: const Color(0xFFFF6F91),
                            selected: _selectedCc != null,
                            onClear: () => setState(() => _selectedCc = null),
                          ),
                          const SizedBox(height: 10),
                          _SelectionImageList(
                            docs: mammograms,
                            selected: _selectedCc,
                            accentColor: const Color(0xFFFF6F91),
                            onSelect: (doc) =>
                                setState(() => _selectedCc = doc),
                          ),
                          const SizedBox(height: 20),

                          // Mammogram MLO
                          _SelectionSectionHeader(
                            label: 'Mammogram (MLO)',
                            icon: Icons.flip_rounded,
                            color: const Color(0xFFFF9A3C),
                            selected: _selectedMlo != null,
                            onClear: () => setState(() => _selectedMlo = null),
                          ),
                          const SizedBox(height: 10),
                          _SelectionImageList(
                            docs: mammograms,
                            selected: _selectedMlo,
                            accentColor: const Color(0xFFFF9A3C),
                            onSelect: (doc) =>
                                setState(() => _selectedMlo = doc),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Ultrasound
                        if (ultrasounds.isNotEmpty) ...[
                          _SelectionSectionHeader(
                            label: 'Ultrasound',
                            icon: Icons.waves_rounded,
                            color: const Color(0xFF6C63FF),
                            selected: _selectedUs != null,
                            onClear: () => setState(() => _selectedUs = null),
                          ),
                          const SizedBox(height: 10),
                          _SelectionImageList(
                            docs: ultrasounds,
                            selected: _selectedUs,
                            accentColor: const Color(0xFF6C63FF),
                            onSelect: (doc) =>
                                setState(() => _selectedUs = doc),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Selection summary
                        if (_selectedCc != null ||
                            _selectedMlo != null ||
                            _selectedUs != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A1D2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isDark ? 0.2 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected for Analysis',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_selectedCc != null)
                                  _SelectedRow(
                                    label: 'Mammogram CC',
                                    color: const Color(0xFFFF6F91),
                                    date: _formatDate(
                                        _selectedCc!['uploadedAt']),
                                  ),
                                if (_selectedMlo != null)
                                  _SelectedRow(
                                    label: 'Mammogram MLO',
                                    color: const Color(0xFFFF9A3C),
                                    date: _formatDate(
                                        _selectedMlo!['uploadedAt']),
                                  ),
                                if (_selectedUs != null)
                                  _SelectedRow(
                                    label: 'Ultrasound',
                                    color: const Color(0xFF6C63FF),
                                    date: _formatDate(
                                        _selectedUs!['uploadedAt']),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  // Generate button
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1D2E)
                          : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(isDark ? 0.3 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: (_selectedCc != null || _selectedUs != null)
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6F91),
                                    Color(0xFF6C63FF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: (_selectedCc == null && _selectedUs == null)
                              ? AppColors.getBorder(context)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: (_selectedCc != null || _selectedUs != null)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF6F91)
                                        .withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: (_isLoading ||
                                    (_selectedCc == null &&
                                        _selectedUs == null))
                                ? null
                                : () => _startAnalysis(patient),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.psychology_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Generate AI Report',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SelectionSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onClear;
  const _SelectionSectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const Spacer(),
        if (selected)
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionImageList extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final Map<String, dynamic>? selected;
  final Color accentColor;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _SelectionImageList({
    required this.docs,
    required this.selected,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: docs.length,
        itemBuilder: (ctx, i) {
          final doc        = docs[i];
          final url        = doc['imageUrl']?.toString() ?? '';
          final ts         = doc['uploadedAt'];
          final score      = (doc['validationScore'] as num?)?.toInt() ?? 0;
          final label      = doc['scanLabel']?.toString() ?? '';
          final isSelected = selected?['id'] == doc['id'];

          String dateStr = '';
          if (ts is Timestamp) {
            final dt = ts.toDate();
            const m = ['Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'];
            dateStr = '${dt.day} ${m[dt.month - 1]}';
          }

          return GestureDetector(
            onTap: () => onSelect(doc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? accentColor : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? accentColor.withOpacity(0.3)
                        : Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: url.isNotEmpty
                              ? Image.network(url, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: accentColor.withOpacity(0.1),
                                    child: Icon(Icons.broken_image_rounded,
                                        color: accentColor, size: 28),
                                  ))
                              : Container(
                                  color: accentColor.withOpacity(0.1),
                                  child: Icon(Icons.image_outlined,
                                      color: accentColor, size: 28),
                                ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        if (score > 0)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '✓ $score%',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        if (label.isNotEmpty)
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
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
        },
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  final String label;
  final Color color;
  final String date;
  const _SelectedRow({
    required this.label,
    required this.color,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const Spacer(),
          Text(
            date,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.check_circle_rounded, color: color, size: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Index Error State
// ─────────────────────────────────────────────────────────────────────────────

class _IndexErrorState extends StatelessWidget {
  final String error;
  const _IndexErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final urlMatch = RegExp(r'https://console\.firebase\.google\.com\S+')
        .firstMatch(error);
    final indexUrl = urlMatch?.group(0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.build_circle_outlined,
                  color: Colors.orange, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Database Index Building',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A Firestore index is required. Run the command below, then wait a few minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1D2E)
                    : const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const SelectableText(
                'firebase deploy --only firestore:indexes',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (indexUrl != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                indexUrl,
                style: const TextStyle(fontSize: 10, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Compare Reports Button
// ─────────────────────────────────────────────────────────────────────────────
class _CompareReportsButton extends StatelessWidget {
  final String patientId;
  final String patientName;

  const _CompareReportsButton({
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectReportsScreen(
              patientId: patientId,
              patientName: patientName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compare Reports',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Track progress over time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
