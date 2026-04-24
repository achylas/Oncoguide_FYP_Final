import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// DETAILED SCAN VIEW - Opens when clicking on a scan from history
// ═══════════════════════════════════════════════════════════════
class DetailedScanViewPage extends StatefulWidget {
  final String scanId;

  const DetailedScanViewPage({
    super.key,
    required this.scanId,
  });

  @override
  State<DetailedScanViewPage> createState() => _DetailedScanViewPageState();
}

class _DetailedScanViewPageState extends State<DetailedScanViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data - Replace with actual API call
  final ScanDetailData _scanData = ScanDetailData(
    id: '001',
    scanDate: DateTime(2026, 1, 14, 10, 30),
    analysisDate: DateTime(2026, 1, 14, 10, 35),
    patientName: 'Sarah Johnson',
    patientAge: 52,
    patientId: 'PT-2024-001',
    scanType: 'Mammogram + Ultrasound',
    diagnosis: 'Malignant Tumor Detected',
    stage: 'Stage II (Localized)',
    severity: 'High Risk',
    tnmClassification: 'T2  N1  M0',
    tumorSize: '2.8 cm',
    lymphNodes: '1–3 nodes involved',
    confidence: 92.4,
    riskScore: 78,
    clinicalFindings: 'AI analysis indicates irregular mass density with '
        'spiculated margins, a hallmark feature of malignant breast lesions. '
        'The staging suggests localized disease with limited lymph node '
        'involvement and no distant metastasis detected.',
    aiModel: 'OncologyNet v4.2',
    processingTime: '4.8 seconds',
    imageUrls: [
      'mammogram_1.jpg',
      'ultrasound_1.jpg',
    ],
    recommendations: [
      'Immediate biopsy confirmation is advised',
      'Refer to oncology specialist within 7 days',
      'Contrast-enhanced MRI recommended for staging',
      'Discuss findings in multidisciplinary tumor board',
    ],
    previousScans: [
      PreviousScanSummary(
        date: DateTime(2026, 1, 8),
        diagnosis: 'Suspicious Mass',
        severity: 'Medium Risk',
      ),
      PreviousScanSummary(
        date: DateTime(2025, 12, 20),
        diagnosis: 'Benign Cyst Detected',
        severity: 'Low Risk',
      ),
    ],
    annotations: [
      'Mass located at 2 o\'clock position, 4cm from nipple',
      'Irregular borders with speculation noted',
      'Architectural distortion present',
    ],
    radiologistNotes: '',
    status: 'Completed',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan #${widget.scanId}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              // Download report functionality
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Print Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'compare',
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows, size: 20),
                    SizedBox(width: 12),
                    Text('Compare Scans'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════
          // QUICK INFO BANNER
          // ═══════════════════════════════════════════════════════
          _buildQuickInfoBanner(),

          // ═══════════════════════════════════════════════════════
          // TAB BAR
          // ═══════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Images'),
                Tab(text: 'History'),
                Tab(text: 'Notes'),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════════
          // TAB VIEWS
          // ═══════════════════════════════════════════════════════
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildImagesTab(),
                _buildHistoryTab(),
                _buildNotesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUICK INFO BANNER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuickInfoBanner() {
    return Container(
      color: const Color(0xFFEF4444),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanData.diagnosis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_scanData.stage} • Confidence: ${_scanData.confidence}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _scanData.severity,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Info Card
          _buildSectionCard(
            title: 'Patient Information',
            icon: Icons.person_outline,
            iconColor: const Color(0xFF6366F1),
            child: Column(
              children: [
                _buildInfoRow(
                  label: 'Name',
                  value: _scanData.patientName,
                  icon: Icons.badge_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Patient ID',
                  value: _scanData.patientId,
                  icon: Icons.fingerprint,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Age',
                  value: '${_scanData.patientAge} years',
                  icon: Icons.cake_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Scan Date',
                  value: _formatDateTime(_scanData.scanDate),
                  icon: Icons.calendar_today_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clinical Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Risk Score',
                  value: '${_scanData.riskScore}%',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Confidence',
                  value: '${_scanData.confidence}%',
                  icon: Icons.analytics_outlined,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tumor Characteristics
          _buildSectionCard(
            title: 'Tumor Characteristics',
            icon: Icons.biotech_rounded,
            iconColor: const Color(0xFF8B5CF6),
            child: Column(
              children: [
                _buildInfoRow(
                  label: 'TNM Classification',
                  value: _scanData.tnmClassification,
                  icon: Icons.grid_on_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Tumor Size',
                  value: _scanData.tumorSize,
                  icon: Icons.straighten_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Lymph Nodes',
                  value: _scanData.lymphNodes,
                  icon: Icons.blur_circular_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clinical Findings
          _buildSectionCard(
            title: 'Clinical Findings',
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF0EA5E9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanData.clinicalFindings,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey[700],
                  ),
                ),
                if (_scanData.annotations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Key Annotations:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_scanData.annotations.map(
                    (annotation) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              annotation,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recommendations
          _buildSectionCard(
            title: 'Medical Recommendations',
            icon: Icons.fact_check_rounded,
            iconColor: const Color(0xFF10B981),
            child: Column(
              children: _scanData.recommendations
                  .map((rec) => _buildRecommendationItem(rec))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Technical Details
          _buildSectionCard(
            title: 'Technical Details',
            icon: Icons.settings_outlined,
            iconColor: const Color(0xFF6B7280),
            child: Column(
              children: [
                _buildInfoRow(
                  label: 'AI Model',
                  value: _scanData.aiModel,
                  icon: Icons.psychology_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Processing Time',
                  value: _scanData.processingTime,
                  icon: Icons.timer_outlined,
                ),
                _buildDivider(),
                _buildInfoRow(
                  label: 'Analysis Date',
                  value: _formatDateTime(_scanData.analysisDate),
                  icon: Icons.calendar_month_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGES TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medical Imaging',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),

          // In a real app, these would be actual images
          _buildImagePreview(
            'Mammogram - CC View',
            Icons.monitor_heart_outlined,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          _buildImagePreview(
            'Ultrasound - Transverse',
            Icons.waves_outlined,
            const Color(0xFF0EA5E9),
          ),

          const SizedBox(height: 20),

          // Image Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.compare_outlined),
                  label: const Text('Compare'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HISTORY TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Previous Scans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          if (_scanData.previousScans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.history_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No previous scans',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._scanData.previousScans.map((scan) => _buildHistoryItem(scan)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(PreviousScanSummary scan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(scan.date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scan.diagnosis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  scan.severity,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTES TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Radiologist Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Add notes or observations...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM ACTIONS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.compare_outlined),
              label: const Text('Compare'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF6366F1)),
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Download Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[200]);
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 14,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════
class ScanDetailData {
  final String id;
  final DateTime scanDate;
  final DateTime analysisDate;
  final String patientName;
  final int patientAge;
  final String patientId;
  final String scanType;
  final String diagnosis;
  final String stage;
  final String severity;
  final String tnmClassification;
  final String tumorSize;
  final String lymphNodes;
  final double confidence;
  final int riskScore;
  final String clinicalFindings;
  final String aiModel;
  final String processingTime;
  final List<String> imageUrls;
  final List<String> recommendations;
  final List<PreviousScanSummary> previousScans;
  final List<String> annotations;
  final String radiologistNotes;
  final String status;

  ScanDetailData({
    required this.id,
    required this.scanDate,
    required this.analysisDate,
    required this.patientName,
    required this.patientAge,
    required this.patientId,
    required this.scanType,
    required this.diagnosis,
    required this.stage,
    required this.severity,
    required this.tnmClassification,
    required this.tumorSize,
    required this.lymphNodes,
    required this.confidence,
    required this.riskScore,
    required this.clinicalFindings,
    required this.aiModel,
    required this.processingTime,
    required this.imageUrls,
    required this.recommendations,
    required this.previousScans,
    required this.annotations,
    required this.radiologistNotes,
    required this.status,
  });
}

class PreviousScanSummary {
  final DateTime date;
  final String diagnosis;
  final String severity;

  PreviousScanSummary({
    required this.date,
    required this.diagnosis,
    required this.severity,
  });
}
