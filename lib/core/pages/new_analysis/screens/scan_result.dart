import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/pdf_service.dart';
import 'package:oncoguide_v2/services/recommendation_engine.dart';
import '../../../widgets/resuable_top_bar.dart';
import 'new_analysis_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Priority-first result screen layout:
//  1. Patient header
//  2. Overall verdict banner (most important — high/low risk)
//  3. Ultrasound finding (if available) — benign/normal/malignant
//  4. Risk score metrics
//  5. GradCAM heatmap (visual XAI)
//  6. SHAP feature importance (tabular XAI)
//  7. Image validation badges
//  8. Uploaded scans
//  9. Clinical recommendations
// 10. Disclaimer
// ─────────────────────────────────────────────────────────────────────────────

class ScanResultPage extends StatefulWidget {
  final Map<String, dynamic> selectedPatient;
  final Map<ImagingType, File?> uploadedImages;
  final Set<ImagingType> selectedImagingTypes;
  final TabularPredictionResult? tabularResult;
  final MammogramValidationResult? mammogramValidation;
  final MammogramValidationResult? ultrasoundValidation;
  final UltrasoundAnalysisResult? ultrasoundAnalysis;
  final DensityAnalysisResult? densityAnalysis;
  final MammogramAnalysisResult? mammogramAnalysis;

  const ScanResultPage({
    super.key,
    required this.selectedPatient,
    required this.uploadedImages,
    required this.selectedImagingTypes,
    this.tabularResult,
    this.mammogramValidation,
    this.ultrasoundValidation,
    this.ultrasoundAnalysis,
    this.densityAnalysis,
    this.mammogramAnalysis,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  bool _sharing = false;

  bool get _isHighRisk => widget.tabularResult?.prediction == 1;
  double get _riskPct  => widget.tabularResult?.riskPercentage ?? 0.0;
  String get _riskLabel => widget.tabularResult?.riskLabel ?? 'Pending';

  Future<void> _shareReport() async {
    setState(() => _sharing = true);
    try {
      final reportData = {
        'patientName'    : widget.selectedPatient['name'] ?? 'Unknown',
        'patientAge'     : widget.selectedPatient['age'] ?? 0,
        'riskLabel'      : widget.tabularResult?.riskLabel ?? '',
        'riskPercentage' : widget.tabularResult?.riskPercentage ?? 0.0,
        'shapValues'     : widget.tabularResult?.shapValues ?? {},
        'baseValue'      : widget.tabularResult?.baseValue ?? 0.0,
        // Ultrasound results
        'usPrediction'   : widget.ultrasoundAnalysis?.prediction,
        'usConfidence'   : widget.ultrasoundAnalysis?.confidence,
        'usProbabilities': widget.ultrasoundAnalysis?.probabilities,
        'gradcamImage'   : widget.ultrasoundAnalysis?.gradcamImage ?? '',
        // Mammogram finding results
        'mammoPrediction'     : widget.mammogramAnalysis?.prediction,
        'mammoConfidence'     : widget.mammogramAnalysis?.confidence,
        'mammoProbabilities'  : widget.mammogramAnalysis?.probabilities,
        'mammoFindingCategory': widget.mammogramAnalysis?.findingCategory,
        // Density results
        'densityClass'        : widget.densityAnalysis?.densityClass,
        'densityLabel'        : widget.densityAnalysis?.densityLabel,
        'densityIndex'        : widget.densityAnalysis?.densityIndex,
        'densityConfidence'   : widget.densityAnalysis?.confidence,
        // Image URLs
        'mammogramUrl'   : null,
        'ultrasoundUrl'  : null,
        ...widget.selectedPatient,
      };
      await PdfService.shareReport(reportData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    final name   = widget.selectedPatient['name']?.toString() ?? 'Unknown Patient';
    final age    = (widget.selectedPatient['age'] as num?)?.toInt() ?? 0;
    final status = widget.selectedPatient['medicalHistory']?.toString() ??
        widget.selectedPatient['status']?.toString() ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: 'Analysis Report',
        subtitle: const Text('AI-Assisted Diagnosis'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      // ── Share FAB ────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sharing ? null : _shareReport,
        backgroundColor: const Color(0xFF6366F1),
        icon: _sharing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.share_rounded, color: Colors.white),
        label: Text(
          _sharing ? 'Preparing...' : 'Share Report',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. Patient header ─────────────────────────────────────────
            _PatientHeader(name: name, age: age, status: status),
            const SizedBox(height: 20),

            // ── 2. Imaging findings — HERO (mammogram + ultrasound first) ──
            if (widget.mammogramAnalysis != null) ...[
              _MammogramFindingCard(result: widget.mammogramAnalysis!),
              const SizedBox(height: 16),
            ],
            if (widget.ultrasoundAnalysis != null) ...[
              _UltrasoundFindingCard(result: widget.ultrasoundAnalysis!),
              const SizedBox(height: 16),
            ],

            // ── 3. GradCAM heatmaps — right after findings ────────────────
            if (widget.mammogramAnalysis != null && widget.mammogramAnalysis!.hasGradcam) ...[
              _MammogramGradCamCard(result: widget.mammogramAnalysis!),
              const SizedBox(height: 16),
            ],
            if (widget.ultrasoundAnalysis != null && widget.ultrasoundAnalysis!.hasGradcam) ...[
              _GradCamCard(result: widget.ultrasoundAnalysis!),
              const SizedBox(height: 16),
            ],

            // ── 4. Density analysis ───────────────────────────────────────
            if (widget.densityAnalysis != null) ...[
              _DensityCard(result: widget.densityAnalysis!),
              const SizedBox(height: 16),
            ],

            // ── 5. Clinical risk strip — compact, not dominant ────────────
            if (widget.tabularResult != null) ...[
              _RiskStrip(
                riskPct: _riskPct,
                riskLabel: _riskLabel,
                isHighRisk: _isHighRisk,
              ),
              const SizedBox(height: 16),
            ],

            // ── 6. SHAP feature importance ────────────────────────────────
            if (widget.tabularResult != null && widget.tabularResult!.shapValues.isNotEmpty) ...[
              _ShapCard(result: widget.tabularResult!),
              const SizedBox(height: 16),
            ],

            // ── 7. Image validation badges ────────────────────────────────
            if (widget.mammogramValidation != null || widget.ultrasoundValidation != null) ...[
              _ValidationBadgesRow(
                mammogramValidation: widget.mammogramValidation,
                ultrasoundValidation: widget.ultrasoundValidation,
              ),
              const SizedBox(height: 16),
            ],

            // ── 8. Uploaded scans ─────────────────────────────────────────
            if (widget.selectedImagingTypes.isNotEmpty) ...[
              _UploadedScansCard(
                selectedImagingTypes: widget.selectedImagingTypes,
                uploadedImages: widget.uploadedImages,
              ),
              const SizedBox(height: 16),
            ],

            // ── 9. Clinical recommendations ───────────────────────────────
            _PersonalizedRecommendationsCard(
              patient: widget.selectedPatient,
              tabularResult: widget.tabularResult,
              ultrasoundAnalysis: widget.ultrasoundAnalysis,
              densityAnalysis: widget.densityAnalysis,
              mammogramAnalysis: widget.mammogramAnalysis,
            ),
            const SizedBox(height: 16),

            // ── 10. Disclaimer ────────────────────────────────────────────
            _DisclaimerCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card shell
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
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
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle({required this.title, required this.icon, required this.color});

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
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Patient Header
// ─────────────────────────────────────────────────────────────────────────────
class _PatientHeader extends StatelessWidget {
  final String name;
  final int age;
  final String status;
  const _PatientHeader({required this.name, required this.age, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$age years${status.isNotEmpty ? '  •  $status' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF10B981).withOpacity(0.15)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Risk Strip — compact clinical risk row (not dominant)
// ─────────────────────────────────────────────────────────────────────────────
class _RiskStrip extends StatelessWidget {
  final double riskPct;
  final String riskLabel;
  final bool isHighRisk;

  const _RiskStrip({
    required this.riskPct,
    required this.riskLabel,
    required this.isHighRisk,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final color   = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final bgColor = isHighRisk
        ? color.withOpacity(isDark ? 0.15 : 0.07)
        : color.withOpacity(isDark ? 0.12 : 0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isHighRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Label + source note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical Risk (RF Model)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(context),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // Score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text(
              '${riskPct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Progress bar (thin)
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: riskPct / 100,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'from clinical data',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.getTextSecondary(context).withOpacity(0.6),
                  ),
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
// Low Confidence Warning — shown when AI confidence < 70%
// ─────────────────────────────────────────────────────────────────────────────
class _LowConfidenceWarning extends StatelessWidget {
  final double confidence;
  const _LowConfidenceWarning({required this.confidence});

  @override
  Widget build(BuildContext context) {
    if (confidence >= 70) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D2F1F) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Low confidence (${confidence.toStringAsFixed(0)}%). '
          'This result is below the 70% reliability threshold. '
          'Manual clinical review is strongly recommended before acting on this finding.',
          style: TextStyle(
            fontSize: 12, height: 1.5,
            color: isDark ? const Color(0xFFE5C97E) : const Color(0xFF92400E),
            fontWeight: FontWeight.w500,
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Ultrasound Finding Card
// ─────────────────────────────────────────────────────────────────────────────
class _UltrasoundFindingCard extends StatelessWidget {
  final UltrasoundAnalysisResult result;
  const _UltrasoundFindingCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color predColor;
    IconData predIcon;
    String description;

    switch (result.predictionIndex) {
      case 2:
        predColor   = const Color(0xFFEF4444);
        predIcon    = Icons.warning_rounded;
        description = 'Malignant characteristics detected in ultrasound. Immediate clinical follow-up required.';
        break;
      case 0:
        predColor   = const Color(0xFFF59E0B);
        predIcon    = Icons.info_rounded;
        description = 'Benign mass detected. Monitor and follow up as recommended by your physician.';
        break;
      default:
        predColor   = const Color(0xFF10B981);
        predIcon    = Icons.check_circle_rounded;
        description = 'No suspicious findings detected in ultrasound imaging.';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Ultrasound Finding',
            icon: Icons.waves_rounded,
            color: predColor,
          ),
          const SizedBox(height: 16),
          // Big finding row
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: predColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: predColor.withOpacity(0.4), width: 2),
                ),
                child: Icon(predIcon, color: predColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.prediction,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: predColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${result.confidence.toStringAsFixed(1)}% confidence',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          _LowConfidenceWarning(confidence: result.confidence),
          const SizedBox(height: 16),
          // Probability bars
          ...result.probabilities.entries.map((entry) {
            Color barColor;
            if (entry.key == 'Malignant') barColor = const Color(0xFFEF4444);
            else if (entry.key == 'Benign') barColor = const Color(0xFFF59E0B);
            else barColor = const Color(0xFF10B981);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(builder: (ctx, c) => Stack(children: [
                    Container(
                      height: 7,
                      width: c.maxWidth,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 7,
                      width: c.maxWidth * (entry.value / 100),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 4)],
                      ),
                    ),
                  ])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. GradCAM Card
// ─────────────────────────────────────────────────────────────────────────────
class _GradCamCard extends StatelessWidget {
  final UltrasoundAnalysisResult result;
  const _GradCamCard({required this.result});

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GradCamFullScreen(gradcamBase64: result.gradcamImage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — use Flexible to prevent overflow
          Row(
            children: [
              const Icon(Icons.thermostat_rounded, color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GradCAM — Visual Explanation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6C63FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openFullScreen(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFF6C63FF)),
                      SizedBox(width: 4),
                      Text('Zoom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Heatmap shows which regions of the ultrasound influenced the AI prediction. Tap to zoom.',
            style: TextStyle(fontSize: 12.5, color: AppColors.getTextSecondary(context), height: 1.5),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openFullScreen(context),
            child: Hero(
              tag: 'gradcam_image',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  base64Decode(result.gradcamImage),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              _legendDot('Low', const Color(0xFF0000FF)),
              _legendDot('Medium', const Color(0xFF00FF00)),
              _legendDot('High', const Color(0xFFFF0000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3b. Mammogram Finding Card
// ─────────────────────────────────────────────────────────────────────────────
class _MammogramFindingCard extends StatelessWidget {
  final MammogramAnalysisResult result;
  const _MammogramFindingCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color predColor;
    IconData predIcon;
    switch (result.predictionIndex) {
      case 2: // Suspicious
        predColor = const Color(0xFFEF4444);
        predIcon  = Icons.warning_rounded;
        break;
      case 1: // Benign
        predColor = const Color(0xFFF59E0B);
        predIcon  = Icons.info_rounded;
        break;
      default: // Normal
        predColor = const Color(0xFF10B981);
        predIcon  = Icons.check_circle_rounded;
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Mammogram Finding',
            icon: Icons.monitor_heart_rounded,
            color: predColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.prediction,
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900,
                        color: predColor, letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${result.confidence.toStringAsFixed(1)}% confidence',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (result.findingCategory.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: predColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.findingCategory,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: predColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: predColor.withOpacity(isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: predColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: predColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.clinicalNote,
                    style: TextStyle(
                      fontSize: 13, height: 1.5,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _LowConfidenceWarning(confidence: result.confidence),
          const SizedBox(height: 16),
          // Probability bars
          ...result.probabilities.entries.map((entry) {
            Color barColor;
            if (entry.key == 'Suspicious') barColor = const Color(0xFFEF4444);
            else if (entry.key == 'Benign') barColor = const Color(0xFFF59E0B);
            else barColor = const Color(0xFF10B981);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context))),
                      Text('${entry.value.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: barColor)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(builder: (ctx, c) => Stack(children: [
                    Container(height: 7, width: c.maxWidth,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        )),
                    Container(height: 7,
                        width: c.maxWidth * (entry.value / 100).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: barColor, borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 4)],
                        )),
                  ])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5b. Mammogram GradCAM Card
// ─────────────────────────────────────────────────────────────────────────────
class _MammogramGradCamCard extends StatelessWidget {
  final MammogramAnalysisResult result;
  const _MammogramGradCamCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.thermostat_rounded, color: Color(0xFFFF6F91), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GradCAM — Mammogram Region',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFF6F91)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _GradCamFullScreen(gradcamBase64: result.gradcamImage),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6F91).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF6F91).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFFFF6F91)),
                      SizedBox(width: 4),
                      Text('Zoom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFF6F91))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Highlighted regions show where the AI detected suspicious patterns in the mammogram.',
            style: TextStyle(fontSize: 12.5, color: AppColors.getTextSecondary(context), height: 1.5),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _GradCamFullScreen(gradcamBase64: result.gradcamImage),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                base64Decode(result.gradcamImage),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              _legendDot('Low', const Color(0xFF0000FF)),
              _legendDot('Medium', const Color(0xFF00FF00)),
              _legendDot('High', const Color(0xFFFF0000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5c. Density Card
// ─────────────────────────────────────────────────────────────────────────────
class _DensityCard extends StatelessWidget {
  final DensityAnalysisResult result;
  const _DensityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Color per density class
    final colors = [
      const Color(0xFF10B981), // A — green (fatty, best)
      const Color(0xFF3B82F6), // B — blue (scattered)
      const Color(0xFFF59E0B), // C — amber (heterogeneous)
      const Color(0xFFEF4444), // D — red (extremely dense)
    ];
    final color = colors[result.densityIndex.clamp(0, 3)];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.density_medium_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mammogram Density',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'BI-RADS Density Classification',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Density badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Density ${['A','B','C','D'][result.densityIndex.clamp(0,3)]}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      '${result.confidence.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Full class name
          Text(
            result.densityClass,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),

          // Clinical note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.clinicalNote,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _LowConfidenceWarning(confidence: result.confidence),
          const SizedBox(height: 16),

          // Probability bars
          Text(
            'Class Probabilities',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          ...result.probabilities.entries.map((e) {
            final barColor = colors[result.probabilities.keys.toList().indexOf(e.key).clamp(0, 3)];
            final pct = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key.replaceAll('Density ', '').split('(').first.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (ctx, con) => Stack(
                      children: [
                        Container(
                          height: 7,
                          width: con.maxWidth,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 7,
                          width: con.maxWidth * (pct / 100).clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          // GradCAM heatmap (CC view)
          if (result.hasGradcam) ...[
            const SizedBox(height: 16),
            Text(
              'Density Heatmap (CC View)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Warm areas show regions that most influenced the density classification.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _GradCamFullScreen(
                    gradcamBase64: result.gradcamImage,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uri.parse('data:image/png;base64,${result.gradcamImage}')
                      .data!
                      .contentAsBytes(),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 80,
                    child: Center(child: Icon(Icons.broken_image_rounded)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradCAM Full Screen Viewer
// ─────────────────────────────────────────────────────────────────────────────
class _GradCamFullScreen extends StatefulWidget {
  final String gradcamBase64;
  const _GradCamFullScreen({required this.gradcamBase64});

  @override
  State<_GradCamFullScreen> createState() => _GradCamFullScreenState();
}

class _GradCamFullScreenState extends State<_GradCamFullScreen> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('GradCAM Heatmap', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reset zoom',
            onPressed: () => _controller.value = Matrix4.identity(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full screen interactive image
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.8,
              maxScale: 8.0,
              child: Hero(
                tag: 'gradcam_image',
                child: Image.memory(
                  base64Decode(widget.gradcamBase64),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          // Bottom legend overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot('Low', const Color(0xFF0000FF)),
                      const SizedBox(width: 20),
                      _dot('Medium', const Color(0xFF00FF00)),
                      const SizedBox(width: 20),
                      _dot('High', const Color(0xFFFF0000)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pinch to zoom  •  Drag to pan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. SHAP Card
// ─────────────────────────────────────────────────────────────────────────────
class _ShapCard extends StatelessWidget {
  final TabularPredictionResult result;
  const _ShapCard({required this.result});

  static const _labels = {
    'age': 'Age',
    'menarche': 'Age at Menarche',
    'menopause': 'Menopause Age',
    'agefirst': 'Age at 1st Pregnancy',
    'children': 'No. of Children',
    'breastfeeding': 'Breastfeeding',
    'imc': 'BMI',
    'weight': 'Weight (kg)',
    'menopause_status': 'Menopause Status',
    'pregnancy': 'Pregnancy',
    'family_history': 'Family History',
    'family_history_count': 'Family History Count',
    'family_history_degree': 'Family History Degree',
    'exercise_regular': 'Regular Exercise',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = result.sortedShapEntries.take(8).toList();
    final maxAbs = entries.isEmpty
        ? 1.0
        : entries.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'SHAP — Clinical Risk Factors',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 8),
          Text(
            'Purple = increases risk  •  Green = decreases risk',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final label = _labels[entry.key] ?? entry.key;
            final value = entry.value;
            final isPos = value >= 0;
            final barColor = isPos ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
            final frac = maxAbs == 0 ? 0.0 : value.abs() / maxAbs;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: barColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${isPos ? '+' : ''}${value.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(builder: (ctx, c) => Stack(children: [
                    Container(
                      height: 7,
                      width: c.maxWidth,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 7,
                      width: c.maxWidth * frac,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 4)],
                      ),
                    ),
                  ])),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Base value: ${result.baseValue.toStringAsFixed(4)}  •  Top 8 of ${result.shapValues.length} features',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
// 7. Validation Badges Row
// ─────────────────────────────────────────────────────────────────────────────
class _ValidationBadgesRow extends StatelessWidget {
  final MammogramValidationResult? mammogramValidation;
  final MammogramValidationResult? ultrasoundValidation;
  const _ValidationBadgesRow({this.mammogramValidation, this.ultrasoundValidation});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Image Quality Check',
            icon: Icons.shield_rounded,
            color: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (mammogramValidation != null)
                Expanded(
                  child: _ValidationBadge(
                    label: 'Mammogram',
                    isValid: mammogramValidation!.isValid,
                    score: mammogramValidation!.score * 100,
                  ),
                ),
              if (mammogramValidation != null && ultrasoundValidation != null)
                const SizedBox(width: 12),
              if (ultrasoundValidation != null)
                Expanded(
                  child: _ValidationBadge(
                    label: 'Ultrasound',
                    isValid: ultrasoundValidation!.isValid,
                    score: ultrasoundValidation!.score * 100,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isValid ? 'Valid scan' : 'Quality warning',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          Text(
            'Score: ${score.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
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
// 8. Uploaded Scans Card
// ─────────────────────────────────────────────────────────────────────────────
class _UploadedScansCard extends StatelessWidget {
  final Set<ImagingType> selectedImagingTypes;
  final Map<ImagingType, File?> uploadedImages;
  const _UploadedScansCard({required this.selectedImagingTypes, required this.uploadedImages});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Uploaded Scans',
            icon: Icons.medical_information_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 14),
          ...selectedImagingTypes.map((type) {
            final file = uploadedImages[type];
            if (file == null) return const SizedBox.shrink();
            final label = type == ImagingType.mammogram ? 'Mammogram' : 'Ultrasound';
            final icon  = type == ImagingType.mammogram
                ? Icons.monitor_heart_outlined
                : Icons.waves_outlined;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 15, color: const Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
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

// ─────────────────────────────────────────────────────────────────────────────
// 9. Personalized Recommendations Card (engine-driven)
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalizedRecommendationsCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final TabularPredictionResult? tabularResult;
  final UltrasoundAnalysisResult? ultrasoundAnalysis;
  final DensityAnalysisResult? densityAnalysis;
  final MammogramAnalysisResult? mammogramAnalysis;

  const _PersonalizedRecommendationsCard({
    required this.patient,
    required this.tabularResult,
    required this.ultrasoundAnalysis,
    this.densityAnalysis,
    this.mammogramAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final recs = RecommendationEngine.generate(
      patient: patient,
      tabularResult: tabularResult,
      ultrasoundAnalysis: ultrasoundAnalysis,
      densityAnalysis: densityAnalysis,
      mammogramAnalysis: mammogramAnalysis,
    );

    if (recs.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Personalized Recommendations',
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 6),
          Text(
            'Based on your AI results, risk factors, and clinical data',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          ...recs.map((rec) => _RecTileWidget(rec: rec)),
        ],
      ),
    );
  }
}

class _RecTileWidget extends StatelessWidget {
  final Recommendation rec;
  const _RecTileWidget({required this.rec});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    String priorityLabel;
    switch (rec.priority) {
      case RecPriority.urgent:
        priorityLabel = 'URGENT';
        break;
      case RecPriority.high:
        priorityLabel = 'HIGH';
        break;
      case RecPriority.medium:
        priorityLabel = 'MEDIUM';
        break;
      case RecPriority.low:
        priorityLabel = 'ROUTINE';
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
          // Emoji icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(rec.icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rec.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        priorityLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rec.detail,
                  style: TextStyle(
                    fontSize: 12.5,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. Disclaimer Card
// ─────────────────────────────────────────────────────────────────────────────
class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D2F1F) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFBBF24).withOpacity(isDark ? 0.3 : 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Medical Notice',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This is an AI-assisted assessment and must be reviewed by a qualified medical professional before any clinical decision-making. It does not replace professional medical diagnosis.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: isDark ? const Color(0xFFB0B3C5) : Colors.brown[700],
                  ),
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
// Enums (kept for backward compat)
// ─────────────────────────────────────────────────────────────────────────────
enum RecommendationPriority { urgent, high, medium }
