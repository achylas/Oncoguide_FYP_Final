import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/core/pages/history/report_detail_screen.dart';
import 'package:oncoguide_v2/services/report_service.dart';
import '../../widgets/resuable_top_bar.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    _TabDef('All',        Icons.list_alt_rounded,       null),
    _TabDef('High Risk',  Icons.warning_rounded,         Color(0xFFEF4444)),
    _TabDef('Cancer',     Icons.coronavirus_rounded,     Color(0xFFDC2626)),
    _TabDef('Mammogram',  Icons.monitor_heart_outlined,  Color(0xFFFF6F91)),
    _TabDef('Ultrasound', Icons.waves_rounded,           Color(0xFF6C63FF)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
        title: 'Scan History',
        subtitle: const Text('All analysis reports'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.getTextSecondary(context),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: _tabs.map((t) => Tab(
                child: Row(
                  children: [
                    Icon(t.icon, size: 16, color: t.color),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ],
                ),
              )).toList(),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All — shows both mammogram + ultrasound reports
                _AllReportsTab(),
                // High Risk
                _StreamTab(
                  stream: ReportService.riskPatientsStream(),
                  emptyLabel: 'No high risk patients',
                  emptyIcon: Icons.warning_rounded,
                  cardType: _CardType.riskPatient,
                ),
                // Cancer (Malignant)
                _StreamTab(
                  stream: ReportService.cancerPatientsStream(),
                  emptyLabel: 'No cancer patients flagged',
                  emptyIcon: Icons.coronavirus_rounded,
                  cardType: _CardType.cancerPatient,
                ),
                // Mammogram reports
                _StreamTab(
                  stream: ReportService.mammogramReportsStream(),
                  emptyLabel: 'No mammogram reports',
                  emptyIcon: Icons.monitor_heart_outlined,
                  cardType: _CardType.mammogramReport,
                ),
                // Ultrasound reports
                _StreamTab(
                  stream: ReportService.ultrasoundReportsStream(),
                  emptyLabel: 'No ultrasound reports',
                  emptyIcon: Icons.waves_rounded,
                  cardType: _CardType.ultrasoundReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Reports Tab — merges mammogram + ultrasound streams
// ─────────────────────────────────────────────────────────────────────────────
class _AllReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ReportService.mammogramReportsStream(),
      builder: (context, mammoSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ReportService.ultrasoundReportsStream(),
          builder: (context, usSnap) {
            if (mammoSnap.connectionState == ConnectionState.waiting ||
                usSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (mammoSnap.hasError || usSnap.hasError) {
              return _indexErrorState(context, (mammoSnap.error ?? usSnap.error).toString());
            }

            final mammoDocs = mammoSnap.data?.docs ?? [];
            final usDocs    = usSnap.data?.docs ?? [];

            // Merge and sort by createdAt descending
            final all = [
              ...mammoDocs.map((d) => {'id': d.id, 'type': 'mammogram', ...d.data()}),
              ...usDocs.map((d) => {'id': d.id, 'type': 'ultrasound', ...d.data()}),
            ];

            all.sort((a, b) {
              final ta = a['createdAt'];
              final tb = b['createdAt'];
              if (ta is Timestamp && tb is Timestamp) {
                return tb.compareTo(ta);
              }
              return 0;
            });

            if (all.isEmpty) {
              return _emptyState(context, 'No reports yet', Icons.history_rounded);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: all.length,
              itemBuilder: (ctx, i) => _ReportCard(
                data: all[i],
                cardType: all[i]['type'] == 'mammogram'
                    ? _CardType.mammogramReport
                    : _CardType.ultrasoundReport,
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic stream tab
// ─────────────────────────────────────────────────────────────────────────────
class _StreamTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyLabel;
  final IconData emptyIcon;
  final _CardType cardType;

  const _StreamTab({
    required this.stream,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.cardType,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _indexErrorState(context, snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(context, emptyLabel, emptyIcon);
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _ReportCard(
            data: {'id': docs[i].id, ...docs[i].data()},
            cardType: cardType,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Card
// ─────────────────────────────────────────────────────────────────────────────
enum _CardType { mammogramReport, ultrasoundReport, riskPatient, cancerPatient }

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final _CardType cardType;
  const _ReportCard({required this.data, required this.cardType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final patientName   = data['patientName']?.toString() ?? 'Unknown';
    final riskLabel     = data['riskLabel']?.toString() ?? '';
    final riskPct       = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final usPrediction  = data['usPrediction']?.toString() ?? data['prediction']?.toString();
    final mammogramUrl  = data['mammogramUrl']?.toString();
    final ultrasoundUrl = data['ultrasoundUrl']?.toString();
    final gradcamUrl    = data['gradcamUrl']?.toString();
    final isHighRisk    = riskLabel == 'High Risk';
    final isMalignant   = usPrediction == 'Malignant';

    // Badge color
    Color badgeColor;
    String badgeText;
    if (cardType == _CardType.cancerPatient || isMalignant) {
      badgeColor = const Color(0xFFDC2626);
      badgeText  = 'Malignant';
    } else if (cardType == _CardType.riskPatient || isHighRisk) {
      badgeColor = const Color(0xFFEF4444);
      badgeText  = 'High Risk';
    } else if (usPrediction == 'Benign') {
      badgeColor = const Color(0xFFF59E0B);
      badgeText  = 'Benign';
    } else if (usPrediction == 'Normal') {
      badgeColor = const Color(0xFF10B981);
      badgeText  = 'Normal';
    } else {
      badgeColor = const Color(0xFF10B981);
      badgeText  = 'Low Risk';
    }

    // Type icon
    IconData typeIcon;
    Color typeColor;
    switch (cardType) {
      case _CardType.mammogramReport:
        typeIcon = Icons.monitor_heart_outlined; typeColor = const Color(0xFFFF6F91);
        break;
      case _CardType.ultrasoundReport:
        typeIcon = Icons.waves_rounded; typeColor = const Color(0xFF6C63FF);
        break;
      case _CardType.cancerPatient:
        typeIcon = Icons.coronavirus_rounded; typeColor = const Color(0xFFDC2626);
        break;
      case _CardType.riskPatient:
        typeIcon = Icons.warning_rounded; typeColor = const Color(0xFFEF4444);
        break;
    }

    // Date
    String dateStr = '';
    final ts = data['createdAt'] ?? data['flaggedAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    // Thumbnail URL
    final thumbUrl = mammogramUrl ?? ultrasoundUrl ?? gradcamUrl;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(reportData: data),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: thumbUrl != null
                    ? Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(typeColor, typeIcon),
                      )
                    : _thumbPlaceholder(typeColor, typeIcon),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(typeIcon, size: 13, color: typeColor),
                        const SizedBox(width: 4),
                        Text(
                          cardType == _CardType.mammogramReport ? 'Mammogram'
                              : cardType == _CardType.ultrasoundReport ? 'Ultrasound'
                              : cardType == _CardType.cancerPatient ? 'Cancer Patient'
                              : 'High Risk Patient',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor),
                        ),
                        const Spacer(),
                        if (dateStr.isNotEmpty)
                          Text(dateStr, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      patientName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                          ),
                        ),
                        if (riskPct > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${riskPct.toStringAsFixed(0)}% risk',
                            style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(Color color, IconData icon) {
    return Container(
      color: color.withOpacity(0.1),
      child: Center(child: Icon(icon, color: color, size: 32)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _emptyState(BuildContext context, String label, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: AppColors.accent),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    ),
  );
}

class _TabDef {
  final String label;
  final IconData icon;
  final Color? color;
  const _TabDef(this.label, this.icon, this.color);
}

Widget _indexErrorState(BuildContext context, String error) {
  final urlMatch = RegExp(r'https://console\.firebase\.google\.com\S+').firstMatch(error);
  final indexUrl = urlMatch?.group(0);
  final isDark   = Theme.of(context).brightness == Brightness.dark;

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
            child: const Icon(Icons.build_circle_outlined, color: Colors.orange, size: 40),
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
            'A Firestore index is required. Run the command below in the oncoguide_v2 folder, then wait a few minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.getTextSecondary(context)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D2E) : const Color(0xFFF0F2F8),
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
