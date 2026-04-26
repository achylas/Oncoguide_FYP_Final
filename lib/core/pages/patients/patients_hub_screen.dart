import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/core/pages/patients/patient_profile_screen.dart';
import 'package:oncoguide_v2/core/widgets/resuable_top_bar.dart';

class PatientsHubScreen extends StatefulWidget {
  const PatientsHubScreen({super.key});

  @override
  State<PatientsHubScreen> createState() => _PatientsHubScreenState();
}

class _PatientsHubScreenState extends State<PatientsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

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
        title: 'Patients',
        subtitle: const Text('All patient records'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Search patients by name...',
                  hintStyle: TextStyle(
                    color: AppColors.getTextSecondary(context).withOpacity(0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: AppColors.getTextSecondary(context), size: 18),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Stats row ───────────────────────────────────────────────────
          _StatsRow(uid: _uid),
          const SizedBox(height: 4),

          // ── Tab bar ─────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.getTextSecondary(context),
              indicator: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(context),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'All Patients'),
                Tab(text: 'Cancer'),
                Tab(text: 'Normal'),
              ],
            ),
          ),

          // ── Tab views ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllPatientsTab(search: _search),
                _CancerPatientsTab(uid: _uid, search: _search),
                _NormalPatientsTab(uid: _uid, search: _search),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').snapshots(),
      builder: (context, allSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cancer_patients')
              .where('flaggedBy', isEqualTo: uid)
              .snapshots(),
          builder: (context, cancerSnap) {
            final total  = allSnap.data?.docs.length ?? 0;
            final cancer = cancerSnap.data?.docs.length ?? 0;
            final normal = total - cancer;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatChip('$total',  'Total',  const Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  _StatChip('$cancer', 'Cancer', const Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  _StatChip('$normal', 'Normal', const Color(0xFF10B981)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatChip(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — All Patients
// ─────────────────────────────────────────────────────────────────────────────
class _AllPatientsTab extends StatelessWidget {
  final String search;
  const _AllPatientsTab({required this.search});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((d) {
          final name = d.data()['name']?.toString().toLowerCase() ?? '';
          return search.isEmpty || name.contains(search);
        }).toList();

        if (filtered.isEmpty) return _empty(context, 'No patients found');

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final data = {'id': filtered[i].id, ...filtered[i].data()};
            return _PatientCard(
              data: data,
              fallbackBadgeColor: const Color(0xFF6366F1),
              fallbackBadgeLabel: 'Patient',
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Cancer Patients
// ─────────────────────────────────────────────────────────────────────────────
class _CancerPatientsTab extends StatelessWidget {
  final String uid;
  final String search;
  const _CancerPatientsTab({required this.uid, required this.search});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cancer_patients')
          .where('flaggedBy', isEqualTo: uid)
          .orderBy('flaggedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((d) {
          final name = d.data()['patientName']?.toString().toLowerCase() ?? '';
          return search.isEmpty || name.contains(search);
        }).toList();

        if (filtered.isEmpty) return _empty(context, 'No cancer patients flagged');

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final data = {'id': filtered[i].id, ...filtered[i].data()};
            return _PatientCard(
              data: data,
              fallbackBadgeColor: const Color(0xFFEF4444),
              fallbackBadgeLabel: 'Malignant',
              isCancerRecord: true,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Normal Patients
// ─────────────────────────────────────────────────────────────────────────────
class _NormalPatientsTab extends StatelessWidget {
  final String uid;
  final String search;
  const _NormalPatientsTab({required this.uid, required this.search});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cancer_patients')
          .where('flaggedBy', isEqualTo: uid)
          .snapshots(),
      builder: (context, cancerSnap) {
        final cancerIds = (cancerSnap.data?.docs ?? [])
            .map((d) => d.data()['patientId']?.toString() ?? d.id)
            .toSet();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('patients')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, allSnap) {
            if (allSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = allSnap.data?.docs ?? [];
            final filtered = docs.where((d) {
              final isCancer = cancerIds.contains(d.id);
              final name = d.data()['name']?.toString().toLowerCase() ?? '';
              return !isCancer && (search.isEmpty || name.contains(search));
            }).toList();

            if (filtered.isEmpty) return _empty(context, 'No normal patients');

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final data = {'id': filtered[i].id, ...filtered[i].data()};
                return _PatientCard(
                  data: data,
                  fallbackBadgeColor: const Color(0xFF10B981),
                  fallbackBadgeLabel: 'Normal',
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Card — shows latest report status badge fetched live
// ─────────────────────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color fallbackBadgeColor;
  final String fallbackBadgeLabel;
  final bool isCancerRecord;

  const _PatientCard({
    required this.data,
    required this.fallbackBadgeColor,
    required this.fallbackBadgeLabel,
    this.isCancerRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final name      = (data['name'] ?? data['patientName'] ?? 'Unknown').toString();
    final age       = ((data['age'] ?? data['patientAge'] ?? 0) as num).toInt();
    final id        = data['id']?.toString() ?? '';
    final patientId = isCancerRecord
        ? (data['patientId']?.toString() ?? id)
        : id;

    String dateStr = '';
    final ts = data['createdAt'] ?? data['flaggedAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    // Cancer records already have a definitive badge — no need to fetch
    if (isCancerRecord) {
      return _CardBody(
        name: name, age: age, dateStr: dateStr,
        patientId: patientId,
        badgeLabel: fallbackBadgeLabel,
        badgeColor: fallbackBadgeColor,
      );
    }

    // For regular patients: fetch latest report to show real status
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
            // Determine which report is more recent
            final mammoDoc = mammoSnap.data?.docs.firstOrNull;
            final usDoc    = usSnap.data?.docs.firstOrNull;

            Map<String, dynamic>? latest;
            Timestamp? latestTs;

            if (mammoDoc != null) {
              final t = mammoDoc.data()['createdAt'];
              if (t is Timestamp) latestTs = t;
              latest = mammoDoc.data();
            }
            if (usDoc != null) {
              final t = usDoc.data()['createdAt'];
              if (t is Timestamp &&
                  (latestTs == null || t.compareTo(latestTs) > 0)) {
                latest = usDoc.data();
              }
            }

            // Derive badge from latest report
            String label = fallbackBadgeLabel;
            Color  color = fallbackBadgeColor;

            if (latest != null) {
              final usPred  = latest['usPrediction']?.toString()
                  ?? latest['prediction']?.toString();
              final riskLbl = latest['riskLabel']?.toString();

              if (usPred == 'Malignant') {
                label = 'Malignant'; color = const Color(0xFFEF4444);
              } else if (usPred == 'Benign') {
                label = 'Benign';    color = const Color(0xFFF59E0B);
              } else if (usPred == 'Normal') {
                label = 'Normal';    color = const Color(0xFF10B981);
              } else if (riskLbl == 'High Risk') {
                label = 'High Risk'; color = const Color(0xFFEF4444);
              } else if (riskLbl != null && riskLbl.isNotEmpty) {
                label = riskLbl;     color = const Color(0xFF10B981);
              } else {
                label = 'Scanned';   color = const Color(0xFF6366F1);
              }
            }

            return _CardBody(
              name: name, age: age, dateStr: dateStr,
              patientId: patientId,
              badgeLabel: label,
              badgeColor: color,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card body — pure UI, no data fetching
// ─────────────────────────────────────────────────────────────────────────────
class _CardBody extends StatelessWidget {
  final String name;
  final int    age;
  final String dateStr;
  final String patientId;
  final String badgeLabel;
  final Color  badgeColor;

  const _CardBody({
    required this.name,
    required this.age,
    required this.dateStr,
    required this.patientId,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientProfileScreen(
            patientId: patientId,
            patientName: name,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [badgeColor, badgeColor.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (age > 0) ...[
                        Icon(Icons.cake_outlined,
                            size: 12,
                            color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 3),
                        Text('$age yrs',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextSecondary(context))),
                        const SizedBox(width: 10),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 3),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextSecondary(context))),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.getTextSecondary(context), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
Widget _empty(BuildContext context, String label) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_search_rounded,
            size: 56,
            color: AppColors.getTextSecondary(context).withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
              fontSize: 15,
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
