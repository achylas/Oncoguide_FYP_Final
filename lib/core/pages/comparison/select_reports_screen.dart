import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/report_service.dart';
import 'report_comparison_screen.dart';
import '../../widgets/resuable_top_bar.dart';

/// Screen for selecting 2 reports to compare
class SelectReportsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const SelectReportsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<SelectReportsScreen> createState() => _SelectReportsScreenState();
}

class _SelectReportsScreenState extends State<SelectReportsScreen> {
  Map<String, dynamic>? _selectedReport1;
  Map<String, dynamic>? _selectedReport2;
  String _selectedType = 'mammogram'; // mammogram or ultrasound

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: 'Select Reports to Compare',
        subtitle: Text(widget.patientName),
        showBackButton: true,
        showSettingsButton: false,
      ),
      floatingActionButton: _selectedReport1 != null && _selectedReport2 != null
          ? FloatingActionButton.extended(
              onPressed: _compareReports,
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
              label: const Text(
                'Compare',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: Column(
        children: [
          // ── Type Selector ─────────────────────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Mammogram',
                    icon: Icons.monitor_heart_outlined,
                    isSelected: _selectedType == 'mammogram',
                    onTap: () => setState(() {
                      _selectedType = 'mammogram';
                      _selectedReport1 = null;
                      _selectedReport2 = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    label: 'Ultrasound',
                    icon: Icons.waves_rounded,
                    isSelected: _selectedType == 'ultrasound',
                    onTap: () => setState(() {
                      _selectedType = 'ultrasound';
                      _selectedReport1 = null;
                      _selectedReport2 = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ── Selection Status ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _SelectionBox(
                    label: 'Report 1 (Older)',
                    selected: _selectedReport1 != null,
                    date: _selectedReport1 != null
                        ? _formatDate(_selectedReport1!['createdAt'])
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.compare_arrows_rounded, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Expanded(
                  child: _SelectionBox(
                    label: 'Report 2 (Newer)',
                    selected: _selectedReport2 != null,
                    date: _selectedReport2 != null
                        ? _formatDate(_selectedReport2!['createdAt'])
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // ── Reports List ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _selectedType == 'mammogram'
                  ? ReportService.mammogramReportsStream()
                  : ReportService.ultrasoundReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                // Filter by patient ID
                final patientDocs = allDocs
                    .where((doc) => doc.data()['patientId'] == widget.patientId)
                    .toList();

                if (patientDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedType == 'mammogram'
                              ? Icons.monitor_heart_outlined
                              : Icons.waves_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedType} reports found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (patientDocs.length < 2) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          'Need at least 2 reports to compare',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Found ${patientDocs.length} report(s)',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: patientDocs.length,
                  itemBuilder: (ctx, i) {
                    final doc = patientDocs[i];
                    final data = {'id': doc.id, ...doc.data()};
                    final isSelected1 = _selectedReport1?['id'] == doc.id;
                    final isSelected2 = _selectedReport2?['id'] == doc.id;
                    final isSelected = isSelected1 || isSelected2;

                    return _ReportCard(
                      data: data,
                      isSelected: isSelected,
                      selectionNumber: isSelected1 ? 1 : (isSelected2 ? 2 : null),
                      onTap: () => _selectReport(data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectReport(Map<String, dynamic> report) {
    setState(() {
      // If already selected, deselect
      if (_selectedReport1?['id'] == report['id']) {
        _selectedReport1 = null;
        return;
      }
      if (_selectedReport2?['id'] == report['id']) {
        _selectedReport2 = null;
        return;
      }

      // Select in order
      if (_selectedReport1 == null) {
        _selectedReport1 = report;
      } else if (_selectedReport2 == null) {
        _selectedReport2 = report;
      } else {
        // Both selected, replace the first one
        _selectedReport1 = report;
        _selectedReport2 = null;
      }
    });
  }

  void _compareReports() {
    if (_selectedReport1 == null || _selectedReport2 == null) return;

    // Ensure older report is first
    final date1 = (_selectedReport1!['createdAt'] as Timestamp).toDate();
    final date2 = (_selectedReport2!['createdAt'] as Timestamp).toDate();

    final older = date1.isBefore(date2) ? _selectedReport1! : _selectedReport2!;
    final newer = date1.isBefore(date2) ? _selectedReport2! : _selectedReport1!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportComparisonScreen(
          olderReport: older,
          newerReport: newer,
          patientName: widget.patientName,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return 'Unknown';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type Button
// ─────────────────────────────────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection Box
// ─────────────────────────────────────────────────────────────────────────────
class _SelectionBox extends StatelessWidget {
  final String label;
  final bool selected;
  final String? date;

  const _SelectionBox({
    required this.label,
    required this.selected,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF6366F1).withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF6366F1) : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF6366F1) : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date ?? 'Not selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF6366F1) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Card
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelected;
  final int? selectionNumber;
  final VoidCallback onTap;

  const _ReportCard({
    required this.data,
    required this.isSelected,
    required this.selectionNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = _formatDate(data['createdAt']);
    final riskPct = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final riskLabel = data['riskLabel']?.toString() ?? '';
    final prediction = data['prediction']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 3,
          ),
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
            // Selection indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSelected
                    ? Text(
                        '$selectionNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.circle_outlined, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 16),

            // Report info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (riskLabel.isNotEmpty)
                    Text(
                      '$riskLabel (${riskPct.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  if (prediction.isNotEmpty)
                    Text(
                      prediction,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return 'Unknown';
  }
}
