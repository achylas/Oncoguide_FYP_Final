import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/storage_service.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/new_analysis_screen.dart';

/// Handles all Firestore writes after an analysis completes.
///
/// Collections written to:
///   mammogram_reports/   — every mammogram scan
///   ultrasound_reports/  — every ultrasound scan
///   cancer_patients/     — when US prediction == Malignant
///   risk_patients/       — when RF risk == High Risk
///
/// Images stored in Supabase; public URLs saved in Firestore docs.
class ReportService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Public entry point ────────────────────────────────────────────────────

  static Future<void> saveReport({
    required Map<String, dynamic> patient,
    required Set<ImagingType> imagingTypes,
    required Map<ImagingType, File?> uploadedImages,
    required TabularPredictionResult? tabularResult,
    required MammogramValidationResult? mammogramValidation,
    required MammogramValidationResult? ultrasoundValidation,
    required UltrasoundAnalysisResult? ultrasoundAnalysis,
    DensityAnalysisResult? densityAnalysis,
    MammogramAnalysisResult? mammogramAnalysis,
  }) async {
    try {
      final uid       = _auth.currentUser?.uid ?? 'anonymous';
      final reportId  = DateTime.now().millisecondsSinceEpoch.toString();
      final patientId = patient['id']?.toString() ?? '';
      final patientName = patient['name']?.toString() ?? 'Unknown';
      final patientAge  = (patient['age'] as num?)?.toInt() ?? 0;
      final timestamp   = FieldValue.serverTimestamp();

      // ── Upload images to Supabase ────────────────────────────────────────
      final mammogramFile  = uploadedImages[ImagingType.mammogram];
      final ultrasoundFile = uploadedImages[ImagingType.ultrasound];

      String? mammogramUrl;
      String? ultrasoundUrl;
      String? gradcamUrl;

      if (mammogramFile != null) {
        mammogramUrl = await StorageService.uploadFile(
          file: mammogramFile,
          folder: 'mammograms',
          fileName: '$reportId.jpg',
        );
      }

      if (ultrasoundFile != null) {
        ultrasoundUrl = await StorageService.uploadFile(
          file: ultrasoundFile,
          folder: 'ultrasounds',
          fileName: '$reportId.jpg',
        );
      }

      if (ultrasoundAnalysis != null && ultrasoundAnalysis.hasGradcam) {
        final bytes = Uint8List.fromList(base64Decode(ultrasoundAnalysis.gradcamImage));
        gradcamUrl = await StorageService.uploadBytes(
          bytes: bytes,
          folder: 'gradcam',
          fileName: '$reportId.png',
        );
      }

      // ── Write mammogram report ───────────────────────────────────────────
      String? mammogramReportId;
      if (imagingTypes.contains(ImagingType.mammogram) && mammogramFile != null) {
        mammogramReportId = await _saveMammogramReport(
          reportId: reportId,
          patientId: patientId,
          patientName: patientName,
          patientAge: patientAge,
          doctorId: uid,
          timestamp: timestamp,
          mammogramValidation: mammogramValidation,
          tabularResult: tabularResult,
          mammogramUrl: mammogramUrl,
          densityAnalysis: densityAnalysis,
          mammogramAnalysis: mammogramAnalysis,
        );
      }

      // ── Write ultrasound report ──────────────────────────────────────────
      String? ultrasoundReportId;
      if (imagingTypes.contains(ImagingType.ultrasound) && ultrasoundFile != null) {
        ultrasoundReportId = await _saveUltrasoundReport(
          reportId: reportId,
          patientId: patientId,
          patientName: patientName,
          patientAge: patientAge,
          doctorId: uid,
          timestamp: timestamp,
          ultrasoundValidation: ultrasoundValidation,
          ultrasoundAnalysis: ultrasoundAnalysis,
          tabularResult: tabularResult,
          ultrasoundUrl: ultrasoundUrl,
          gradcamUrl: gradcamUrl,
        );
      }

      // ── Flag cancer patient (Malignant ultrasound) ───────────────────────
      if (ultrasoundAnalysis?.prediction == 'Malignant' &&
          ultrasoundReportId != null) {
        await _flagCancerPatient(
          patientId: patientId,
          patientName: patientName,
          patientAge: patientAge,
          doctorId: uid,
          ultrasoundReportId: ultrasoundReportId,
          ultrasoundAnalysis: ultrasoundAnalysis!,
          ultrasoundUrl: ultrasoundUrl,
          gradcamUrl: gradcamUrl,
        );
      }

      // ── Flag risk patient (High Risk RF) ─────────────────────────────────
      if (tabularResult?.prediction == 1 && mammogramReportId != null) {
        await _flagRiskPatient(
          patientId: patientId,
          patientName: patientName,
          patientAge: patientAge,
          doctorId: uid,
          mammogramReportId: mammogramReportId,
          tabularResult: tabularResult!,
          mammogramUrl: mammogramUrl,
        );
      }

      print('[ReportService] ✓ Report saved: $reportId');
    } catch (e) {
      print('[ReportService] ✗ Save failed: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<String> _saveMammogramReport({
    required String reportId,
    required String patientId,
    required String patientName,
    required int patientAge,
    required String doctorId,
    required FieldValue timestamp,
    required MammogramValidationResult? mammogramValidation,
    required TabularPredictionResult? tabularResult,
    required String? mammogramUrl,
    DensityAnalysisResult? densityAnalysis,
    MammogramAnalysisResult? mammogramAnalysis,
  }) async {
    final doc = _clean({
      'reportId'       : reportId,
      'patientId'      : patientId,
      'patientName'    : patientName,
      'patientAge'     : patientAge,
      'doctorId'       : doctorId,
      'createdAt'      : timestamp,
      'type'           : 'mammogram',
      'source'         : 'doctor',
      // Gatekeeper
      'isValid'        : mammogramValidation?.isValid,
      'gatekeeperScore': mammogramValidation?.score,
      // RF model
      'riskLabel'      : tabularResult?.riskLabel,
      'riskPercentage' : tabularResult?.riskPercentage,
      'prediction'     : tabularResult?.prediction,
      'shapValues'     : tabularResult?.shapValues,
      'baseValue'      : tabularResult?.baseValue,
      // Image
      'mammogramUrl'   : mammogramUrl,
      // Density model (if CC + MLO were both uploaded)
      'densityClass'   : densityAnalysis?.densityClass,
      'densityLabel'   : densityAnalysis?.densityLabel,
      'densityIndex'   : densityAnalysis?.densityIndex,
      'densityConfidence'    : densityAnalysis?.confidence,
      'densityProbabilities' : densityAnalysis?.probabilities,
      // Mammogram analysis model (BI-RADS finding classification)
      'mammoPrediction'      : mammogramAnalysis?.prediction,
      'mammoPredictionIndex' : mammogramAnalysis?.predictionIndex,
      'mammoConfidence'      : mammogramAnalysis?.confidence,
      'mammoProbabilities'   : mammogramAnalysis?.probabilities,
      'mammoFindingCategory' : mammogramAnalysis?.findingCategory,
    });

    final ref = await _db.collection('mammogram_reports').add(doc);
    return ref.id;
  }

  static Future<String> _saveUltrasoundReport({
    required String reportId,
    required String patientId,
    required String patientName,
    required int patientAge,
    required String doctorId,
    required FieldValue timestamp,
    required MammogramValidationResult? ultrasoundValidation,
    required UltrasoundAnalysisResult? ultrasoundAnalysis,
    required TabularPredictionResult? tabularResult,
    required String? ultrasoundUrl,
    required String? gradcamUrl,
  }) async {
    final doc = _clean({
      'reportId'       : reportId,
      'patientId'      : patientId,
      'patientName'    : patientName,
      'patientAge'     : patientAge,
      'doctorId'       : doctorId,
      'createdAt'      : timestamp,
      'type'           : 'ultrasound',
      'source'         : 'doctor',
      // Gatekeeper
      'isValid'        : ultrasoundValidation?.isValid,
      'gatekeeperScore': ultrasoundValidation?.score,
      // US analysis
      'prediction'     : ultrasoundAnalysis?.prediction,
      'predictionIndex': ultrasoundAnalysis?.predictionIndex,
      'confidence'     : ultrasoundAnalysis?.confidence,
      'probabilities'  : ultrasoundAnalysis?.probabilities,
      // RF model (combined analysis)
      'riskLabel'      : tabularResult?.riskLabel,
      'riskPercentage' : tabularResult?.riskPercentage,
      'shapValues'     : tabularResult?.shapValues,
      'baseValue'      : tabularResult?.baseValue,
      // Images
      'ultrasoundUrl'  : ultrasoundUrl,
      'gradcamUrl'     : gradcamUrl,
    });

    final ref = await _db.collection('ultrasound_reports').add(doc);
    return ref.id;
  }

  static Future<void> _flagCancerPatient({
    required String patientId,
    required String patientName,
    required int patientAge,
    required String doctorId,
    required String ultrasoundReportId,
    required UltrasoundAnalysisResult ultrasoundAnalysis,
    required String? ultrasoundUrl,
    required String? gradcamUrl,
  }) async {
    final ref = _db.collection('cancer_patients').doc(patientId);
    final snap = await ref.get();

    // Keep last 5 report IDs
    List<String> last5 = [];
    if (snap.exists) {
      final existing = snap.data()?['last5UltrasoundReportIds'];
      if (existing is List) {
        last5 = List<String>.from(existing);
      }
    }
    last5.insert(0, ultrasoundReportId);
    if (last5.length > 5) last5 = last5.sublist(0, 5);

    await ref.set(_clean({
      'patientId'                 : patientId,
      'patientName'               : patientName,
      'patientAge'                : patientAge,
      'flaggedAt'                 : FieldValue.serverTimestamp(),
      'flaggedBy'                 : doctorId,
      'usPrediction'              : 'Malignant',
      'usConfidence'              : ultrasoundAnalysis.confidence,
      'usProbabilities'           : ultrasoundAnalysis.probabilities,
      'latestUltrasoundReportId'  : ultrasoundReportId,
      'last5UltrasoundReportIds'  : last5,
      'ultrasoundUrl'             : ultrasoundUrl,
      'gradcamUrl'                : gradcamUrl,
    }), SetOptions(merge: true));
  }

  static Future<void> _flagRiskPatient({
    required String patientId,
    required String patientName,
    required int patientAge,
    required String doctorId,
    required String mammogramReportId,
    required TabularPredictionResult tabularResult,
    required String? mammogramUrl,
  }) async {
    final ref = _db.collection('risk_patients').doc(patientId);
    final snap = await ref.get();

    List<String> last5 = [];
    if (snap.exists) {
      final existing = snap.data()?['last5MammogramReportIds'];
      if (existing is List) {
        last5 = List<String>.from(existing);
      }
    }
    last5.insert(0, mammogramReportId);
    if (last5.length > 5) last5 = last5.sublist(0, 5);

    await ref.set(_clean({
      'patientId'                : patientId,
      'patientName'              : patientName,
      'patientAge'               : patientAge,
      'flaggedAt'                : FieldValue.serverTimestamp(),
      'flaggedBy'                : doctorId,
      'riskLabel'                : 'High Risk',
      'riskPercentage'           : tabularResult.riskPercentage,
      'shapValues'               : tabularResult.shapValues,
      'baseValue'                : tabularResult.baseValue,
      'latestMammogramReportId'  : mammogramReportId,
      'last5MammogramReportIds'  : last5,
      'mammogramUrl'             : mammogramUrl,
    }), SetOptions(merge: true));
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// All mammogram reports for current doctor, newest first.
  static Stream<QuerySnapshot<Map<String, dynamic>>> mammogramReportsStream() =>
      _db.collection('mammogram_reports')
          .where('doctorId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  /// All ultrasound reports for current doctor, newest first.
  static Stream<QuerySnapshot<Map<String, dynamic>>> ultrasoundReportsStream() =>
      _db.collection('ultrasound_reports')
          .where('doctorId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  /// All cancer patients (Malignant) for current doctor.
  static Stream<QuerySnapshot<Map<String, dynamic>>> cancerPatientsStream() =>
      _db.collection('cancer_patients')
          .where('flaggedBy', isEqualTo: _uid)
          .orderBy('flaggedAt', descending: true)
          .snapshots();

  /// All high-risk patients for current doctor.
  static Stream<QuerySnapshot<Map<String, dynamic>>> riskPatientsStream() =>
      _db.collection('risk_patients')
          .where('flaggedBy', isEqualTo: _uid)
          .orderBy('flaggedAt', descending: true)
          .snapshots();

  /// All reports (mammogram + ultrasound) combined stream.
  static Stream<QuerySnapshot<Map<String, dynamic>>> allReportsStream(String type) {
    assert(type == 'mammogram_reports' || type == 'ultrasound_reports');
    return _db.collection(type)
        .where('doctorId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static String get _uid => _auth.currentUser?.uid ?? '';

  /// Remove null values from a map before writing to Firestore.
  static Map<String, dynamic> _clean(Map<String, dynamic> map) {
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
