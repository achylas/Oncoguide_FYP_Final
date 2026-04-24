import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/core/pages/history/report_detail_screen.dart';
import 'package:oncoguide_v2/core/widgets/resuable_top_bar.dart';

class PatientProfileScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const PatientProfileScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8),
      appBar: ReusableTopBar(
        title: widget.patientName,
        subtitle: const Text('Patient Profile'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('patients').doc(widget.patientId).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final patient = snap.data?.exists == true
              ? {'id': snap.data!.id, ...snap.data!.data()!}
              : <String, dynamic>{};

          return Column(
            children: [
              _PatientHeaderCard(patient: patient),
              Container(
                color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.getTextSecondary(context),
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Clinical Data'),
                    Tab(text: 'Mammogram'),
                    Tab(text: 'Ultrasound'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ClinicalDataTab(patient: patient),
                    _ReportsTab(patientId: widget.patientId, uid: _uid, collection: 'mammogram_reports', emptyLabel: 'No mammogram reports', icon: Icons.monitor_heart_outlined, color: const Color(0xFFFF6F91)),
                    _ReportsTab(patientId: widget.patientId, uid: _uid, collection: 'ultrasound_reports', emptyLabel: 'No ultrasound reports', icon: Icons.waves_rounded, color: const Color(0xFF6C63FF)),
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

// ── Patient Header ────────────────────────────────────────────────────────────
class _PatientHeaderCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientHeaderCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final name    = patient['name']?.toString() ?? 'Unknown';
    final age     = (patient['age'] as num?)?.toInt() ?? 0;
    final weight  = patient['weight']?.toString() ?? '—';
    final clinical = patient['clinicalAssessment'] as Map<String, dynamic>? ?? {};
    final imc     = clinical['imc']?.toString() ?? patient['imc']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.getPrimaryGradient(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text('$age yrs  •  ${weight}kg  •  BMI $imc', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clinical Data Tab ─────────────────────────────────────────────────────────
class _ClinicalDataTab extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _ClinicalDataTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    if (patient.isEmpty) return const Center(child: Text('No clinical data available'));

    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final repro    = patient['reproductive'] as Map<String, dynamic>? ?? {};
    final clinical = patient['clinicalAssessment'] as Map<String, dynamic>? ?? {};

    final sections = [
      {
        'title': 'Demographics',
        'icon': Icons.person_outline_rounded,
        'color': const Color(0xFF6366F1),
        'fields': <String, String>{
          'Name'  : patient['name']?.toString() ?? '—',
          'Age'   : '${patient['age'] ?? '—'} years',
          'Weight': '${patient['weight'] ?? '—'} kg',
          'BMI'   : clinical['imc']?.toString() ?? patient['imc']?.toString() ?? '—',
        },
      },
      {
        'title': 'Reproductive History',
        'icon': Icons.favorite_outline_rounded,
        'color': const Color(0xFFFF6F91),
        'fields': <String, String>{
          'Age at Menarche'     : repro['menarche']?.toString() ?? '—',
          'Menopause Age'       : repro['menopauseAge']?.toString() ?? '—',
          'Menopause Status'    : repro['menopauseStatus'] == 1 ? 'Yes' : 'No',
          'Pregnancy'           : repro['pregnancy'] == 1 ? 'Yes' : 'No',
          'Age at 1st Pregnancy': repro['ageFirstPregnancy']?.toString() ?? '—',
          'No. of Children'     : repro['numberOfChildren']?.toString() ?? '—',
          'Breastfeeding'       : repro['breastfeeding'] == 1 ? 'Yes' : 'No',
        },
      },
      {
        'title': 'Family & Lifestyle',
        'icon': Icons.groups_outlined,
        'color': const Color(0xFF10B981),
        'fields': <String, String>{
          'Family History'       : patient['familyHistory'] == 1 ? 'Yes' : 'No',
          'Family History Count' : patient['familyHistoryCount']?.toString() ?? '—',
          'Family History Degree': patient['familyHistoryDegree']?.toString() ?? '—',
          'Regular Exercise'     : patient['exerciseRegular'] == 1 ? 'Yes' : 'No',
        },
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: sections.map((section) {
        final fields = section['fields'] as Map<String, String>;
        final color  = section['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                      child: Icon(section['icon'] as IconData, color: color, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Text(section['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.getTextPrimary(context))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...fields.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)),
                    Text(e.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context))),
                  ],
                ),
              )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Reports Tab ───────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  final String patientId;
  final String uid;
  final String collection;
  final String emptyLabel;
  final IconData icon;
  final Color color;

  const _ReportsTab({
    required this.patientId,
    required this.uid,
    required this.collection,
    required this.emptyLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
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
                Icon(icon, size: 48, color: color.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(emptyLabel, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = {'id': docs[i].id, 'type': collection == 'mammogram_reports' ? 'mammogram' : 'ultrasound', ...docs[i].data()};
            return _ReportCard(data: data, color: color, icon: icon);
          },
        );
      },
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  final IconData icon;
  const _ReportCard({required this.data, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final riskLabel   = data['riskLabel']?.toString() ?? '';
    final riskPct     = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final prediction  = data['prediction']?.toString();
    final imageUrl    = data['mammogramUrl']?.toString() ?? data['ultrasoundUrl']?.toString();
    final isHighRisk  = riskLabel == 'High Risk';
    final isMalignant = prediction == 'Malignant';
    final badgeColor  = isMalignant ? const Color(0xFFEF4444) : isHighRisk ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final badgeText   = isMalignant ? 'Malignant' : isHighRisk ? 'High Risk' : prediction ?? riskLabel;

    String dateStr = '';
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailScreen(reportData: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 80, height: 80,
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
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
                        Icon(icon, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(data['type'] == 'mammogram' ? 'Mammogram Report' : 'Ultrasound Report',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        const Spacer(),
                        Text(dateStr, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (badgeText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withOpacity(0.4)),
                        ),
                        child: Text(badgeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
                      ),
                    if (riskPct > 0) ...[
                      const SizedBox(height: 4),
                      Text('Risk: ${riskPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: color.withOpacity(0.1),
    child: Center(child: Icon(icon, color: color, size: 28)),
  );
}
