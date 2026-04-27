import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'recommendation_engine.dart';

class PdfService {
  // ── Safe numeric helper ────────────────────────────────────────────────────
  static double _safeD(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generate PDF, upload to Supabase, return public URL.
  static Future<String?> generateAndUpload(Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    final reportId = reportData['reportId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    return StorageService.uploadBytes(
      bytes: bytes,
      folder: 'pdfs',
      fileName: '$reportId.pdf',
      contentType: 'application/pdf',
    );
  }

  /// Save PDF to temp file and open device share sheet.
  static Future<void> shareReport(Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    final patientName = (reportData['patientName']?.toString() ?? 'Patient')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    final fileName = 'OncoGuide_Report_$patientName.pdf';

    // Save to temp directory
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Share via share_plus v7
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'OncoGuide AI Report - $patientName',
      text: 'AI-assisted breast cancer analysis report for $patientName.',
    );
  }

  /// Print via system print dialog.
  static Future<void> printReport(Map<String, dynamic> reportData) async {
    final bytes = await _buildPdf(reportData);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ── PDF builder ────────────────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    // Load a Unicode-capable font from Google Fonts
    final ttf     = await PdfGoogleFonts.nunitoRegular();
    final ttfBold = await PdfGoogleFonts.nunitoBold();

    final pdf = pw.Document();

    // ── Extract data ──────────────────────────────────────────────────────────
    final patientName  = data['patientName']?.toString() ?? 'Unknown';
    final patientAge   = (data['patientAge'] as num?)?.toInt() ?? 0;
    final riskLabel    = data['riskLabel']?.toString() ?? 'Pending';
    final riskPct      = (data['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final usPrediction = data['usPrediction']?.toString();
    final usConfidence = (data['usConfidence'] as num?)?.toDouble();
    final isHighRisk   = riskLabel == 'High Risk';
    final riskColor    = isHighRisk ? PdfColors.red700 : PdfColors.green700;
    final riskBg       = isHighRisk ? PdfColors.red50  : PdfColors.green50;

    // Image data
    final gradcamBase64  = data['gradcamImage']?.toString();   // base64 from analysis
    final gradcamUrl     = data['gradcamUrl']?.toString();     // Supabase URL from saved report
    final mammogramUrl   = data['mammogramUrl']?.toString();
    final ultrasoundUrl  = data['ultrasoundUrl']?.toString();

    // Load images for PDF
    pw.MemoryImage? gradcamPdfImage;
    pw.MemoryImage? mammogramPdfImage;
    pw.MemoryImage? ultrasoundPdfImage;

    // GradCAM — prefer base64 (fresh analysis), fallback to URL
    if (gradcamBase64 != null && gradcamBase64.isNotEmpty) {
      try {
        gradcamPdfImage = pw.MemoryImage(base64Decode(gradcamBase64));
      } catch (_) {}
    } else if (gradcamUrl != null && gradcamUrl.isNotEmpty) {
      try {
        final response = await _fetchImageBytes(gradcamUrl);
        if (response != null) gradcamPdfImage = pw.MemoryImage(response);
      } catch (_) {}
    }

    // Mammogram image
    if (mammogramUrl != null && mammogramUrl.isNotEmpty) {
      try {
        final response = await _fetchImageBytes(mammogramUrl);
        if (response != null) mammogramPdfImage = pw.MemoryImage(response);
      } catch (_) {}
    }

    // Ultrasound image
    if (ultrasoundUrl != null && ultrasoundUrl.isNotEmpty) {
      try {
        final response = await _fetchImageBytes(ultrasoundUrl);
        if (response != null) ultrasoundPdfImage = pw.MemoryImage(response);
      } catch (_) {}
    }

    // Date
    String dateStr = 'N/A';
    final ts = data['createdAt'] ?? data['flaggedAt'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }

    // SHAP
    final shapRaw = data['shapValues'];
    Map<String, double> shapValues = {};
    if (shapRaw is Map) {
      shapValues = Map.fromEntries(shapRaw.entries
          .where((e) => e.value is num || e.value is String)
          .map((e) => MapEntry(e.key.toString(), _safeD(e.value))));
    }
    final sortedShap = shapValues.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    // US probabilities
    final probRaw = data['usProbabilities'] ?? data['probabilities'];
    Map<String, double> probs = {};
    if (probRaw is Map) {
      probs = Map.fromEntries(probRaw.entries
          .where((e) => e.value is num || e.value is String)
          .map((e) => MapEntry(e.key.toString(), _safeD(e.value))));
    }

    // Recommendations (engine-generated, no emojis in PDF)
    TabularPredictionResult? tabResult;
    UltrasoundAnalysisResult? usResult;
    if (riskLabel.isNotEmpty && riskLabel != 'Pending') {
      tabResult = TabularPredictionResult(
        prediction: isHighRisk ? 1 : 0,
        probability: riskPct / 100,
        riskLabel: riskLabel,
        riskPercentage: riskPct,
        shapValues: shapValues,
        baseValue: _safeD(data['baseValue']),
      );
    }
    if (usPrediction != null) {
      usResult = UltrasoundAnalysisResult(
        prediction: usPrediction,
        predictionIndex: usPrediction == 'Malignant' ? 2 : usPrediction == 'Benign' ? 0 : 1,
        confidence: usConfidence ?? 0.0,
        probabilities: {},
        gradcamImage: '',
      );
    }

    // Reconstruct density result from saved Firestore fields (if present)
    DensityAnalysisResult? densityResult;
    final densityIndexRaw = data['densityIndex'];
    final densityIndex    = densityIndexRaw is num ? densityIndexRaw.toInt() : null;
    final densityClass    = data['densityClass'] as String?;
    final densityLabel    = data['densityLabel'] as String?;
    final densityConf     = _safeD(data['densityConfidence']);
    if (densityIndex != null && densityClass != null && densityLabel != null) {
      final densityProbRaw = data['densityProbabilities'];
      final densityProbs = densityProbRaw is Map
          ? Map<String, double>.fromEntries(densityProbRaw.entries
              .where((e) => e.value is num || e.value is String)
              .map((e) => MapEntry(e.key.toString(), _safeD(e.value))))
          : <String, double>{};
      densityResult = DensityAnalysisResult(
        densityClass: densityClass,
        densityLabel: densityLabel,
        densityIndex: densityIndex,
        confidence: densityConf,
        probabilities: densityProbs,
        gradcamImage: '',
      );
    }

    final recs = RecommendationEngine.generate(
      patient: data,
      tabularResult: tabResult,
      ultrasoundAnalysis: usResult,
      densityAnalysis: densityResult,
    );

    // ── Shared text styles ────────────────────────────────────────────────────
    pw.TextStyle body(double size, {PdfColor? color, bool bold = false}) =>
        pw.TextStyle(font: bold ? ttfBold : ttf, fontSize: size, color: color);

    // ── Build page ────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('OncoGuide AI', style: body(20, color: PdfColors.pink700, bold: true)),
                    pw.Text('AI-Assisted Breast Cancer Analysis Report', style: body(10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Text(dateStr, style: body(9, color: PdfColors.grey500)),
              ],
            ),
            pw.Divider(color: PdfColors.pink200, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CONFIDENTIAL - For medical professional use only', style: body(8, color: PdfColors.grey500)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: body(8, color: PdfColors.grey500)),
          ],
        ),
        build: (ctx) => [

          // Patient info
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: pw.BoxDecoration(color: PdfColors.indigo400, borderRadius: pw.BorderRadius.circular(10)),
                  child: pw.Center(child: pw.Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                    style: body(22, color: PdfColors.white, bold: true),
                  )),
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(patientName, style: body(16, bold: true)),
                    pw.Text('Age: $patientAge years', style: body(11, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Risk banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: riskBg,
              border: pw.Border.all(color: riskColor, width: 1.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Overall Risk Assessment', style: body(11, color: PdfColors.grey600)),
                    pw.Text(riskLabel, style: body(20, color: riskColor, bold: true)),
                  ],
                ),
                pw.Text('${riskPct.toStringAsFixed(1)}%', style: body(28, color: riskColor, bold: true)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Ultrasound finding
          if (usPrediction != null) ...[
            _sectionHeader('Ultrasound Analysis', ttfBold),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Prediction:', style: body(11, color: PdfColors.grey600)),
                      pw.Text(
                        usPrediction,
                        style: body(14, bold: true, color: usPrediction == 'Malignant' ? PdfColors.red700 : usPrediction == 'Benign' ? PdfColors.orange700 : PdfColors.green700),
                      ),
                    ],
                  ),
                  if (usConfidence != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Confidence:', style: body(11, color: PdfColors.grey600)),
                        pw.Text('${usConfidence.toStringAsFixed(1)}%', style: body(11, bold: true)),
                      ],
                    ),
                  ],
                  if (probs.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Class Probabilities:', style: body(10, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    ...probs.entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 100, child: pw.Text(e.key, style: body(10))),
                          pw.Expanded(child: pw.LinearProgressIndicator(
                            value: e.value / 100,
                            backgroundColor: PdfColors.grey200,
                            valueColor: e.key == 'Malignant' ? PdfColors.red400 : e.key == 'Benign' ? PdfColors.orange400 : PdfColors.green400,
                          )),
                          pw.SizedBox(width: 8),
                          pw.Text('${e.value.toStringAsFixed(1)}%', style: body(10, bold: true)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // SHAP table
          if (sortedShap.isNotEmpty) ...[
            _sectionHeader('SHAP - Clinical Risk Factors', ttfBold),
            pw.SizedBox(height: 4),
            pw.Text('Positive = increases risk  |  Negative = decreases risk', style: body(9, color: PdfColors.grey500)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _cell('Feature', ttfBold, bold: true),
                    _cell('SHAP Value', ttfBold, bold: true),
                    _cell('Direction', ttfBold, bold: true),
                  ],
                ),
                ...sortedShap.take(10).map((e) {
                  const labels = {
                    'age': 'Age', 'menarche': 'Age at Menarche', 'menopause': 'Menopause Age',
                    'agefirst': 'Age at 1st Pregnancy', 'children': 'No. of Children',
                    'breastfeeding': 'Breastfeeding', 'imc': 'BMI', 'weight': 'Weight (kg)',
                    'menopause_status': 'Menopause Status', 'pregnancy': 'Pregnancy',
                    'family_history': 'Family History', 'family_history_count': 'Family History Count',
                    'family_history_degree': 'Family History Degree', 'exercise_regular': 'Regular Exercise',
                  };
                  final label = labels[e.key] ?? e.key;
                  final isPos = e.value >= 0;
                  return pw.TableRow(children: [
                    _cell(label, ttf),
                    _cell('${isPos ? '+' : ''}${e.value.toStringAsFixed(4)}', ttf, color: isPos ? PdfColors.purple700 : PdfColors.green700),
                    _cell(isPos ? 'Increases Risk' : 'Decreases Risk', ttf, color: isPos ? PdfColors.purple700 : PdfColors.green700),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Imaging section ───────────────────────────────────────────────
          if (mammogramPdfImage != null || ultrasoundPdfImage != null || gradcamPdfImage != null) ...[
            _sectionHeader('Medical Imaging', ttfBold),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (mammogramPdfImage != null)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Mammogram', style: body(10, bold: true, color: PdfColors.pink700)),
                        pw.SizedBox(height: 4),
                        pw.ClipRRect(
                          horizontalRadius: 4,
                          verticalRadius: 4,
                          child: pw.Image(mammogramPdfImage, height: 160, fit: pw.BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
                if (mammogramPdfImage != null && ultrasoundPdfImage != null)
                  pw.SizedBox(width: 10),
                if (ultrasoundPdfImage != null)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Ultrasound', style: body(10, bold: true, color: PdfColors.indigo700)),
                        pw.SizedBox(height: 4),
                        pw.ClipRRect(
                          horizontalRadius: 4,
                          verticalRadius: 4,
                          child: pw.Image(ultrasoundPdfImage, height: 160, fit: pw.BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (gradcamPdfImage != null) ...[
              pw.SizedBox(height: 12),
              pw.Text('GradCAM — AI Visual Explanation', style: body(10, bold: true, color: PdfColors.purple700)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Heatmap highlights regions the AI model focused on. Red/warm = high attention, Blue/cool = low attention.',
                style: body(9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(gradcamPdfImage, height: 200, fit: pw.BoxFit.contain),
                ),
              ),
            ],
            pw.SizedBox(height: 16),
          ],

          // Personalized recommendations
          _sectionHeader('Personalized Clinical Recommendations', ttfBold),
          pw.SizedBox(height: 4),
          pw.Text('Generated based on AI results, risk factors, and patient clinical data', style: body(9, color: PdfColors.grey500)),
          pw.SizedBox(height: 8),
          ...recs.map((rec) {
            PdfColor recColor;
            String badge;
            switch (rec.priority) {
              case RecPriority.urgent: recColor = PdfColors.red700;    badge = 'URGENT';  break;
              case RecPriority.high:   recColor = PdfColors.orange700; badge = 'HIGH';    break;
              case RecPriority.medium: recColor = PdfColors.indigo700; badge = 'MEDIUM';  break;
              case RecPriority.low:    recColor = PdfColors.green700;  badge = 'ROUTINE'; break;
            }
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: recColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(rec.title, style: body(10, color: recColor, bold: true))),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(color: recColor, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text(badge, style: body(7, color: PdfColors.white, bold: true)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(rec.detail, style: body(9, color: PdfColors.grey700)),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 16),

          // Disclaimer
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber300),
            ),
            child: pw.Text(
              'IMPORTANT: This is an AI-assisted assessment and must be reviewed and validated by a qualified medical professional before any clinical decision-making. This analysis does not replace professional medical diagnosis.',
              style: body(9, color: PdfColors.brown700),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionHeader(String title, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.pink50,
        border: pw.Border(left: pw.BorderSide(color: PdfColors.pink400, width: 3)),
      ),
      child: pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.pink800)),
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, color: color)),
    );
  }

  /// Fetch image bytes from a URL (for Supabase public URLs)
  static Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
