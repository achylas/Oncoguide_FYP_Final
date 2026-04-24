import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/history/scan_history/scan_view_page.dart';

import '../../../utils/common_app_bar.dart';
import '../../../conts/colors.dart';
import '../../new_analysis/screens/new_analysis_screen.dart';

class ScanHistoryPage extends StatefulWidget {
  final String patientId;

  const ScanHistoryPage({
    super.key,
    required this.patientId,
  });

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ScanRecord> _scans = [
    ScanRecord(
      id: '001',
      patientName: 'Sarah Johnson',
      scanDate: DateTime(2026, 1, 14),
      scanType: 'Mammogram ',
      diagnosis: 'Malignant Tumor Detected',
      stage: 'Stage II',
      severity: ScanSeverity.high,
      confidence: 92.4,
      status: ScanStatus.completed,
      imageCount: 2,
    ),
    ScanRecord(
      id: '002',
      patientName: 'Sarah Johnson',
      scanDate: DateTime(2026, 1, 8),
      scanType: 'Mammogram',
      diagnosis: 'Suspicious Mass',
      stage: 'Requires Further Testing',
      severity: ScanSeverity.medium,
      confidence: 78.5,
      status: ScanStatus.completed,
      imageCount: 1,
    ),
    ScanRecord(
      id: '003',
      patientName: 'Sarah Johnson',
      scanDate: DateTime(2025, 12, 20),
      scanType: 'Ultrasound',
      diagnosis: 'Benign Cyst Detected',
      stage: 'Non-cancerous',
      severity: ScanSeverity.low,
      confidence: 95.2,
      status: ScanStatus.completed,
      imageCount: 1,
    ),
    ScanRecord(
      id: '004',
      patientName: 'Sarah Johnson',
      scanDate: DateTime(2025, 12, 5),
      scanType: 'Mammogram',
      diagnosis: 'No Abnormalities',
      stage: 'Clear',
      severity: ScanSeverity.none,
      confidence: 98.1,
      status: ScanStatus.completed,
      imageCount: 1,
    ),
  ];

  List<ScanRecord> get _filteredScans {
    List<ScanRecord> filtered = _scans;

    if (_selectedFilter != 'All') {
      filtered = filtered.where((scan) {
        switch (_selectedFilter) {
          case 'High Risk':
            return scan.severity == ScanSeverity.high;
          case 'Medium Risk':
            return scan.severity == ScanSeverity.medium;
          case 'Low Risk':
            return scan.severity == ScanSeverity.low;
          case 'Clear':
            return scan.severity == ScanSeverity.none;
          default:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((scan) {
        return scan.diagnosis.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            scan.scanType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            scan.stage.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredScans = _filteredScans;

    return Scaffold(
      appBar: const CommonTopBar(title: 'Scan History'),
      backgroundColor: AppColors.getBackground(context),
      body: Column(
        children: [
          // Header Section
          Container(
            color: AppColors.getCardBackground(context),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Scans',
                        value: '${_scans.length}',
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'High Risk',
                        value: '${_scans.where((s) => s.severity == ScanSeverity.high).length}',
                        icon: Icons.warning_rounded,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Clear',
                        value: '${_scans.where((s) => s.severity == ScanSeverity.none).length}',
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark
                        ? Border.all(color: AppColors.borderDark)
                        : Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: TextStyle(color: AppColors.getTextPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Search scans by diagnosis, type...',
                      hintStyle: TextStyle(
                        color: AppColors.getTextSecondary(context),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.getTextSecondary(context),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppColors.getTextSecondary(context),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            color: AppColors.getCardBackground(context),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  _buildFilterChip('High Risk'),
                  _buildFilterChip('Medium Risk'),
                  _buildFilterChip('Low Risk'),
                  _buildFilterChip('Clear'),
                ],
              ),
            ),
          ),

          // Scan List
          Expanded(
            child: filteredScans.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredScans.length,
              itemBuilder: (context, index) {
                return _buildScanCard(filteredScans[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewAnalysisScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add),
        label: const Text(
          'New Scan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : Colors.grey[100],
        selectedColor: const Color(0xFF6366F1).withOpacity(isDark ? 0.25 : 0.15),
        checkmarkColor: const Color(0xFF6366F1),
        labelStyle: TextStyle(
          color: isSelected
              ? const Color(0xFF6366F1)
              : AppColors.getTextSecondary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : AppColors.getBorder(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildScanCard(ScanRecord scan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getSeverityColor(scan.severity).withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showScanDetails(scan);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(scan.severity).withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSeverityIcon(scan.severity),
                        color: _getSeverityColor(scan.severity),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatDate(scan.scanDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${scan.id}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.getTextSecondary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scan.diagnosis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getTextPrimary(context),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scan.stage,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(scan.status),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.getDivider(context)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMetaChip(
                      icon: Icons.camera_alt_outlined,
                      label: scan.scanType,
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 8),
                    if (scan.status == ScanStatus.completed) ...[
                      _buildMetaChip(
                        icon: Icons.analytics_outlined,
                        label: '${scan.confidence.toStringAsFixed(1)}%',
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _buildMetaChip(
                        icon: Icons.image_outlined,
                        label: '${scan.imageCount} images',
                        color: const Color(0xFF0EA5E9),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ScanStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case ScanStatus.completed:
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF059669);
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case ScanStatus.processing:
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Processing';
        icon = Icons.hourglass_empty;
        break;
      case ScanStatus.pending:
        backgroundColor = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF4F46E5);
        label = 'Pending';
        icon = Icons.pending;
        break;
      case ScanStatus.failed:
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'Failed';
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_outlined,
              size: 64,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'No scans found' : 'No scan history yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Start by creating a new scan analysis',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(ScanSeverity severity) {
    switch (severity) {
      case ScanSeverity.high:
        return const Color(0xFFEF4444);
      case ScanSeverity.medium:
        return const Color(0xFFF59E0B);
      case ScanSeverity.low:
        return const Color(0xFF3B82F6);
      case ScanSeverity.none:
        return const Color(0xFF10B981);
    }
  }

  IconData _getSeverityIcon(ScanSeverity severity) {
    switch (severity) {
      case ScanSeverity.high:
        return Icons.warning_rounded;
      case ScanSeverity.medium:
        return Icons.info_rounded;
      case ScanSeverity.low:
        return Icons.check_circle_outline;
      case ScanSeverity.none:
        return Icons.verified_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showScanDetails(ScanRecord scan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedScanViewPage(scanId: scan.id),
      ),
    );
  }
}

// Data Models
class ScanRecord {
  final String id;
  final String patientName;
  final DateTime scanDate;
  final String scanType;
  final String diagnosis;
  final String stage;
  final ScanSeverity severity;
  final double confidence;
  final ScanStatus status;
  final int imageCount;

  ScanRecord({
    required this.id,
    required this.patientName,
    required this.scanDate,
    required this.scanType,
    required this.diagnosis,
    required this.stage,
    required this.severity,
    required this.confidence,
    required this.status,
    required this.imageCount,
  });
}

enum ScanSeverity { none, low, medium, high }
enum ScanStatus { completed, processing, pending, failed }