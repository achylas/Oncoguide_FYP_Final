import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for comparing two reports and generating comparison analysis
class ComparisonService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Calculate the difference between two reports
  static ComparisonResult compare({
    required Map<String, dynamic> olderReport,
    required Map<String, dynamic> newerReport,
  }) {
    // Extract data from both reports
    final olderRisk = (olderReport['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final newerRisk = (newerReport['riskPercentage'] as num?)?.toDouble() ?? 0.0;
    final riskChange = newerRisk - olderRisk;

    final olderPrediction = olderReport['prediction']?.toString() ?? '';
    final newerPrediction = newerReport['prediction']?.toString() ?? '';

    final olderConfidence = (olderReport['confidence'] as num?)?.toDouble() ?? 0.0;
    final newerConfidence = (newerReport['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidenceChange = newerConfidence - olderConfidence;

    final olderDensityIndex = (olderReport['densityIndex'] as num?)?.toInt();
    final newerDensityIndex = (newerReport['densityIndex'] as num?)?.toInt();
    final densityChange = (newerDensityIndex != null && olderDensityIndex != null)
        ? newerDensityIndex - olderDensityIndex
        : null;

    // SHAP comparison
    final olderShap = olderReport['shapValues'] as Map<String, dynamic>?;
    final newerShap = newerReport['shapValues'] as Map<String, dynamic>?;
    final shapChanges = _compareShapValues(olderShap, newerShap);

    // Determine overall trend
    final trend = _calculateTrend(
      riskChange: riskChange,
      predictionChanged: olderPrediction != newerPrediction,
      densityChange: densityChange,
    );

    return ComparisonResult(
      olderReport: olderReport,
      newerReport: newerReport,
      riskChange: riskChange,
      confidenceChange: confidenceChange,
      densityChange: densityChange,
      predictionChanged: olderPrediction != newerPrediction,
      shapChanges: shapChanges,
      overallTrend: trend,
      comparisonDate: DateTime.now(),
    );
  }

  /// Save comparison report to Firestore
  static Future<String?> saveComparison({
    required ComparisonResult comparison,
    required String patientId,
    required String patientName,
  }) async {
    try {
      final uid = _auth.currentUser?.uid ?? 'anonymous';
      final reportType = comparison.olderReport['type']?.toString() ?? 'unknown';

      final doc = {
        'type': 'comparison',
        'reportType': reportType, // mammogram or ultrasound
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'olderReportId': comparison.olderReport['id']?.toString(),
        'newerReportId': comparison.newerReport['id']?.toString(),
        'olderReportDate': comparison.olderReport['createdAt'],
        'newerReportDate': comparison.newerReport['createdAt'],
        'riskChange': comparison.riskChange,
        'confidenceChange': comparison.confidenceChange,
        'densityChange': comparison.densityChange,
        'predictionChanged': comparison.predictionChanged,
        'overallTrend': comparison.overallTrend.name,
        'shapChanges': comparison.shapChanges,
        'summary': _generateSummary(comparison),
      };

      final ref = await _db.collection('report_comparisons').add(doc);
      return ref.id;
    } catch (e) {
      print('[ComparisonService] Failed to save: $e');
      return null;
    }
  }

  /// Get all comparisons for a patient
  static Stream<QuerySnapshot<Map<String, dynamic>>> getComparisonsForPatient(String patientId) {
    return _db
        .collection('report_comparisons')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Map<String, double> _compareShapValues(
    Map<String, dynamic>? older,
    Map<String, dynamic>? newer,
  ) {
    if (older == null || newer == null) return {};

    final changes = <String, double>{};
    for (final key in newer.keys) {
      final oldVal = (older[key] as num?)?.toDouble() ?? 0.0;
      final newVal = (newer[key] as num?)?.toDouble() ?? 0.0;
      changes[key] = newVal - oldVal;
    }
    return changes;
  }

  static ComparisonTrend _calculateTrend({
    required double riskChange,
    required bool predictionChanged,
    required int? densityChange,
  }) {
    // If prediction changed to worse (e.g., Benign → Malignant), it's declining
    if (predictionChanged) {
      // This would need more logic based on actual prediction values
      return ComparisonTrend.mixed;
    }

    // If risk decreased significantly
    if (riskChange < -5) return ComparisonTrend.improving;
    if (riskChange > 5) return ComparisonTrend.declining;

    // If density improved (lower index is better)
    if (densityChange != null) {
      if (densityChange < 0) return ComparisonTrend.improving;
      if (densityChange > 0) return ComparisonTrend.declining;
    }

    return ComparisonTrend.stable;
  }

  static String _generateSummary(ComparisonResult comparison) {
    final parts = <String>[];

    // Risk change
    if (comparison.riskChange.abs() > 1) {
      final direction = comparison.riskChange < 0 ? 'decreased' : 'increased';
      parts.add('Risk score $direction by ${comparison.riskChange.abs().toStringAsFixed(1)}%');
    }

    // Prediction change
    if (comparison.predictionChanged) {
      final older = comparison.olderReport['prediction']?.toString() ?? '';
      final newer = comparison.newerReport['prediction']?.toString() ?? '';
      parts.add('Prediction changed from $older to $newer');
    }

    // Density change
    if (comparison.densityChange != null && comparison.densityChange != 0) {
      final direction = comparison.densityChange! < 0 ? 'improved' : 'increased';
      parts.add('Breast density $direction');
    }

    if (parts.isEmpty) {
      return 'No significant changes detected between reports';
    }

    return parts.join('. ') + '.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum ComparisonTrend { improving, stable, declining, mixed }

class ComparisonResult {
  final Map<String, dynamic> olderReport;
  final Map<String, dynamic> newerReport;
  final double riskChange;
  final double confidenceChange;
  final int? densityChange;
  final bool predictionChanged;
  final Map<String, double> shapChanges;
  final ComparisonTrend overallTrend;
  final DateTime comparisonDate;

  ComparisonResult({
    required this.olderReport,
    required this.newerReport,
    required this.riskChange,
    required this.confidenceChange,
    required this.densityChange,
    required this.predictionChanged,
    required this.shapChanges,
    required this.overallTrend,
    required this.comparisonDate,
  });
}
