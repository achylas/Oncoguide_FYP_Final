import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/pdf_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/resuable_top_bar.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportDetailScreen({super.key, required this.reportData});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _savingPdf = false;
  String? _pdfUrl;

  @override
  void initState() {
    super.initState();
    _pdfUrl = widget.reportData['pdfUrl']?.toString();
  }

  Future<void> _saveAsPdf() async {
    setState(() => _savingPdf = true);
    try {
      final url = await PdfService.generateAndUpload(widget.reportData);
      if (url != null) {
        // Save PDF URL back to Firestore
        final docId = widget.reportData['id']?.toString();
        final type  = widget.reportData['type']?.toString();
        if (docId != null && type != null) {
          final collection = type == 'mammogram'
              ? 'mammogram_reports'
              : 'ultrasound_reports';
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(docId)
              .update({'pdfUrl': url});
        }
        setState(() => _pdfUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF saved successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8);

    final patientName   = widget.reportData['patientName']?.toString() ?? 'Unknown';
    final patientAge    = (widget.reportData['patientAge'] as num?)?.toInt() ?? 0;
    final riskLabel     = widget.reportData['riskLabel']?.toString() ?? 'Pending';
    final riskPct       = (widget.reportData['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final usPrediction  = widget.reportData['usPrediction']?.toString();
    final usConfidence  = (widget.reportData['usConfidence'] as num?)?.toDouble();
    final mammogramUrl  = widget.reportData['mammogramUrl']?.toString();
    final ultrasoundUrl = widget.reportData['ultrasoundUrl']?.toString();
    final gradcamUrl    = widget.reportData['gradcamUrl']?.toString();
    final isHighRisk    = riskLabel == 'High Risk';
    final riskColor     = isHighRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    // SHAP values
    final shapRaw = widget.reportData['shapValues'];
    Map<String, double> shapValues = {};
    if (shapRaw is Map) {
      shapValues = shapRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
    final sortedShap = shapValues.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    // US probabilities
    final probRaw = widget.reportData['usProbabilities'];
    Map<String, double> probs = {};
    if (probRaw is Map) {
      probs = probRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: ReusableTopBar(
        title: 'Report Detail',
        subtitle: Text(patientName),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── PDF Action Buttons ────────────────────────────────────────
            _card(
              isDark: isDark,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _savingPdf ? null : _saveAsPdf,
                      icon: _savingPdf
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_alt_rounded, size: 18),
                      label: Text(_savingPdf ? 'Saving...' : _pdfUrl != null ? 'Re-save PDF' : 'Save as PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => PdfService.shareReport(widget.reportData),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Report'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PDF saved link
            if (_pdfUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PDF saved to cloud storage',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Patient + Risk banner ─────────────────────────────────────
            _card(
              isDark: isDark,
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(context))),
                        Text('$patientAge years', style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: riskColor.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Text('${riskPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: riskColor)),
                        Text(riskLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: riskColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Ultrasound finding ────────────────────────────────────────
            if (usPrediction != null) ...[
              _sectionCard(
                isDark: isDark,
                title: 'Ultrasound Finding',
                icon: Icons.waves_rounded,
                iconColor: const Color(0xFF6C63FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usPrediction,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: usPrediction == 'Malignant'
                            ? const Color(0xFFEF4444)
                            : usPrediction == 'Benign'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                      ),
                    ),
                    if (usConfidence != null)
                      Text(
                        'Confidence: ${usConfidence.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                      ),
                    if (probs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...probs.entries.map((e) {
                        Color c = e.key == 'Malignant'
                            ? const Color(0xFFEF4444)
                            : e.key == 'Benign'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                                  Text('${e.value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LayoutBuilder(builder: (ctx, con) => Stack(children: [
                                Container(height: 7, width: con.maxWidth, decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                                Container(height: 7, width: con.maxWidth * (e.value / 100), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                              ])),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── GradCAM ───────────────────────────────────────────────────
            if (gradcamUrl != null) ...[
              _sectionCard(
                isDark: isDark,
                title: 'GradCAM Heatmap',
                icon: Icons.thermostat_rounded,
                iconColor: const Color(0xFF6C63FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Red/warm areas = regions the model focused on.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.getTextSecondary(context), height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        gradcamUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) => progress == null
                            ? child
                            : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Icon(Icons.broken_image_rounded))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── SHAP values ───────────────────────────────────────────────
            if (shapValues.isNotEmpty) ...[
              _sectionCard(
                isDark: isDark,
                title: 'SHAP — Risk Factors',
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF8B5CF6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purple = increases risk  •  Green = decreases risk',
                      style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)),
                    ),
                    const SizedBox(height: 12),
                    ...sortedShap.take(8).map((entry) {
                      const labels = {
                        'age': 'Age', 'menarche': 'Age at Menarche', 'menopause': 'Menopause Age',
                        'agefirst': 'Age at 1st Pregnancy', 'children': 'No. of Children',
                        'breastfeeding': 'Breastfeeding', 'imc': 'BMI', 'weight': 'Weight (kg)',
                        'menopause_status': 'Menopause Status', 'pregnancy': 'Pregnancy',
                        'family_history': 'Family History', 'family_history_count': 'Family History Count',
                        'family_history_degree': 'Family History Degree', 'exercise_regular': 'Regular Exercise',
                      };
                      final label = labels[entry.key] ?? entry.key;
                      final isPos = entry.value >= 0;
                      final barColor = isPos ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
                      final maxAbs = sortedShap.isEmpty ? 1.0 : sortedShap.first.value.abs();
                      final frac = maxAbs == 0 ? 0.0 : entry.value.abs() / maxAbs;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: barColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                                  child: Text('${isPos ? '+' : ''}${entry.value.toStringAsFixed(4)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: barColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LayoutBuilder(builder: (ctx, con) => Stack(children: [
                              Container(height: 7, width: con.maxWidth, decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2D47) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                              Container(height: 7, width: con.maxWidth * frac, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4))),
                            ])),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Scan images ───────────────────────────────────────────────
            if (mammogramUrl != null || ultrasoundUrl != null) ...[
              _sectionCard(
                isDark: isDark,
                title: 'Uploaded Scans',
                icon: Icons.medical_information_rounded,
                iconColor: const Color(0xFF8B5CF6),
                child: Column(
                  children: [
                    if (mammogramUrl != null) ...[
                      _scanImage(context, 'Mammogram', Icons.monitor_heart_outlined, mammogramUrl),
                      const SizedBox(height: 12),
                    ],
                    if (ultrasoundUrl != null)
                      _scanImage(context, 'Ultrasound', Icons.waves_outlined, ultrasoundUrl),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Disclaimer ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3D2F1F) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This is an AI-assisted report. Must be reviewed by a qualified medical professional before any clinical decision.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? const Color(0xFFB0B3C5) : Colors.brown[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanImage(BuildContext context, String label, IconData icon, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
            errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Icon(Icons.broken_image_rounded))),
          ),
        ),
      ],
    );
  }

  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1F2937))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
