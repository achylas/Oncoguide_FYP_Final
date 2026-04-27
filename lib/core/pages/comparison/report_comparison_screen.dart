import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/comparison_service.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/recommendation_engine.dart';
import '../../widgets/resuable_top_bar.dart';

/// Screen for comparing two reports side-by-side
class ReportComparisonScreen extends StatefulWidget {
  final Map<String, dynamic> olderReport;
  final Map<String, dynamic> newerReport;
  final String patientName;
  final String patientId;

  const ReportComparisonScreen({
    super.key,
    required this.olderReport,
    required this.newerReport,
    required this.patientName,
    required this.patientId,
  });

  @override
  State<ReportComparisonScreen> createState() => _ReportComparisonScreenState();
}

class _ReportComparisonScreenState extends State<ReportComparisonScreen> {
  late ComparisonResult _comparison;
  bool _saving = false;
  Map<String, dynamic> _patientData = {};
  int _patientAge = 0;

  @override
  void initState() {
    super.initState();
    _comparison = ComparisonService.compare(
      olderReport: widget.olderReport,
      newerReport: widget.newerReport,
    );
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();
      if (doc.exists && mounted) {
        final data = {'id': doc.id, ...doc.data()!};
        setState(() {
          _patientData = data;
          _patientAge = (data['age'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveComparison() async {
    setState(() => _saving = true);
    try {
      final id = await ComparisonService.saveComparison(
        comparison: _comparison,
        patientId: widget.patientId,
        patientName: widget.patientName,
      );

      if (id != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comparison saved successfully'),
          backgroundColor: Color(0xFF10B981),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    // Determine report type from the older report
    final reportType = widget.olderReport['type']?.toString() ?? 'mammogram';
    final isMammogramComparison = reportType == 'mammogram';
    final isUltrasoundComparison = reportType == 'ultrasound';

    final olderDate = _formatDate(widget.olderReport['createdAt']);
    final newerDate = _formatDate(widget.newerReport['createdAt']);

    final olderRisk = (widget.olderReport['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final newerRisk = (widget.newerReport['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final olderRiskLabel = widget.olderReport['riskLabel']?.toString() ?? '';
    final newerRiskLabel = widget.newerReport['riskLabel']?.toString() ?? '';

    // ── Ultrasound-specific fields ────────────────────────────────────────
    final olderUsPrediction = widget.olderReport['prediction']?.toString() ?? '';
    final newerUsPrediction = widget.newerReport['prediction']?.toString() ?? '';
    final olderUsConfidence = (widget.olderReport['confidence'] as num?)?.toDouble() ?? 0.0;
    final newerUsConfidence = (widget.newerReport['confidence'] as num?)?.toDouble() ?? 0.0;

    // ── Mammogram-specific fields ─────────────────────────────────────────
    final olderMammoPrediction = widget.olderReport['mammoPrediction']?.toString() ?? '';
    final newerMammoPrediction = widget.newerReport['mammoPrediction']?.toString() ?? '';
    final olderMammoConfidence = (widget.olderReport['mammoConfidence'] as num?)?.toDouble() ?? 0.0;
    final newerMammoConfidence = (widget.newerReport['mammoConfidence'] as num?)?.toDouble() ?? 0.0;

    final olderDensityLabel = widget.olderReport['densityLabel']?.toString() ?? '';
    final newerDensityLabel = widget.newerReport['densityLabel']?.toString() ?? '';
    final olderDensityIndex = (widget.olderReport['densityIndex'] as num?)?.toInt();
    final newerDensityIndex = (widget.newerReport['densityIndex'] as num?)?.toInt();
    final olderDensityConf  = (widget.olderReport['densityConfidence'] as num?)?.toDouble() ?? 0.0;
    final newerDensityConf  = (widget.newerReport['densityConfidence'] as num?)?.toDouble() ?? 0.0;

    final olderGradcamUs      = widget.olderReport['gradcamUrl']?.toString();
    final newerGradcamUs      = widget.newerReport['gradcamUrl']?.toString();
    final olderGradcamDensity = widget.olderReport['densityGradcamUrl']?.toString();
    final newerGradcamDensity = widget.newerReport['densityGradcamUrl']?.toString();
    final olderGradcamMammo   = widget.olderReport['mammoGradcamUrl']?.toString();
    final newerGradcamMammo   = widget.newerReport['mammoGradcamUrl']?.toString();

    // Show GradCAM section only for the relevant type
    final hasUsGradcam = isUltrasoundComparison &&
        (olderGradcamUs != null || newerGradcamUs != null);
    final hasDensityGradcam = isMammogramComparison &&
        ((olderGradcamDensity != null && olderGradcamDensity.isNotEmpty) ||
         (newerGradcamDensity != null && newerGradcamDensity.isNotEmpty));
    final hasMammoGradcam = isMammogramComparison &&
        ((olderGradcamMammo != null && olderGradcamMammo.isNotEmpty) ||
         (newerGradcamMammo != null && newerGradcamMammo.isNotEmpty));
    final hasAnyGradcam = hasUsGradcam || hasDensityGradcam || hasMammoGradcam;

    final olderImage = widget.olderReport['mammogramUrl']?.toString() ??
        widget.olderReport['ultrasoundUrl']?.toString();
    final newerImage = widget.newerReport['mammogramUrl']?.toString() ??
        widget.newerReport['ultrasoundUrl']?.toString();

    final olderShap = widget.olderReport['shapValues'] as Map<String, dynamic>?;
    final newerShap = widget.newerReport['shapValues'] as Map<String, dynamic>?;

    final olderRecommendations = _generateRecommendations(widget.olderReport);
    final newerRecommendations = _generateRecommendations(widget.newerReport);

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: 'Report Comparison',
        subtitle: Text(widget.patientName),
        showBackButton: true,
        showSettingsButton: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveComparison,
        backgroundColor: const Color(0xFF6366F1),
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded, color: Colors.white),
        label: Text(
          _saving ? 'Saving...' : 'Save Comparison',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrendBanner(trend: _comparison.overallTrend),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _HeaderCard(
                    isDark: isDark,
                    label: 'Older Report',
                    date: olderDate,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderCard(
                    isDark: isDark,
                    label: 'Newer Report',
                    date: newerDate,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionTitle('Risk Score', Icons.analytics_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RiskCard(
                    isDark: isDark,
                    risk: olderRisk,
                    riskLabel: olderRiskLabel,
                    isOlder: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RiskCard(
                    isDark: isDark,
                    risk: newerRisk,
                    riskLabel: newerRiskLabel,
                    isOlder: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ChangeIndicator(
              change: _comparison.riskChange,
              label: 'Risk Score',
              isPercentage: true,
            ),
            const SizedBox(height: 20),

            // ── Ultrasound: show US prediction ────────────────────────────
            if (isUltrasoundComparison &&
                (olderUsPrediction.isNotEmpty || newerUsPrediction.isNotEmpty)) ...[
              _SectionTitle('Ultrasound Prediction', Icons.waves_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _PredictionCard(
                  isDark: isDark,
                  prediction: olderUsPrediction,
                  confidence: olderUsConfidence,
                  isOlder: true,
                )),
                const SizedBox(width: 12),
                Expanded(child: _PredictionCard(
                  isDark: isDark,
                  prediction: newerUsPrediction,
                  confidence: newerUsConfidence,
                  isOlder: false,
                )),
              ]),
              const SizedBox(height: 20),
            ],

            // ── Mammogram: show mammogram finding prediction ───────────────
            if (isMammogramComparison &&
                (olderMammoPrediction.isNotEmpty || newerMammoPrediction.isNotEmpty)) ...[
              _SectionTitle('Mammogram Finding', Icons.monitor_heart_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _PredictionCard(
                  isDark: isDark,
                  prediction: olderMammoPrediction,
                  confidence: olderMammoConfidence,
                  isOlder: true,
                  isMammogram: true,
                )),
                const SizedBox(width: 12),
                Expanded(child: _PredictionCard(
                  isDark: isDark,
                  prediction: newerMammoPrediction,
                  confidence: newerMammoConfidence,
                  isOlder: false,
                  isMammogram: true,
                )),
              ]),
              const SizedBox(height: 20),
            ],

            // ── Mammogram: show density comparison ────────────────────────
            if (isMammogramComparison &&
                (olderDensityLabel.isNotEmpty || newerDensityLabel.isNotEmpty)) ...[
              _SectionTitle('Breast Density', Icons.density_medium_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DensityCard(
                  isDark: isDark,
                  densityLabel: olderDensityLabel,
                  densityIndex: olderDensityIndex,
                  confidence: olderDensityConf,
                  isOlder: true,
                )),
                const SizedBox(width: 12),
                Expanded(child: _DensityCard(
                  isDark: isDark,
                  densityLabel: newerDensityLabel,
                  densityIndex: newerDensityIndex,
                  confidence: newerDensityConf,
                  isOlder: false,
                )),
              ]),
              if (_comparison.densityChange != null && _comparison.densityChange != 0) ...[
                const SizedBox(height: 8),
                _ChangeIndicator(
                  change: _comparison.densityChange!.toDouble(),
                  label: 'Density',
                  isPercentage: false,
                ),
              ],
              const SizedBox(height: 20),
            ],

            if (hasAnyGradcam) ...[
              _SectionTitle('GradCAM — AI Visual Explanation', Icons.thermostat_rounded),
              const SizedBox(height: 8),
              // Explanation banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Heatmaps highlight which image regions drove the AI prediction. '
                    'Red = high influence, blue = low influence.',
                    style: TextStyle(
                      fontSize: 11.5, height: 1.5,
                      color: isDark ? const Color(0xFFB0B3C5) : const Color(0xFF4B5563),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Ultrasound GradCAM ──────────────────────────────────────────
              if (olderGradcamUs != null || newerGradcamUs != null) ...[
                _GradCamRowLabel(
                  isDark: isDark,
                  icon: Icons.waves_rounded,
                  color: const Color(0xFF6C63FF),
                  label: 'Ultrasound GradCAM',
                  subtitle: 'AI focus regions on ultrasound scan',
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: olderGradcamUs,
                      isBase64: false,
                      reportLabel: 'Older Report',
                      isOlder: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: newerGradcamUs,
                      isBase64: false,
                      reportLabel: 'Newer Report',
                      isOlder: false,
                    )),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── Density GradCAM ─────────────────────────────────────────────
              if ((olderGradcamDensity != null && olderGradcamDensity.isNotEmpty) ||
                  (newerGradcamDensity != null && newerGradcamDensity.isNotEmpty)) ...[
                _GradCamRowLabel(
                  isDark: isDark,
                  icon: Icons.density_medium_rounded,
                  color: const Color(0xFFFF6F91),
                  label: 'Mammogram Density GradCAM',
                  subtitle: 'AI focus regions on CC mammogram view',
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: olderGradcamDensity,
                      isBase64: false,
                      reportLabel: 'Older Report',
                      isOlder: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: newerGradcamDensity,
                      isBase64: false,
                      reportLabel: 'Newer Report',
                      isOlder: false,
                    )),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── Mammogram Finding GradCAM ────────────────────────────────────
              if ((olderGradcamMammo != null && olderGradcamMammo.isNotEmpty) ||
                  (newerGradcamMammo != null && newerGradcamMammo.isNotEmpty)) ...[
                _GradCamRowLabel(
                  isDark: isDark,
                  icon: Icons.monitor_heart_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Mammogram Finding GradCAM',
                  subtitle: 'AI focus regions for BI-RADS classification',
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: olderGradcamMammo,
                      isBase64: false,
                      reportLabel: 'Older Report',
                      isOlder: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _GradCamCard(
                      isDark: isDark,
                      imageUrl: newerGradcamMammo,
                      isBase64: false,
                      reportLabel: 'Newer Report',
                      isOlder: false,
                    )),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 20),
            ],

            if (olderImage != null || newerImage != null) ...[
              _SectionTitle('Uploaded Scans', Icons.medical_information_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ImageCard(
                      isDark: isDark,
                      imageUrl: olderImage,
                      label: 'Older',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageCard(
                      isDark: isDark,
                      imageUrl: newerImage,
                      label: 'Newer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (olderShap != null || newerShap != null) ...[
              _SectionTitle('Risk Factors (SHAP)', Icons.bar_chart_rounded),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ShapCard(
                      isDark: isDark,
                      shapValues: olderShap,
                      label: 'Older',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShapCard(
                      isDark: isDark,
                      shapValues: newerShap,
                      label: 'Newer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            _SectionTitle('Previous Recommendations', Icons.history_rounded),
            const SizedBox(height: 12),
            _RecommendationsCard(
              isDark: isDark,
              recommendations: olderRecommendations,
              label: 'From Older Report',
            ),
            const SizedBox(height: 20),

            _SectionTitle('Updated Recommendations', Icons.fact_check_rounded),
            const SizedBox(height: 12),
            _RecommendationsCard(
              isDark: isDark,
              recommendations: newerRecommendations,
              label: 'Based on Latest Report',
              isNew: true,
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3D2F1F) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This comparison is AI-assisted. All recommendations must be reviewed by a qualified medical professional.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? const Color(0xFFB0B3C5) : Colors.brown[700],
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  List<Recommendation> _generateRecommendations(Map<String, dynamic> report) {
    double safeD(dynamic v, [double fb = 0.0]) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fb;
      return fb;
    }
    Map<String, double> safeMap(dynamic raw) {
      if (raw is! Map) return {};
      return Map.fromEntries(raw.entries
          .where((e) => e.value is num || e.value is String)
          .map((e) => MapEntry(e.key.toString(), safeD(e.value))));
    }

    final riskLabel  = report['riskLabel']?.toString() ?? '';
    final riskPct    = safeD(report['riskPercentage']);
    final shapRaw    = report['shapValues'];
    final baseValue  = safeD(report['baseValue']);

    TabularPredictionResult? tabularResult;
    if (riskLabel.isNotEmpty && shapRaw is Map) {
      tabularResult = TabularPredictionResult(
        prediction: riskLabel == 'High Risk' ? 1 : 0,
        probability: riskPct / 100.0,
        riskPercentage: riskPct,
        riskLabel: riskLabel,
        shapValues: safeMap(shapRaw),
        baseValue: baseValue,
      );
    }

    final usPrediction  = report['prediction']?.toString();
    final usConfidence  = safeD(report['confidence']);
    final probabilities = report['probabilities'];

    UltrasoundAnalysisResult? usResult;
    if (usPrediction != null && usPrediction.isNotEmpty) {
      final predIndex = usPrediction == 'Benign' ? 0
          : usPrediction == 'Normal' ? 1
          : usPrediction == 'Malignant' ? 2 : 1;
      usResult = UltrasoundAnalysisResult(
        prediction: usPrediction,
        predictionIndex: predIndex,
        confidence: usConfidence,
        probabilities: safeMap(probabilities),
        gradcamImage: '',
      );
    }

    final densityIndexRaw = report['densityIndex'];
    final densityIndex    = densityIndexRaw is num ? densityIndexRaw.toInt() : null;
    final densityClass    = report['densityClass']?.toString() ?? '';
    final densityLabel    = report['densityLabel']?.toString() ?? '';
    final densityConf     = safeD(report['densityConfidence']);
    final densProbs       = report['densityProbabilities'];

    DensityAnalysisResult? densityResult;
    if (densityIndex != null && densityIndex >= 0) {
      densityResult = DensityAnalysisResult(
        densityClass: densityClass,
        densityLabel: densityLabel,
        densityIndex: densityIndex,
        confidence: densityConf,
        probabilities: safeMap(densProbs),
        gradcamImage: '',
      );
    }

    final Map<String, dynamic> patient = {
      ...(_patientData.isNotEmpty ? _patientData : {}),
      'name': widget.patientName,
      'age': _patientAge,
    };

    return RecommendationEngine.generate(
      patient: patient,
      tabularResult: tabularResult,
      ultrasoundAnalysis: usResult,
      densityAnalysis: densityResult,
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
// Section Title
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String date;
  final Color color;

  const _HeaderCard({
    required this.isDark,
    required this.label,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend Banner
// ─────────────────────────────────────────────────────────────────────────────
class _TrendBanner extends StatelessWidget {
  final ComparisonTrend trend;
  const _TrendBanner({required this.trend});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (trend) {
      case ComparisonTrend.improving:
        color = const Color(0xFF10B981);
        icon = Icons.trending_down_rounded;
        label = 'Improving Trend';
        break;
      case ComparisonTrend.declining:
        color = const Color(0xFFEF4444);
        icon = Icons.trending_up_rounded;
        label = 'Declining Trend';
        break;
      case ComparisonTrend.stable:
        color = const Color(0xFF6366F1);
        icon = Icons.trending_flat_rounded;
        label = 'Stable Condition';
        break;
      case ComparisonTrend.mixed:
        color = const Color(0xFFF59E0B);
        icon = Icons.swap_vert_rounded;
        label = 'Mixed Changes';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Card
// ─────────────────────────────────────────────────────────────────────────────
class _RiskCard extends StatelessWidget {
  final bool isDark;
  final double risk;
  final String riskLabel;
  final bool isOlder;

  const _RiskCard({
    required this.isDark,
    required this.risk,
    required this.riskLabel,
    required this.isOlder,
  });

  @override
  Widget build(BuildContext context) {
    final isHighRisk = riskLabel == 'High Risk';
    final color = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOlder ? Colors.grey.withOpacity(0.3) : const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isOlder ? 'Older' : 'Newer',
            style: TextStyle(
              fontSize: 11,
              color: isOlder ? Colors.grey : const Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${risk.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            riskLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Indicator
// ─────────────────────────────────────────────────────────────────────────────
class _ChangeIndicator extends StatelessWidget {
  final double change;
  final String label;
  final bool isPercentage;

  const _ChangeIndicator({
    required this.change,
    required this.label,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isImproving = change < 0;
    final color = isImproving ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final icon = isImproving ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '${isImproving ? '' : '+'}${change.toStringAsFixed(1)}${isPercentage ? '%' : ''}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isImproving ? 'Improvement' : 'Increase',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prediction Card
// ─────────────────────────────────────────────────────────────────────────────
class _PredictionCard extends StatelessWidget {
  final bool isDark;
  final String prediction;
  final double confidence;
  final bool isOlder;
  final bool isMammogram;

  const _PredictionCard({
    required this.isDark,
    required this.prediction,
    required this.confidence,
    required this.isOlder,
    this.isMammogram = false,
  });

  @override
  Widget build(BuildContext context) {
    Color predColor;
    if (isMammogram) {
      // Mammogram: Normal / Benign / Suspicious
      if (prediction == 'Suspicious') {
        predColor = const Color(0xFFEF4444);
      } else if (prediction == 'Benign') {
        predColor = const Color(0xFFF59E0B);
      } else {
        predColor = const Color(0xFF10B981);
      }
    } else {
      // Ultrasound: Benign / Normal / Malignant
      if (prediction == 'Malignant') {
        predColor = const Color(0xFFEF4444);
      } else if (prediction == 'Benign') {
        predColor = const Color(0xFFF59E0B);
      } else {
        predColor = const Color(0xFF10B981);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOlder ? Colors.grey.withOpacity(0.3) : const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isOlder ? 'Older' : 'Newer',
            style: TextStyle(
              fontSize: 11,
              color: isOlder ? Colors.grey : const Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prediction.isEmpty ? 'N/A' : prediction,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: predColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${confidence.toStringAsFixed(0)}% confidence',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Card
// ─────────────────────────────────────────────────────────────────────────────
class _ImageCard extends StatelessWidget {
  final bool isDark;
  final String? imageUrl;
  final String label;

  const _ImageCard({
    required this.isDark,
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SHAP Card
// ─────────────────────────────────────────────────────────────────────────────
class _ShapCard extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic>? shapValues;
  final String label;

  const _ShapCard({
    required this.isDark,
    required this.shapValues,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (shapValues == null || shapValues!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No SHAP data',
            style: TextStyle(color: AppColors.getTextSecondary(context)),
          ),
        ),
      );
    }

    final sorted = shapValues!.entries.toList()
      ..sort((a, b) => (b.value as num).abs().compareTo((a.value as num).abs()));
    final top5 = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...top5.map((entry) {
            final value = (entry.value as num).toDouble();
            final isPositive = value >= 0;
            final color = isPositive ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _formatShapKey(entry.key),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${value.toStringAsFixed(3)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: (value.abs() / 0.1).clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatShapKey(String key) {
    const labels = {
      'age': 'Age',
      'weight': 'Weight',
      'imc': 'BMI',
      'family_history': 'Family History',
      'exercise_regular': 'Exercise',
      'breastfeeding': 'Breastfeeding',
    };
    return labels[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradCAM Row Label
// ─────────────────────────────────────────────────────────────────────────────
class _GradCamRowLabel extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;

  const _GradCamRowLabel({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: AppColors.getTextPrimary(context),
        )),
        Text(subtitle, style: TextStyle(
          fontSize: 11, color: AppColors.getTextSecondary(context),
        )),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradCAM Card — network image from Supabase URL
// ─────────────────────────────────────────────────────────────────────────────
class _GradCamCard extends StatelessWidget {
  final bool isDark;
  final String? imageUrl;
  final bool isBase64;      // kept for API compatibility, ignored (all URLs now)
  final String reportLabel;
  final bool isOlder;

  const _GradCamCard({
    required this.isDark,
    required this.imageUrl,
    required this.isBase64,
    required this.reportLabel,
    required this.isOlder,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isOlder
        ? Colors.grey.withOpacity(0.35)
        : const Color(0xFF6366F1).withOpacity(0.4);
    final labelColor = isOlder ? Colors.grey : const Color(0xFF6366F1);
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(reportLabel, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: labelColor,
              )),
            ]),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : const SizedBox(height: 180,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorBuilder: (_, __, ___) => _noImagePlaceholder(isDark),
                  )
                : _noImagePlaceholder(isDark),
          ),
        ],
      ),
    );
  }

  Widget _noImagePlaceholder(bool isDark) {
    return Container(
      height: 180,
      color: isDark ? const Color(0xFF252840) : const Color(0xFFF3F4F6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.thermostat_rounded,
            size: 36, color: isDark ? const Color(0xFF4A4D6A) : Colors.grey[400]),
        const SizedBox(height: 8),
        Text('No GradCAM available',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF4A4D6A) : Colors.grey[400],
            )),
      ]),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Density Card
// ─────────────────────────────────────────────────────────────────────────────
class _DensityCard extends StatelessWidget {
  final bool isDark;
  final String densityLabel;
  final int? densityIndex;
  final double confidence;
  final bool isOlder;

  const _DensityCard({
    required this.isDark,
    required this.densityLabel,
    required this.densityIndex,
    required this.confidence,
    required this.isOlder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF10B981), // A — Fatty
      const Color(0xFF3B82F6), // B — Scattered
      const Color(0xFFF59E0B), // C — Heterogeneous
      const Color(0xFFEF4444), // D — Extremely Dense
    ];
    final idx = (densityIndex ?? 0).clamp(0, 3);
    final color = densityLabel.isEmpty ? Colors.grey : colors[idx];
    final densLetter = ['A', 'B', 'C', 'D'][idx];
    final borderColor = isOlder
        ? Colors.grey.withOpacity(0.3)
        : const Color(0xFF6366F1).withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        Text(
          isOlder ? 'Older' : 'Newer',
          style: TextStyle(
            fontSize: 11,
            color: isOlder ? Colors.grey : const Color(0xFF6366F1),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        densityLabel.isEmpty
            ? const Text('N/A', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey))
            : Column(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(child: Text(
                    densLetter,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                  )),
                ),
                const SizedBox(height: 8),
                Text(
                  densityLabel,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  textAlign: TextAlign.center,
                ),
              ]),
        const SizedBox(height: 6),
        if (confidence > 0)
          Text(
            '${confidence.toStringAsFixed(0)}% confidence',
            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)),
          ),
      ]),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final bool isDark;
  final List<Recommendation> recommendations;
  final String label;
  final bool isNew;

  const _RecommendationsCard({
    required this.isDark,
    required this.recommendations,
    required this.label,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Center(
          child: Text(
            'No recommendations available',
            style: TextStyle(color: AppColors.getTextSecondary(context)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isNew ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              if (isNew) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...recommendations.map((rec) {
            Color color;
            switch (rec.priority) {
              case RecPriority.urgent:
                color = const Color(0xFFEF4444);
                break;
              case RecPriority.high:
                color = const Color(0xFFF59E0B);
                break;
              case RecPriority.medium:
                color = const Color(0xFF6366F1);
                break;
              case RecPriority.low:
                color = const Color(0xFF10B981);
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.detail,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
