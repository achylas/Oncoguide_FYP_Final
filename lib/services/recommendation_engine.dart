import 'package:oncoguide_v2/services/api_service.dart';

/// Priority levels for recommendations
enum RecPriority { urgent, high, medium, low }

/// Categories for grouping
enum RecCategory { clinical, imaging, lifestyle, genetic, monitoring }

/// A single personalized recommendation
class Recommendation {
  final String title;
  final String detail;       // why this recommendation (personalized reason)
  final RecPriority priority;
  final RecCategory category;
  final String icon;         // emoji icon

  const Recommendation({
    required this.title,
    required this.detail,
    required this.priority,
    required this.category,
    required this.icon,
  });
}

/// Generates personalized clinical recommendations based on:
///   - RF model output (risk %, SHAP values)
///   - Ultrasound model output (Benign/Normal/Malignant)
///   - Density model output (BI-RADS A–D)
///   - Patient demographics and clinical data
class RecommendationEngine {

  static List<Recommendation> generate({
    required Map<String, dynamic> patient,
    required TabularPredictionResult? tabularResult,
    required UltrasoundAnalysisResult? ultrasoundAnalysis,
    DensityAnalysisResult? densityAnalysis,
  }) {
    final recs = <Recommendation>[];

    final isHighRisk    = tabularResult?.prediction == 1;
    final riskPct       = tabularResult?.riskPercentage ?? 0.0;
    final shap          = tabularResult?.shapValues ?? {};
    final usPrediction  = ultrasoundAnalysis?.prediction;
    final usConfidence  = ultrasoundAnalysis?.confidence ?? 0.0;
    final densityIndex  = densityAnalysis?.densityIndex;
    final densityClass  = densityAnalysis?.densityClass ?? '';

    // Patient fields
    final age         = (patient['age'] as num?)?.toDouble() ?? 0;
    final bmi         = _getDouble(patient, ['imc', 'clinicalAssessment.imc']) ?? 0;
    final weight      = (patient['weight'] as num?)?.toDouble() ?? 0;
    final famHistory  = _getInt(patient, ['familyHistory', 'family_history']) ?? 0;
    final famCount    = _getDouble(patient, ['familyHistoryCount', 'family_history_count']) ?? 0;
    final famDegree   = _getDouble(patient, ['familyHistoryDegree', 'family_history_degree']) ?? 0;
    final exercise    = _getInt(patient, ['exerciseRegular', 'exercise_regular']) ?? 0;
    final breastfeed  = _getInt(patient, ['breastfeeding']) ??
        _getIntNested(patient, 'reproductive', 'breastfeeding') ?? 0;
    final children    = _getDouble(patient, ['children']) ??
        _getDoubleNested(patient, 'reproductive', 'numberOfChildren') ?? 0;
    final menopause   = _getInt(patient, ['menopause_status']) ??
        _getIntNested(patient, 'reproductive', 'menopauseStatus') ?? 0;

    // Top SHAP factors (sorted by absolute impact)
    final topShap = shap.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final topFactor = topShap.isNotEmpty ? topShap.first.key : null;

    // ── URGENT: Malignant ultrasound ──────────────────────────────────────────
    if (usPrediction == 'Malignant') {
      recs.add(Recommendation(
        title: 'Urgent Biopsy Required',
        detail: 'Ultrasound shows malignant characteristics with ${usConfidence.toStringAsFixed(0)}% confidence. Tissue biopsy must be performed within 48–72 hours to confirm diagnosis.',
        priority: RecPriority.urgent,
        category: RecCategory.clinical,
        icon: '🔬',
      ));
      recs.add(Recommendation(
        title: 'Immediate Oncology Referral',
        detail: 'Malignant ultrasound finding requires urgent referral to a breast oncology specialist. Do not delay beyond 48 hours.',
        priority: RecPriority.urgent,
        category: RecCategory.clinical,
        icon: '🏥',
      ));
    }

    // ── HIGH RISK from RF model ───────────────────────────────────────────────
    if (isHighRisk) {
      recs.add(Recommendation(
        title: 'Oncology Specialist Referral',
        detail: 'Clinical risk model indicates ${riskPct.toStringAsFixed(1)}% breast cancer risk. Referral to oncology specialist recommended within 7 days.',
        priority: RecPriority.high,
        category: RecCategory.clinical,
        icon: '👩‍⚕️',
      ));

      recs.add(Recommendation(
        title: 'Contrast-Enhanced MRI',
        detail: 'High risk score warrants contrast-enhanced MRI for detailed staging and to assess extent of disease.',
        priority: RecPriority.high,
        category: RecCategory.imaging,
        icon: '🧲',
      ));

      recs.add(Recommendation(
        title: 'Multidisciplinary Tumor Board',
        detail: 'Case should be discussed in a multidisciplinary tumor board for comprehensive treatment planning.',
        priority: RecPriority.medium,
        category: RecCategory.clinical,
        icon: '👥',
      ));
    }

    // ── SHAP-driven: Family history is top risk factor ────────────────────────
    if (famHistory == 1 && topFactor == 'family_history') {
      final degree = famDegree == 1 ? 'first-degree' : famDegree == 2 ? 'second-degree' : 'family';
      final count  = famCount > 0 ? '${famCount.toInt()} $degree relative${famCount > 1 ? 's' : ''}' : 'family members';
      recs.add(Recommendation(
        title: 'Genetic Counseling Advised',
        detail: 'Family history ($count with breast cancer) is your #1 risk factor per AI analysis. BRCA1/BRCA2 genetic testing is strongly recommended.',
        priority: RecPriority.high,
        category: RecCategory.genetic,
        icon: '🧬',
      ));
    } else if (famHistory == 1) {
      recs.add(Recommendation(
        title: 'Consider Genetic Screening',
        detail: 'Family history of breast cancer detected. Discuss BRCA genetic testing with your physician.',
        priority: RecPriority.medium,
        category: RecCategory.genetic,
        icon: '🧬',
      ));
    }

    // ── SHAP-driven: Weight/BMI is top risk factor ────────────────────────────
    if ((topFactor == 'weight' || topFactor == 'imc') && (bmi > 25 || weight > 70)) {
      final bmiStr = bmi > 0 ? ' (BMI: ${bmi.toStringAsFixed(1)})' : '';
      recs.add(Recommendation(
        title: 'Weight Management Program',
        detail: 'Body weight$bmiStr is identified as your top modifiable risk factor. A structured weight management program with a nutritionist is recommended.',
        priority: RecPriority.high,
        category: RecCategory.lifestyle,
        icon: '⚖️',
      ));
    } else if (bmi > 30) {
      recs.add(Recommendation(
        title: 'Obesity Management',
        detail: 'BMI of ${bmi.toStringAsFixed(1)} is in the obese range, which increases breast cancer risk. Consult a nutritionist for a structured weight loss plan.',
        priority: RecPriority.medium,
        category: RecCategory.lifestyle,
        icon: '⚖️',
      ));
    } else if (bmi > 25) {
      recs.add(Recommendation(
        title: 'Healthy Weight Maintenance',
        detail: 'BMI of ${bmi.toStringAsFixed(1)} is slightly above normal. Maintaining a healthy weight reduces breast cancer risk by up to 20%.',
        priority: RecPriority.low,
        category: RecCategory.lifestyle,
        icon: '🥗',
      ));
    }

    // ── Exercise recommendation ───────────────────────────────────────────────
    if (exercise == 0) {
      final shapImpact = shap['exercise_regular'];
      final isTopFactor = topFactor == 'exercise_regular';
      recs.add(Recommendation(
        title: 'Start Regular Exercise',
        detail: isTopFactor
            ? 'Lack of exercise is your top modifiable risk factor per AI analysis. 150+ minutes of moderate aerobic activity per week reduces breast cancer risk significantly.'
            : 'No regular exercise reported. Physical activity of 150+ min/week is recommended to reduce cancer risk${shapImpact != null ? ' (SHAP impact: ${shapImpact.toStringAsFixed(4)})' : ''}.',
        priority: isTopFactor ? RecPriority.high : RecPriority.medium,
        category: RecCategory.lifestyle,
        icon: '🏃‍♀️',
      ));
    }

    // ── Age-based screening ───────────────────────────────────────────────────
    if (age >= 40 && age < 50) {
      recs.add(Recommendation(
        title: 'Annual Mammogram Screening',
        detail: 'At age ${age.toInt()}, annual mammogram screening is recommended. Early detection significantly improves outcomes.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    } else if (age >= 50) {
      recs.add(Recommendation(
        title: 'Biennial Mammogram + Clinical Exam',
        detail: 'At age ${age.toInt()}, mammogram every 1–2 years combined with clinical breast exam is standard of care.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    } else if (age < 40 && isHighRisk) {
      recs.add(Recommendation(
        title: 'Early Screening Recommended',
        detail: 'Despite age ${age.toInt()}, high risk score warrants earlier screening. Discuss MRI or ultrasound-based screening with your physician.',
        priority: RecPriority.high,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    }

    // ── Menopause-related ─────────────────────────────────────────────────────
    if (menopause == 1 && isHighRisk) {
      recs.add(Recommendation(
        title: 'Review Hormone Therapy',
        detail: 'Post-menopausal status combined with high risk score — review any hormone replacement therapy with your physician as it may increase risk.',
        priority: RecPriority.medium,
        category: RecCategory.clinical,
        icon: '💊',
      ));
    }

    // ── Breastfeeding protective factor ──────────────────────────────────────
    if (breastfeed == 1 && children > 0 && !isHighRisk) {
      recs.add(Recommendation(
        title: 'Protective Factors Noted',
        detail: 'Breastfeeding history is a protective factor against breast cancer. Continue routine preventive care and annual check-ups.',
        priority: RecPriority.low,
        category: RecCategory.monitoring,
        icon: '✅',
      ));
    }

    // ── Benign ultrasound ─────────────────────────────────────────────────────
    if (usPrediction == 'Benign') {
      recs.add(Recommendation(
        title: 'Benign Mass — Monitor',
        detail: 'Ultrasound shows benign characteristics (${usConfidence.toStringAsFixed(0)}% confidence). Follow-up ultrasound in 6 months to monitor for changes.',
        priority: RecPriority.medium,
        category: RecCategory.monitoring,
        icon: '🔍',
      ));
    }

    // ── Density-driven recommendations ───────────────────────────────────────
    if (densityAnalysis != null) {
      if (densityIndex == 3) {
        // Density D — extremely dense, significantly limits mammography
        recs.add(Recommendation(
          title: 'Supplemental MRI Recommended',
          detail: '$densityClass detected. Extremely dense tissue significantly reduces mammography sensitivity. Contrast-enhanced MRI or whole-breast ultrasound is strongly recommended as a supplement.',
          priority: isHighRisk ? RecPriority.high : RecPriority.medium,
          category: RecCategory.imaging,
          icon: '🧲',
        ));
        recs.add(Recommendation(
          title: 'Inform Patient of Dense Tissue',
          detail: 'Patients with extremely dense breasts (Density D) should be informed that mammography alone may miss up to 40% of cancers. Discuss supplemental screening options.',
          priority: RecPriority.medium,
          category: RecCategory.clinical,
          icon: '💬',
        ));
      } else if (densityIndex == 2) {
        // Density C — heterogeneous, may obscure small masses
        recs.add(Recommendation(
          title: 'Consider Supplemental Ultrasound',
          detail: '$densityClass detected. Heterogeneously dense tissue may obscure small masses on mammography. Supplemental whole-breast ultrasound is recommended, especially given ${isHighRisk ? "high risk score" : "clinical context"}.',
          priority: isHighRisk ? RecPriority.high : RecPriority.medium,
          category: RecCategory.imaging,
          icon: '🔊',
        ));
      }
      // Density A or B — no additional imaging needed, but note it
      if (densityIndex != null && densityIndex <= 1 && !isHighRisk) {
        recs.add(Recommendation(
          title: 'Favorable Tissue Density',
          detail: '$densityClass — mammography has high sensitivity for this tissue type. Standard annual screening schedule is appropriate.',
          priority: RecPriority.low,
          category: RecCategory.monitoring,
          icon: '✅',
        ));
      }
    }

    // ── Normal / Low risk ─────────────────────────────────────────────────────
    if (!isHighRisk && usPrediction != 'Malignant') {
      recs.add(Recommendation(
        title: 'Routine Follow-Up',
        detail: 'Low risk profile detected. Schedule next screening in 12 months or sooner if new symptoms arise (lump, skin changes, nipple discharge).',
        priority: RecPriority.low,
        category: RecCategory.monitoring,
        icon: '📅',
      ));
    }

    // ── SHAP top factor explanation (always add if available) ─────────────────
    if (topShap.isNotEmpty && tabularResult != null) {
      final top = topShap.first;
      final label = _shapLabel(top.key);
      final direction = top.value > 0 ? 'increases' : 'decreases';
      if (top.key != 'family_history' && top.key != 'weight' && top.key != 'imc' && top.key != 'exercise_regular') {
        recs.add(Recommendation(
          title: 'Key Risk Factor: $label',
          detail: 'AI analysis identified "$label" as your most influential risk factor — it $direction your risk score by ${top.value.abs().toStringAsFixed(4)} SHAP units.',
          priority: RecPriority.medium,
          category: RecCategory.clinical,
          icon: '📊',
        ));
      }
    }

    // Sort: urgent → high → medium → low
    recs.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return recs;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static double? _getDouble(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      if (k.contains('.')) {
        final parts = k.split('.');
        final nested = p[parts[0]];
        if (nested is Map) {
          final v = nested[parts[1]];
          if (v != null) return (v as num).toDouble();
        }
      } else if (p[k] != null) {
        return (p[k] as num).toDouble();
      }
    }
    return null;
  }

  static int? _getInt(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      if (p[k] != null) return (p[k] as num).toInt();
    }
    return null;
  }

  static int? _getIntNested(Map<String, dynamic> p, String parent, String key) {
    final nested = p[parent];
    if (nested is Map && nested[key] != null) return (nested[key] as num).toInt();
    return null;
  }

  static double? _getDoubleNested(Map<String, dynamic> p, String parent, String key) {
    final nested = p[parent];
    if (nested is Map && nested[key] != null) return (nested[key] as num).toDouble();
    return null;
  }

  static String _shapLabel(String key) {
    const labels = {
      'age': 'Age',
      'menarche': 'Age at Menarche',
      'menopause': 'Menopause Age',
      'agefirst': 'Age at First Pregnancy',
      'children': 'Number of Children',
      'breastfeeding': 'Breastfeeding History',
      'imc': 'BMI',
      'weight': 'Body Weight',
      'menopause_status': 'Menopause Status',
      'pregnancy': 'Pregnancy History',
      'family_history': 'Family History',
      'family_history_count': 'Family History Count',
      'family_history_degree': 'Family History Degree',
      'exercise_regular': 'Regular Exercise',
    };
    return labels[key] ?? key;
  }
}
