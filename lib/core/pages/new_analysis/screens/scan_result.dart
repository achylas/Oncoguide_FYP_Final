import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/api_service.dart';
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

class ScanResultPage extends StatelessWidget {
  final Map<String, dynamic> selectedPatient;
  final Map<ImagingType, File?> uploadedImages;
  final Set<ImagingType> selectedImagingTypes;
  final TabularPredictionResult? tabularResult;
  final MammogramValidationResult? mammogramValidation;
  final MammogramValidationResult? ultrasoundValidation;
  final UltrasoundAnalysisResult? ultrasoundAnalysis;

  const ScanResultPage({
    super.key,
    required this.selectedPatient,
    required this.uploadedImages,
    required this.selectedImagingTypes,
    this.tabularResult,
    this.mammogramValidation,
    this.ultrasoundValidation,
    this.ultrasoundAnalysis,
  });

  // ── Derived values ──────────────────────────────────────────────────────────
  bool get _isHighRisk => tabularResult?.prediction == 1;
  double get _riskPct  => tabularResult?.riskPercentage ?? 0.0;
  String get _riskLabel => tabularResult?.riskLabel ?? 'Pending';

  String get _overallVerdict {
    if (tabularResult == null) return 'Analysis Pending';
    if (_isHighRisk) return 'High Risk Detected';
    return 'Low Risk';
  }

  Color _verdictColor(bool isDark) =>
      _isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);

  String _getScanTypeLabel() {
    if (selectedImagingTypes.length > 1) return 'Multi-modal';
    if (selectedImagingTypes.isEmpty) return 'Clinical Data';
    return selectedImagingTypes.first == ImagingType.mammogram
        ? 'Mammogram'
        : 'Ultrasound';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    final name   = selectedPatient['name']?.toString() ?? 'Unknown Patient';
    final age    = (selectedPatient['age'] as num?)?.toInt() ?? 0;
    final status = selectedPatient['medicalHistory']?.toString() ??
        selectedPatient['status']?.toString() ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: 'Analysis Report',
        subtitle: const Text('AI-Assisted Diagnosis'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. Patient header ─────────────────────────────────────────
            _PatientHeader(name: name, age: age, status: status),
            const SizedBox(height: 20),

            // ── 2. Overall verdict banner ─────────────────────────────────
            _VerdictBanner(
              isHighRisk: _isHighRisk,
              verdict: _overallVerdict,
              riskPct: _riskPct,
              scanType: _getScanTypeLabel(),
              hasPendingResult: tabularResult == null,
            ),
            const SizedBox(height: 20),

            // ── 3. Ultrasound finding (if available) ──────────────────────
            if (ultrasoundAnalysis != null) ...[
              _UltrasoundFindingCard(result: ultrasoundAnalysis!),
              const SizedBox(height: 20),
            ],

            // ── 4. Risk score metrics ─────────────────────────────────────
            if (tabularResult != null) ...[
              _RiskMetricsRow(
                riskPct: _riskPct,
                riskLabel: _riskLabel,
                isHighRisk: _isHighRisk,
              ),
              const SizedBox(height: 20),
            ],

            // ── 5. GradCAM heatmap ────────────────────────────────────────
            if (ultrasoundAnalysis != null && ultrasoundAnalysis!.hasGradcam) ...[
              _GradCamCard(result: ultrasoundAnalysis!),
              const SizedBox(height: 20),
            ],

            // ── 6. SHAP feature importance ────────────────────────────────
            if (tabularResult != null && tabularResult!.shapValues.isNotEmpty) ...[
              _ShapCard(result: tabularResult!),
              const SizedBox(height: 20),
            ],

            // ── 7. Image validation badges ────────────────────────────────
            if (mammogramValidation != null || ultrasoundValidation != null) ...[
              _ValidationBadgesRow(
                mammogramValidation: mammogramValidation,
                ultrasoundValidation: ultrasoundValidation,
              ),
              const SizedBox(height: 20),
            ],

            // ── 8. Uploaded scans ─────────────────────────────────────────
            if (selectedImagingTypes.isNotEmpty) ...[
              _UploadedScansCard(
                selectedImagingTypes: selectedImagingTypes,
                uploadedImages: uploadedImages,
              ),
              const SizedBox(height: 20),
            ],

            // ── 9. Clinical recommendations ───────────────────────────────
            _RecommendationsCard(isHighRisk: _isHighRisk),
            const SizedBox(height: 20),

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
// 2. Verdict Banner
// ─────────────────────────────────────────────────────────────────────────────
class _VerdictBanner extends StatelessWidget {
  final bool isHighRisk;
  final String verdict;
  final double riskPct;
  final String scanType;
  final bool hasPendingResult;

  const _VerdictBanner({
    required this.isHighRisk,
    required this.verdict,
    required this.riskPct,
    required this.scanType,
    required this.hasPendingResult,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = isHighRisk ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final c2 = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c1.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isHighRisk ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI-Assisted Diagnosis',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            verdict,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          if (!hasPendingResult) ...[
            const SizedBox(height: 14),
            // Risk percentage bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Risk Score',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${riskPct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: riskPct / 100,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                _chip(Icons.device_hub_rounded, scanType),
                _chip(Icons.analytics_outlined, 'Random Forest Model'),
              ],
            ),
          ],
        ],
      ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
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
// 4. Risk Metrics Row
// ─────────────────────────────────────────────────────────────────────────────
class _RiskMetricsRow extends StatelessWidget {
  final double riskPct;
  final String riskLabel;
  final bool isHighRisk;
  const _RiskMetricsRow({required this.riskPct, required this.riskLabel, required this.isHighRisk});

  @override
  Widget build(BuildContext context) {
    final color = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final lightColor = isHighRisk ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.emergency_rounded,
            label: 'Risk Level',
            value: isHighRisk ? 'High' : 'Low',
            sub: isHighRisk ? 'Urgent attention' : 'Routine monitoring',
            color: color,
            lightColor: lightColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.speed_rounded,
            label: 'Risk Score',
            value: '${riskPct.toStringAsFixed(1)}%',
            sub: riskLabel,
            color: color,
            lightColor: lightColor,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color lightColor;
  const _MetricTile({
    required this.icon, required this.label, required this.value,
    required this.sub, required this.color, required this.lightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.18) : lightColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextSecondary(context).withOpacity(0.7),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'GradCAM — Visual Explanation',
            icon: Icons.thermostat_rounded,
            color: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 8),
          Text(
            'Heatmap shows which regions of the ultrasound influenced the AI prediction. Red/warm areas = high attention.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.getTextSecondary(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              base64Decode(result.gradcamImage),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot('Low', const Color(0xFF0000FF)),
              const SizedBox(width: 16),
              _legendDot('Medium', const Color(0xFF00FF00)),
              const SizedBox(width: 16),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
// 9. Recommendations Card
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationsCard extends StatelessWidget {
  final bool isHighRisk;
  const _RecommendationsCard({required this.isHighRisk});

  @override
  Widget build(BuildContext context) {
    final items = isHighRisk
        ? [
            _RecItem('Immediate biopsy confirmation is advised', _RecLevel.urgent),
            _RecItem('Refer to oncology specialist within 7 days', _RecLevel.high),
            _RecItem('Contrast-enhanced MRI recommended for staging', _RecLevel.medium),
            _RecItem('Discuss findings in multidisciplinary tumor board', _RecLevel.medium),
          ]
        : [
            _RecItem('Continue routine annual mammogram screening', _RecLevel.medium),
            _RecItem('Maintain healthy lifestyle and regular exercise', _RecLevel.medium),
            _RecItem('Follow up in 12 months or sooner if symptoms arise', _RecLevel.medium),
          ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Clinical Recommendations',
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _RecTile(item: item)),
        ],
      ),
    );
  }
}

enum _RecLevel { urgent, high, medium }

class _RecItem {
  final String text;
  final _RecLevel level;
  const _RecItem(this.text, this.level);
}

class _RecTile extends StatelessWidget {
  final _RecItem item;
  const _RecTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    IconData icon;
    String badge;

    switch (item.level) {
      case _RecLevel.urgent:
        color = const Color(0xFFEF4444); icon = Icons.emergency; badge = 'URGENT';
        break;
      case _RecLevel.high:
        color = const Color(0xFFF59E0B); icon = Icons.priority_high; badge = 'HIGH';
        break;
      default:
        color = const Color(0xFF10B981); icon = Icons.check_circle_outline; badge = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (badge.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
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
