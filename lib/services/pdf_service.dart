import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'storage_service.dart';

/// Generates a PDF report and uploads it to Supabase.
/// Returns the public URL of the uploaded PDF.
class PdfService {
  /// Build and upload PDF. Returns Supabase public URL.
  static Future<String?> generateAndUpload(
      Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    final reportId = reportData['reportId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final url = await StorageService.uploadBytes(
      bytes: bytes,
      folder: 'pdfs',
      fileName: '$reportId.pdf',
      contentType: 'application/pdf',
    );
    return url;
  }

  /// Print / share the PDF directly on device.
  static Future<void> printReport(Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Share PDF via device share sheet (WhatsApp, Email, Drive, etc.)
  static Future<void> shareReport(Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    final patientName = reportData['patientName']?.toString() ?? 'Patient';
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'OncoGuide_Report_$patientName.pdf',
    );
  }

  // ── PDF builder ───────────────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final patientName  = data['patientName']?.toString() ?? 'Unknown';
    final patientAge   = (data['patientAge'] as num?)?.toInt() ?? 0;
    final riskLabel    = data['riskLabel']?.toString() ?? 'Pending';
    final riskPct      = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final usPrediction = data['usPrediction']?.toString() ?? data['prediction']?.toString();
    final usConfidence = (data['usConfidence'] as num?)?.toDouble();
    final isHighRisk   = riskLabel == 'High Risk';

    // Date
    String dateStr = 'N/A';
    final ts = data['createdAt'] ?? data['flaggedAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // SHAP values
    final shapRaw = data['shapValues'];
    Map<String, double> shapValues = {};
    if (shapRaw is Map) {
      shapValues = shapRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
    final sortedShap = shapValues.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    // US probabilities
    final probRaw = data['usProbabilities'] ?? data['probabilities'];
    Map<String, double> probs = {};
    if (probRaw is Map) {
      probs = probRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }

    const _labels = {
      'age': 'Age', 'menarche': 'Age at Menarche', 'menopause': 'Menopause Age',
      'agefirst': 'Age at 1st Pregnancy', 'children': 'No. of Children',
      'breastfeeding': 'Breastfeeding', 'imc': 'BMI', 'weight': 'Weight (kg)',
      'menopause_status': 'Menopause Status', 'pregnancy': 'Pregnancy',
      'family_history': 'Family History', 'family_history_count': 'Family History Count',
      'family_history_degree': 'Family History Degree', 'exercise_regular': 'Regular Exercise',
    };

    final riskColor = isHighRisk ? PdfColors.red700 : PdfColors.green700;
    final riskBg    = isHighRisk ? PdfColors.red50  : PdfColors.green50;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OncoGuide AI',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.pink700,
                      ),
                    ),
                    pw.Text(
                      'AI-Assisted Breast Cancer Analysis Report',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.pink200, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CONFIDENTIAL — For medical professional use only',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
        build: (ctx) => [

          // ── Patient Info ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo400,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(patientName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Age: $patientAge years', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Overall Risk ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: riskBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: riskColor, width: 1.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Overall Risk Assessment',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      riskLabel,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: riskColor),
                    ),
                  ],
                ),
                pw.Text(
                  '${riskPct.toStringAsFixed(1)}%',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: riskColor),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Ultrasound Finding ──────────────────────────────────────────
          if (usPrediction != null) ...[
            _sectionHeader('Ultrasound Analysis'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Prediction:', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                      pw.Text(
                        usPrediction,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: usPrediction == 'Malignant'
                              ? PdfColors.red700
                              : usPrediction == 'Benign'
                                  ? PdfColors.orange700
                                  : PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                  if (usConfidence != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Confidence:', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                        pw.Text('${usConfidence.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                  if (probs.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Class Probabilities:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    ...probs.entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 100, child: pw.Text(e.key, style: pw.TextStyle(fontSize: 10))),
                          pw.Expanded(
                            child: pw.LinearProgressIndicator(
                              value: e.value / 100,
                              backgroundColor: PdfColors.grey200,
                              valueColor: e.key == 'Malignant'
                                  ? PdfColors.red400
                                  : e.key == 'Benign'
                                      ? PdfColors.orange400
                                      : PdfColors.green400,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text('${e.value.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── SHAP Values ─────────────────────────────────────────────────
          if (sortedShap.isNotEmpty) ...[
            _sectionHeader('SHAP — Clinical Risk Factors'),
            pw.SizedBox(height: 4),
            pw.Text(
              'Purple = increases risk  •  Green = decreases risk',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableCell('Feature', bold: true),
                    _tableCell('SHAP Value', bold: true),
                    _tableCell('Direction', bold: true),
                  ],
                ),
                ...sortedShap.take(10).map((e) {
                  final label = _labels[e.key] ?? e.key;
                  final isPos = e.value >= 0;
                  return pw.TableRow(children: [
                    _tableCell(label),
                    _tableCell('${isPos ? '+' : ''}${e.value.toStringAsFixed(4)}',
                        color: isPos ? PdfColors.purple700 : PdfColors.green700),
                    _tableCell(isPos ? '↑ Increases Risk' : '↓ Decreases Risk',
                        color: isPos ? PdfColors.purple700 : PdfColors.green700),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Recommendations ─────────────────────────────────────────────
          _sectionHeader('Clinical Recommendations'),
          pw.SizedBox(height: 8),
          ...( isHighRisk
              ? [
                  '⚠ URGENT: Immediate biopsy confirmation is advised',
                  '⚠ HIGH: Refer to oncology specialist within 7 days',
                  '• Contrast-enhanced MRI recommended for staging',
                  '• Discuss findings in multidisciplinary tumor board',
                ]
              : [
                  '• Continue routine annual mammogram screening',
                  '• Maintain healthy lifestyle and regular exercise',
                  '• Follow up in 12 months or sooner if symptoms arise',
                ]
          ).map((rec) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(rec, style: pw.TextStyle(fontSize: 11)),
          )),
          pw.SizedBox(height: 16),

          // ── Disclaimer ──────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.amber300),
            ),
            child: pw.Text(
              'IMPORTANT: This is an AI-assisted assessment and must be reviewed and validated by a qualified medical professional before any clinical decision-making. This analysis does not replace professional medical diagnosis.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.brown700),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.pink50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(left: pw.BorderSide(color: PdfColors.pink400, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.pink800),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}
