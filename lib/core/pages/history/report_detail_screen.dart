
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/pdf_service.dart';
import 'package:oncoguide_v2/services/recommendation_engine.dart';
import '../../widgets/resuable_top_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportDetailScreen
// Shows every section that ScanResultPage shows, reconstructed from Firestore
// data. Works for both doctor reports (mammogram/ultrasound) and radiologist
// reports.
// ─────────────────────────────────────────────────────────────────────────────

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportDetailScreen({super.key, required this.reportData});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _savingPdf = false;
  String? _pdfUrl;
  int _patientAge = 0;
  Map<String, dynamic> _patientData = {};

  /// Safe numeric extractor — never throws on unexpected types.
  static double _n(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _pdfUrl = widget.reportData['pdfUrl']?.toString();
    final storedAge = widget.reportData['patientAge'];
    if (storedAge is num && storedAge > 0) {
      _patientAge = storedAge.toInt();
    }
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    final pid = widget.reportData['patientId']?.toString();
    if (pid == null || pid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('patients').doc(pid).get();
      if (doc.exists && mounted) {
        final data = {'id': doc.id, ...doc.data()!};
        setState(() {
          _patientData = data;
          if (_patientAge == 0) {
            final ageVal = data['age'];
            _patientAge = ageVal is num ? ageVal.toInt() : 0;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAsPdf() async {
    setState(() => _savingPdf = true);
    try {
      final url = await PdfService.generateAndUpload(widget.reportData);
      if (url != null) {
        final docId = widget.reportData['id']?.toString();
        final type  = widget.reportData['type']?.toString();
        if (docId != null && type != null) {
          final col = type == 'mammogram' ? 'mammogram_reports' : 'ultrasound_reports';
          await FirebaseFirestore.instance.collection(col).doc(docId).update({'pdfUrl': url});
        }
        setState(() => _pdfUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('PDF saved!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);
    final d = widget.reportData;

    // ── Source ────────────────────────────────────────────────────────────
    final source = d['source']?.toString() ?? 'doctor';
    final isRadiologist = source == 'radiologist';

    // ── Patient ───────────────────────────────────────────────────────────
    final patientName = d['patientName']?.toString() ?? 'Unknown';
    final scanLabel   = d['scanLabel']?.toString() ?? '';

    // ── Risk ──────────────────────────────────────────────────────────────
    final riskLabel  = d['riskLabel']?.toString() ?? '';
    final riskPct    = _n(d['riskPercentage']);
    final isHighRisk = riskLabel == 'High Risk';

    // ── Ultrasound ────────────────────────────────────────────────────────
    final usPrediction = d['usPrediction']?.toString() ?? d['prediction']?.toString();
    final usConfidence = _n(d['usConfidence'] ?? d['confidence']);
    final probRaw = d['usProbabilities'] ?? (isRadiologist ? null : d['probabilities']);
    final Map<String, double> probs = probRaw is Map
        ? Map.fromEntries(probRaw.entries
            .where((e) => e.value is num || e.value is String)
            .map((e) => MapEntry(e.key.toString(), _n(e.value))))
        : {};

    // ── Density ───────────────────────────────────────────────────────────
    final densityLabel = d['densityLabel']?.toString() ?? '';
    final densityClass = d['densityClass']?.toString() ?? '';
    final densityConf  = d['densityConfidence'] != null ? _n(d['densityConfidence']) : null;
    final densityIndex = d['densityIndex'] is num ? (d['densityIndex'] as num).toInt() : -1;
    final densProbs    = d['densityProbabilities'];
    final Map<String, double> densMap = (densProbs is Map && densityLabel.isNotEmpty)
        ? Map.fromEntries(densProbs.entries
            .where((e) => e.value is num || e.value is String)
            .map((e) => MapEntry(e.key.toString(), _n(e.value))))
        : {};

    // ── Mammogram Analysis ────────────────────────────────────────────────
    final mammoPrediction  = d['mammoPrediction']?.toString() ?? '';
    final mammoPredIdx     = d['mammoPredictionIndex'] is num ? (d['mammoPredictionIndex'] as num).toInt() : -1;
    final mammoConf        = d['mammoConfidence'] != null ? _n(d['mammoConfidence']) : null;
    final mammoFinding     = d['mammoFindingCategory']?.toString() ?? '';
    final mammoProbs       = d['mammoProbabilities'];
    final Map<String, double> mammoMap = (mammoProbs is Map && mammoPrediction.isNotEmpty)
        ? Map.fromEntries(mammoProbs.entries
            .where((e) => e.value is num || e.value is String)
            .map((e) => MapEntry(e.key.toString(), _n(e.value))))
        : {};

    // ── Images ────────────────────────────────────────────────────────────
    final mammogramUrl  = d['mammogramUrl']?.toString() ?? d['ccImageUrl']?.toString();
    final mloUrl        = d['mloImageUrl']?.toString();
    final ultrasoundUrl = d['ultrasoundUrl']?.toString();
    final gradcamUrl    = d['gradcamUrl']?.toString();

    // ── Validation scores ─────────────────────────────────────────────────
    final mammoScore = d['gatekeeperScore'] != null ? _n(d['gatekeeperScore']) : null;
    final isValid    = d['isValid'] as bool?;

    // ── SHAP ──────────────────────────────────────────────────────────────
    final shapRaw = d['shapValues'];
    final Map<String, double> shapValues = shapRaw is Map
        ? Map.fromEntries(shapRaw.entries
            .where((e) => e.value is num || e.value is String)
            .map((e) => MapEntry(e.key.toString(), _n(e.value))))
        : {};
    final baseValue = d['baseValue'] != null ? _n(d['baseValue']) : 0.0;
    final sortedShap = shapValues.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    // ── Reconstruct model objects for RecommendationEngine ───────────────
    TabularPredictionResult? tabularResult;
    if (riskLabel.isNotEmpty && shapValues.isNotEmpty) {
      tabularResult = TabularPredictionResult(
        prediction: isHighRisk ? 1 : 0,
        probability: riskPct / 100.0, // Convert percentage to 0.0-1.0
        riskPercentage: riskPct,
        riskLabel: riskLabel,
        shapValues: shapValues,
        baseValue: baseValue,
      );
    }

    UltrasoundAnalysisResult? usResult;
    if (usPrediction != null && usPrediction.isNotEmpty) {
      final predIndex = usPrediction == 'Benign' ? 0
          : usPrediction == 'Normal' ? 1
          : usPrediction == 'Malignant' ? 2 : 1;
      usResult = UltrasoundAnalysisResult(
        prediction: usPrediction,
        predictionIndex: predIndex,
        confidence: usConfidence ?? 0.0,
        probabilities: probs,
        gradcamImage: '',
      );
    }

    DensityAnalysisResult? densityResult;
    if (densityLabel.isNotEmpty && densityIndex >= 0) {
      densityResult = DensityAnalysisResult(
        densityClass: densityClass,
        densityLabel: densityLabel,
        densityIndex: densityIndex,
        confidence: densityConf ?? 0.0,
        probabilities: densMap,
        gradcamImage: '',
      );
    }

    MammogramAnalysisResult? mammoResult;
    if (mammoPrediction.isNotEmpty && mammoPredIdx >= 0) {
      mammoResult = MammogramAnalysisResult(
        prediction:      mammoPrediction,
        predictionIndex: mammoPredIdx,
        confidence:      mammoConf ?? 0.0,
        probabilities:   mammoMap,
        gradcamImage:    '',
        findingCategory: mammoFinding,
      );
    }

    // Patient data for recommendations (merge stored + fetched)
    final Map<String, dynamic> patientForRecs = {
      ...(_patientData.isNotEmpty ? _patientData : {}),
      'name': patientName,
      'age': _patientAge,
    };

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: isRadiologist ? 'Radiologist Report' : 'Report Detail',
        subtitle: Text(patientName),
        showBackButton: true,
        showSettingsButton: false,
      ),
      floatingActionButton: !isRadiologist
          ? FloatingActionButton.extended(
              onPressed: _savingPdf ? null : () => PdfService.shareReport(d),
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── PDF save button (doctor reports) ─────────────────────────
            if (!isRadiologist) ...[
              _card(isDark: isDark, child: Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _savingPdf ? null : _saveAsPdf,
                  icon: _savingPdf
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(_savingPdf ? 'Saving...' : _pdfUrl != null ? 'Re-save PDF' : 'Save as PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
              ])),
              const SizedBox(height: 16),
              if (_pdfUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('PDF saved to cloud storage',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // ── Radiologist badge ─────────────────────────────────────────
            if (isRadiologist) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_hospital_rounded, color: Color(0xFF6C63FF), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    scanLabel.isNotEmpty ? 'Radiologist Report — $scanLabel' : 'Radiologist Report',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── 1. Patient header ─────────────────────────────────────────
            _card(isDark: isDark, child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(
                  patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                )),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(patientName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context))),
                Text(_patientAge > 0 ? '$_patientAge years' : 'Age not recorded',
                    style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
              ),
            ])),
            const SizedBox(height: 20),

            // ── 2. Verdict banner ─────────────────────────────────────────
            if (riskLabel.isNotEmpty) ...[
              _VerdictBanner(isHighRisk: isHighRisk, riskPct: riskPct, riskLabel: riskLabel),
              const SizedBox(height: 20),
            ],

            // ── 3. Ultrasound finding ─────────────────────────────────────
            if (usPrediction != null && usPrediction.isNotEmpty) ...[
              _UltrasoundCard(
                isDark: isDark,
                prediction: usPrediction,
                confidence: usConfidence ?? 0.0,
                probs: probs,
              ),
              const SizedBox(height: 20),
            ],

            // ── 3b. Mammogram finding (BI-RADS classification) ────────────
            if (mammoResult != null) ...[
              _MammogramFindingCard(isDark: isDark, result: mammoResult),
              const SizedBox(height: 20),
            ],

            // ── 3c. Density analysis ──────────────────────────────────────
            if (densityLabel.isNotEmpty || densityClass.isNotEmpty) ...[
              _DensityCard(
                isDark: isDark,
                densityLabel: densityLabel,
                densityClass: densityClass,
                densityIndex: densityIndex,
                densityConf: densityConf,
                densMap: densMap,
                mammoPrediction: mammoPrediction,
              ),
              const SizedBox(height: 20),
            ],

            // ── 4. Risk metrics ───────────────────────────────────────────
            if (riskLabel.isNotEmpty) ...[
              _RiskMetricsRow(isDark: isDark, riskPct: riskPct, riskLabel: riskLabel, isHighRisk: isHighRisk),
              const SizedBox(height: 20),
            ],

            // ── 5. GradCAM (URL-based from Supabase) ──────────────────────
            if (gradcamUrl != null && gradcamUrl.isNotEmpty) ...[
              _sectionCard(isDark: isDark, title: 'GradCAM — Visual Explanation',
                  icon: Icons.thermostat_rounded, iconColor: const Color(0xFF6C63FF),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Heatmap shows which regions of the ultrasound influenced the AI prediction.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.getTextSecondary(context), height: 1.5)),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: Image.network(gradcamUrl, width: double.infinity, fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) => progress == null ? child
                                : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                            errorBuilder: (_, __, ___) => const SizedBox(height: 80,
                                child: Center(child: Icon(Icons.broken_image_rounded))))),
                    const SizedBox(height: 10),
                    Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
                      _legendDot('Low', const Color(0xFF0000FF)),
                      _legendDot('Medium', const Color(0xFF00FF00)),
                      _legendDot('High', const Color(0xFFFF0000)),
                    ]),
                  ])),
              const SizedBox(height: 20),
            ],

            // ── 6. SHAP ───────────────────────────────────────────────────
            if (shapValues.isNotEmpty) ...[
              _ShapCard(isDark: isDark, sortedShap: sortedShap, baseValue: baseValue, totalFeatures: shapValues.length),
              const SizedBox(height: 20),
            ],

            // ── 7. Validation badge ───────────────────────────────────────
            if (mammoScore != null && isValid != null) ...[
              _sectionCard(isDark: isDark, title: 'Image Quality Check',
                  icon: Icons.shield_rounded, iconColor: const Color(0xFF0EA5E9),
                  child: _ValidationBadge(
                    label: d['type'] == 'mammogram' ? 'Mammogram' : 'Ultrasound',
                    isValid: isValid,
                    score: mammoScore * 100,
                  )),
              const SizedBox(height: 20),
            ],

            // ── 8. Uploaded scans ─────────────────────────────────────────
            if (mammogramUrl != null || mloUrl != null || ultrasoundUrl != null) ...[
              _sectionCard(isDark: isDark, title: 'Uploaded Scans',
                  icon: Icons.medical_information_rounded, iconColor: const Color(0xFF8B5CF6),
                  child: Column(children: [
                    if (mammogramUrl != null) ...[
                      _scanImage(context, 'Mammogram (CC)', Icons.monitor_heart_outlined, mammogramUrl),
                      const SizedBox(height: 12),
                    ],
                    if (mloUrl != null) ...[
                      _scanImage(context, 'Mammogram (MLO)', Icons.flip_rounded, mloUrl),
                      const SizedBox(height: 12),
                    ],
                    if (ultrasoundUrl != null)
                      _scanImage(context, 'Ultrasound', Icons.waves_outlined, ultrasoundUrl),
                  ])),
              const SizedBox(height: 20),
            ],

            // ── 9. Personalized Recommendations ──────────────────────────
            if (tabularResult != null || usResult != null) ...[
              _RecommendationsCard(
                patient: patientForRecs,
                tabularResult: tabularResult,
                usResult: usResult,
                densityResult: densityResult,
                mammoResult: mammoResult,
              ),
              const SizedBox(height: 20),
            ],

            // ── 10. Disclaimer ────────────────────────────────────────────
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
                Expanded(child: Text(
                  'This is an AI-assisted report. Must be reviewed by a qualified medical professional before any clinical decision.',
                  style: TextStyle(fontSize: 12, height: 1.5,
                      color: isDark ? const Color(0xFFB0B3C5) : Colors.brown[700]),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _scanImage(BuildContext context, String label, IconData icon, String url) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(12),
          child: Image.network(url, height: 180, width: double.infinity, fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) => progress == null ? child
                  : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => const SizedBox(height: 80,
                  child: Center(child: Icon(Icons.broken_image_rounded))))),
    ]);
  }

  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _sectionCard({required bool isDark, required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1F2937)))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verdict Banner
// ─────────────────────────────────────────────────────────────────────────────
class _VerdictBanner extends StatelessWidget {
  final bool isHighRisk;
  final double riskPct;
  final String riskLabel;
  const _VerdictBanner({required this.isHighRisk, required this.riskPct, required this.riskLabel});

  @override
  Widget build(BuildContext context) {
    final c1 = isHighRisk ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final c2 = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final verdict = isHighRisk ? 'High Risk Detected' : 'Low Risk';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c1.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(isHighRisk ? Icons.warning_rounded : Icons.check_circle_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('AI-Assisted Diagnosis',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 14),
        Text(verdict, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.2)),
        const SizedBox(height: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Risk Score', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
            Text('${riskPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: riskPct / 100,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              )),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          _chip(Icons.analytics_outlined, 'Random Forest Model'),
          _chip(Icons.device_hub_rounded, riskLabel),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ultrasound Card
// ─────────────────────────────────────────────────────────────────────────────
class _UltrasoundCard extends StatelessWidget {
  final bool isDark;
  final String prediction;
  final double confidence;
  final Map<String, double> probs;
  const _UltrasoundCard({required this.isDark, required this.prediction, required this.confidence, required this.probs});

  @override
  Widget build(BuildContext context) {
    Color predColor;
    IconData predIcon;
    String description;
    if (prediction == 'Malignant') {
      predColor = const Color(0xFFEF4444);
      predIcon = Icons.warning_rounded;
      description = 'Malignant characteristics detected in ultrasound. Immediate clinical follow-up required.';
    } else if (prediction == 'Benign') {
      predColor = const Color(0xFFF59E0B);
      predIcon = Icons.info_rounded;
      description = 'Benign mass detected. Monitor and follow up as recommended by your physician.';
    } else {
      predColor = const Color(0xFF10B981);
      predIcon = Icons.check_circle_rounded;
      description = 'No suspicious findings detected in ultrasound imaging.';
    }

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: predColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.waves_rounded, color: predColor, size: 18)),
          const SizedBox(width: 10),
          Text('Ultrasound Finding', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1F2937))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: predColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: predColor.withOpacity(0.4), width: 2),
            ),
            child: Icon(predIcon, color: predColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prediction, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: predColor, letterSpacing: -0.5)),
            Text('${confidence.toStringAsFixed(1)}% confidence',
                style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)),
          ])),
        ]),
        const SizedBox(height: 14),
        Text(description, style: TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.getTextSecondary(context))),
        if (probs.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...probs.entries.map((e) {
            final c = e.key == 'Malignant' ? const Color(0xFFEF4444)
                : e.key == 'Benign' ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                  Text('${e.value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                ]),
                const SizedBox(height: 5),
                LayoutBuilder(builder: (ctx, con) => Stack(children: [
                  Container(height: 7, width: con.maxWidth,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                  Container(height: 7, width: con.maxWidth * (e.value / 100),
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4)])),
                ])),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mammogram Finding Card
// ─────────────────────────────────────────────────────────────────────────────
class _MammogramFindingCard extends StatelessWidget {
  final bool isDark;
  final MammogramAnalysisResult result;
  const _MammogramFindingCard({required this.isDark, required this.result});

  @override
  Widget build(BuildContext context) {
    Color predColor;
    IconData predIcon;
    switch (result.predictionIndex) {
      case 2:
        predColor = const Color(0xFFEF4444);
        predIcon  = Icons.warning_rounded;
        break;
      case 1:
        predColor = const Color(0xFFF59E0B);
        predIcon  = Icons.info_rounded;
        break;
      default:
        predColor = const Color(0xFF10B981);
        predIcon  = Icons.check_circle_rounded;
    }

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: predColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.monitor_heart_rounded, color: predColor, size: 18)),
          const SizedBox(width: 10),
          Text('Mammogram Finding', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1F2937))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: predColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: predColor.withOpacity(0.4), width: 2),
            ),
            child: Icon(predIcon, color: predColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(result.prediction, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: predColor, letterSpacing: -0.5)),
            Text('${result.confidence.toStringAsFixed(1)}% confidence',
                style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)),
            if (result.findingCategory.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: predColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(result.findingCategory,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: predColor)),
              ),
            ],
          ])),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: predColor.withOpacity(isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: predColor.withOpacity(0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: predColor),
            const SizedBox(width: 8),
            Expanded(child: Text(result.clinicalNote,
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.getTextSecondary(context)))),
          ]),
        ),
        if (result.probabilities.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...result.probabilities.entries.map((e) {
            final c = e.key == 'Suspicious' ? const Color(0xFFEF4444)
                : e.key == 'Benign' ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                  Text('${e.value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                ]),
                const SizedBox(height: 5),
                LayoutBuilder(builder: (ctx, con) => Stack(children: [
                  Container(height: 7, width: con.maxWidth,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                  Container(height: 7, width: con.maxWidth * (e.value / 100).clamp(0.0, 1.0),
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4)])),
                ])),
              ]),
            );
          }),
        ],
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
  final String densityClass;
  final int densityIndex;
  final double? densityConf;
  final Map<String, double> densMap;
  /// Pass the mammogram prediction so we can show the cross-analysis insight.
  final String? mammoPrediction;
  const _DensityCard({required this.isDark, required this.densityLabel, required this.densityClass,
      required this.densityIndex, required this.densityConf, required this.densMap,
      this.mammoPrediction});

  // ── What each BI-RADS density class means in plain language ──────────────
  static const _densityExplanations = {
    0: _DensityExplanation(
      headline: 'Almost entirely fatty (Density A)',
      what: 'The breast is composed almost entirely of fat. Dense tissue is minimal.',
      mammographySensitivity: 'Excellent — fatty tissue appears dark on mammograms, making any mass easy to spot.',
      cancerRisk: 'No additional density-related risk. Standard screening intervals apply.',
      color: Color(0xFF10B981),
    ),
    1: _DensityExplanation(
      headline: 'Scattered fibroglandular tissue (Density B)',
      what: 'There are scattered areas of fibroglandular tissue mixed with fat.',
      mammographySensitivity: 'Good — most masses are still visible, though a small number may be obscured.',
      cancerRisk: 'Slightly elevated compared to Density A, but still within the average-risk range.',
      color: Color(0xFF3B82F6),
    ),
    2: _DensityExplanation(
      headline: 'Heterogeneously dense tissue (Density C)',
      what: 'The breast has more dense tissue than fat. Dense tissue appears white on mammograms — the same colour as many tumours.',
      mammographySensitivity: 'Reduced — dense tissue can mask small masses, lowering mammography sensitivity by up to 30–40%.',
      cancerRisk: 'Moderately elevated. Dense tissue itself is an independent risk factor for breast cancer, separate from any current findings.',
      color: Color(0xFFF59E0B),
    ),
    3: _DensityExplanation(
      headline: 'Extremely dense tissue (Density D)',
      what: 'The breast is almost entirely composed of dense fibroglandular tissue. This is the highest density category.',
      mammographySensitivity: 'Significantly reduced — mammography alone may miss up to 40–50% of cancers in extremely dense breasts.',
      cancerRisk: 'Substantially elevated. Extremely dense tissue is one of the strongest independent risk factors for breast cancer. Supplemental imaging is strongly recommended.',
      color: Color(0xFFEF4444),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF10B981), // A
      const Color(0xFF3B82F6), // B
      const Color(0xFFF59E0B), // C
      const Color(0xFFEF4444), // D
    ];
    final idx = densityIndex.clamp(0, 3);
    final color = colors[idx];
    final densLetter = ['A', 'B', 'C', 'D'][idx];
    final explanation = _densityExplanations[idx]!;

    // Cross-analysis: Normal mammogram but high density (C or D)
    final isHighDensity = idx >= 2;
    final mammoIsNormal = mammoPrediction == 'Normal';
    final showCrossInsight = isHighDensity && mammoIsNormal;

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.density_medium_rounded, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mammogram Density', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.getTextPrimary(context))),
            Text('BI-RADS Density Classification', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(children: [
              Text('Density $densLetter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              if (densityConf != null)
                Text('${densityConf!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: color)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Density label ────────────────────────────────────────────────────
        Text(densityLabel.isNotEmpty ? densityLabel : densityClass,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 14),

        // ── Plain-language explanation ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(explanation.headline,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 10),
            _explanationRow(context, '🔬', 'What this means', explanation.what),
            const SizedBox(height: 8),
            _explanationRow(context, '📷', 'Mammography sensitivity', explanation.mammographySensitivity),
            const SizedBox(height: 8),
            _explanationRow(context, '⚠️', 'Cancer risk implication', explanation.cancerRisk),
          ]),
        ),

        // ── Cross-analysis insight (Normal mammogram + high density) ─────────
        if (showCrossInsight) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3D2F1F) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.5), width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFFF97316), size: 16),
                ),
                const SizedBox(width: 8),
                const Text('Cross-Analysis Insight',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF97316))),
              ]),
              const SizedBox(height: 10),
              Text(
                'Mammogram result: Normal  ·  Density: ${densLetter == 'C' ? 'Heterogeneously Dense (C)' : 'Extremely Dense (D)'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFFFD580) : const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No cancer is currently visible on this mammogram. However, this does NOT mean the breast is cancer-free — it means no cancer was detected with the available imaging.',
                style: TextStyle(fontSize: 12.5, height: 1.6,
                    color: isDark ? const Color(0xFFE5C97E) : const Color(0xFF78350F)),
              ),
              const SizedBox(height: 8),
              Text(
                idx == 3
                    ? 'Extremely dense tissue (Density D) can hide up to 40–50% of cancers on mammography alone. A normal mammogram result in the presence of Density D should be interpreted with caution. Supplemental MRI or whole-breast ultrasound is strongly recommended to rule out occult (hidden) lesions.'
                    : 'Heterogeneously dense tissue (Density C) can obscure small masses on mammography. A normal mammogram result in the presence of Density C may still miss early-stage lesions. Supplemental whole-breast ultrasound or MRI is recommended, especially if other risk factors are present.',
                style: TextStyle(fontSize: 12.5, height: 1.6,
                    color: isDark ? const Color(0xFFE5C97E) : const Color(0xFF78350F)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 13, color: Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Density is a risk factor for future cancer AND a limitation of mammography — both are clinically important.',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFF97316)),
                  )),
                ]),
              ),
            ]),
          ),
        ],

        // ── Class probabilities ──────────────────────────────────────────────
        if (densMap.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Class Probabilities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context))),
          const SizedBox(height: 10),
          ...densMap.entries.toList().asMap().entries.map((entry) {
            final i = entry.key.clamp(0, 3);
            final e = entry.value;
            final barColor = colors[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key.replaceAll('Density ', '').split('(').first.trim(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                  Text('${e.value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
                ]),
                const SizedBox(height: 4),
                LayoutBuilder(builder: (ctx, con) => Stack(children: [
                  Container(height: 7, width: con.maxWidth,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                  Container(height: 7, width: con.maxWidth * (e.value / 100).clamp(0.0, 1.0),
                      decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4))),
                ])),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _explanationRow(BuildContext context, String emoji, String label, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: RichText(text: TextSpan(
        children: [
          TextSpan(text: '$label: ', style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
          )),
          TextSpan(text: text, style: TextStyle(
            fontSize: 12.5, height: 1.5,
            color: AppColors.getTextSecondary(context),
          )),
        ],
      ))),
    ]);
  }
}

/// Simple data class for density explanations.
class _DensityExplanation {
  final String headline;
  final String what;
  final String mammographySensitivity;
  final String cancerRisk;
  final Color color;
  const _DensityExplanation({
    required this.headline,
    required this.what,
    required this.mammographySensitivity,
    required this.cancerRisk,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Metrics Row
// ─────────────────────────────────────────────────────────────────────────────
class _RiskMetricsRow extends StatelessWidget {
  final bool isDark;
  final double riskPct;
  final String riskLabel;
  final bool isHighRisk;
  const _RiskMetricsRow({required this.isDark, required this.riskPct, required this.riskLabel, required this.isHighRisk});

  @override
  Widget build(BuildContext context) {
    final color = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final lightColor = isHighRisk ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);

    return Row(children: [
      Expanded(child: _MetricTile(isDark: isDark, icon: Icons.emergency_rounded, label: 'Risk Level',
          value: isHighRisk ? 'High' : 'Low', sub: isHighRisk ? 'Urgent attention' : 'Routine monitoring',
          color: color, lightColor: lightColor)),
      const SizedBox(width: 12),
      Expanded(child: _MetricTile(isDark: isDark, icon: Icons.speed_rounded, label: 'Risk Score',
          value: '${riskPct.toStringAsFixed(1)}%', sub: riskLabel,
          color: color, lightColor: lightColor)),
    ]);
  }
}

class _MetricTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color lightColor;
  const _MetricTile({required this.isDark, required this.icon, required this.label,
      required this.value, required this.sub, required this.color, required this.lightColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: isDark ? color.withOpacity(0.18) : lightColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.getTextSecondary(context))),
        Text(sub, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context).withOpacity(0.7))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHAP Card
// ─────────────────────────────────────────────────────────────────────────────
class _ShapCard extends StatelessWidget {
  final bool isDark;
  final List<MapEntry<String, double>> sortedShap;
  final double baseValue;
  final int totalFeatures;
  const _ShapCard({required this.isDark, required this.sortedShap, required this.baseValue, required this.totalFeatures});

  static const _labels = {
    'age': 'Age', 'menarche': 'Age at Menarche', 'menopause': 'Menopause Age',
    'agefirst': 'Age at 1st Pregnancy', 'children': 'No. of Children',
    'breastfeeding': 'Breastfeeding', 'imc': 'BMI', 'weight': 'Weight (kg)',
    'menopause_status': 'Menopause Status', 'pregnancy': 'Pregnancy',
    'family_history': 'Family History', 'family_history_count': 'Family History Count',
    'family_history_degree': 'Family History Degree', 'exercise_regular': 'Regular Exercise',
  };

  @override
  Widget build(BuildContext context) {
    final entries = sortedShap.take(8).toList();
    final maxAbs = entries.isEmpty ? 1.0 : entries.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF8B5CF6), size: 18)),
          const SizedBox(width: 10),
          Text('SHAP — Clinical Risk Factors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1F2937))),
        ]),
        const SizedBox(height: 8),
        Text('Purple = increases risk  •  Green = decreases risk',
            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
        const SizedBox(height: 16),
        ...entries.map((entry) {
          final label = _labels[entry.key] ?? entry.key;
          final isPos = entry.value >= 0;
          final barColor = isPos ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
          final frac = maxAbs == 0 ? 0.0 : entry.value.abs() / maxAbs;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: barColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${isPos ? '+' : ''}${entry.value.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: barColor)),
                ),
              ]),
              const SizedBox(height: 5),
              LayoutBuilder(builder: (ctx, c) => Stack(children: [
                Container(height: 7, width: c.maxWidth,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                Container(height: 7, width: c.maxWidth * frac,
                    decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 4)])),
              ])),
            ]),
          );
        }),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Base value: ${baseValue.toStringAsFixed(4)}  •  Top 8 of $totalFeatures features',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation Badge
// ─────────────────────────────────────────────────────────────────────────────
class _ValidationBadge extends StatelessWidget {
  final String label;
  final bool isValid;
  final double score;
  const _ValidationBadge({required this.label, required this.isValid, required this.score});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isValid ? const Color(0xFF10B981) : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isValid ? Icons.verified_rounded : Icons.warning_amber_rounded, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(isValid ? 'Valid scan' : 'Quality warning',
            style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context))),
        Text('Score: ${score.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations Card
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationsCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final TabularPredictionResult? tabularResult;
  final UltrasoundAnalysisResult? usResult;
  final DensityAnalysisResult? densityResult;
  final MammogramAnalysisResult? mammoResult;
  const _RecommendationsCard({required this.patient, required this.tabularResult,
      required this.usResult, required this.densityResult, this.mammoResult});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recs = RecommendationEngine.generate(
      patient: patient,
      tabularResult: tabularResult,
      ultrasoundAnalysis: usResult,
      densityAnalysis: densityResult,
      mammogramAnalysis: mammoResult,
    );
    if (recs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fact_check_rounded, color: Color(0xFF10B981), size: 18)),
          const SizedBox(width: 10),
          Text('Personalized Recommendations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1F2937))),
        ]),
        const SizedBox(height: 6),
        Text('Based on AI results, risk factors, and clinical data',
            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
        const SizedBox(height: 14),
        ...recs.map((rec) {
          Color color;
          String priorityLabel;
          switch (rec.priority) {
            case RecPriority.urgent:
              color = const Color(0xFFEF4444); priorityLabel = 'URGENT'; break;
            case RecPriority.high:
              color = const Color(0xFFF59E0B); priorityLabel = 'HIGH'; break;
            case RecPriority.medium:
              color = const Color(0xFF6366F1); priorityLabel = 'MEDIUM'; break;
            case RecPriority.low:
              color = const Color(0xFF10B981); priorityLabel = 'ROUTINE'; break;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(rec.icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(rec.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                    child: Text(priorityLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(rec.detail, style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.getTextSecondary(context))),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}
