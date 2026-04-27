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
///   - Mammogram analysis model output (Normal/Benign/Suspicious)
///   - Patient demographics and clinical data
class RecommendationEngine {

  static List<Recommendation> generate({
    required Map<String, dynamic> patient,
    required TabularPredictionResult? tabularResult,
    required UltrasoundAnalysisResult? ultrasoundAnalysis,
    DensityAnalysisResult? densityAnalysis,
    MammogramAnalysisResult? mammogramAnalysis,
  }) {
    final recs = <Recommendation>[];

    final isHighRisk    = tabularResult?.prediction == 1;
    final riskPct       = tabularResult?.riskPercentage ?? 0.0;
    final shap          = tabularResult?.shapValues ?? {};
    final usPrediction  = ultrasoundAnalysis?.prediction;
    final usConfidence  = ultrasoundAnalysis?.confidence ?? 0.0;
    final densityIndex  = densityAnalysis?.densityIndex;
    final densityClass  = densityAnalysis?.densityClass ?? '';
    final mammoPrediction = mammogramAnalysis?.prediction;
    final mammoConfidence = mammogramAnalysis?.confidence ?? 0.0;
    final mammoFinding    = mammogramAnalysis?.findingCategory ?? '';

    // Patient fields - Demographics
    final age         = (patient['age'] as num?)?.toDouble() ?? 0;
    final ethnicity   = patient['ethnicity']?.toString() ?? '';
    
    // Clinical measurements
    final bmi         = _getDouble(patient, ['imc', 'clinicalAssessment.imc']) ?? 0;
    final weight      = (patient['weight'] as num?)?.toDouble() ?? 0;
    final vitaminD    = _getDouble(patient, ['vitaminDLevel']) ?? 0;
    
    // Family history — web portal stores as nested object {hasHistory, count, degree}
    // Flutter app stores flat: family_history: 0|1
    final famHistoryRaw = patient['familyHistory'];
    final int famHistory;
    final double famCount;
    final double famDegree;
    if (famHistoryRaw is Map) {
      famHistory = _safeInt(famHistoryRaw['hasHistory']);
      famCount   = _safeDouble(famHistoryRaw['count']);
      famDegree  = _safeDouble(famHistoryRaw['degree']);
    } else {
      famHistory = _getInt(patient, ['familyHistory', 'family_history']) ?? 0;
      famCount   = _getDouble(patient, ['familyHistoryCount', 'family_history_count']) ?? 0;
      famDegree  = _getDouble(patient, ['familyHistoryDegree', 'family_history_degree']) ?? 0;
    }
    
    // Lifestyle factors — web portal stores in lifestyle.exerciseRegular
    final lifestyleRaw = patient['lifestyle'];
    final int exercise;
    if (lifestyleRaw is Map) {
      exercise = _safeInt(lifestyleRaw['exerciseRegular']);
    } else {
      exercise = _getInt(patient, ['exerciseRegular', 'exercise_regular']) ?? 0;
    }
    final alcoholDrinks = _getDouble(patient, ['alcoholDrinksPerWeek']) ?? 0;
    final smokingStatus = _getInt(patient, ['smokingStatus']) ?? 0; // 0=never, 1=former, 2=current
    final dietType    = patient['dietType']?.toString() ?? '';
    
    // Reproductive history
    final breastfeed  = _getInt(patient, ['breastfeeding']) ??
        _getIntNested(patient, 'reproductive', 'breastfeeding') ?? 0;
    final children    = _getDouble(patient, ['children']) ??
        _getDoubleNested(patient, 'reproductive', 'numberOfChildren') ?? 0;
    final menopause   = _getInt(patient, ['menopause_status']) ??
        _getIntNested(patient, 'reproductive', 'menopauseStatus') ?? 0;
    
    // Contraceptive & HRT
    final oralContraceptive = _getInt(patient, ['oralContraceptiveUse']) ?? 0;
    final oralContraceptiveYears = _getDouble(patient, ['oralContraceptiveYears']) ?? 0;
    final hrtUse      = _getInt(patient, ['hrtUse']) ?? 0;
    final hrtType     = patient['hrtType']?.toString() ?? '';

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

    // ── Mammogram finding recommendations ─────────────────────────────────────
    if (mammoPrediction == 'Suspicious') {
      recs.add(Recommendation(
        title: 'Suspicious Mammogram — Biopsy Recommended',
        detail: 'Mammogram AI detected suspicious findings (${mammoFinding.isNotEmpty ? mammoFinding : "abnormal pattern"}) with ${mammoConfidence.toStringAsFixed(0)}% confidence. Core needle biopsy is recommended to confirm or exclude malignancy.',
        priority: RecPriority.urgent,
        category: RecCategory.clinical,
        icon: '🔬',
      ));
      recs.add(Recommendation(
        title: 'Diagnostic Mammogram + Ultrasound',
        detail: 'Suspicious mammogram finding warrants a diagnostic mammogram with additional views (spot compression, magnification) and targeted ultrasound of the suspicious area.',
        priority: RecPriority.high,
        category: RecCategory.imaging,
        icon: '🩻',
      ));
    } else if (mammoPrediction == 'Benign') {
      recs.add(Recommendation(
        title: 'Benign Mammogram Finding — Short-Interval Follow-Up',
        detail: 'Mammogram shows benign characteristics (${mammoFinding.isNotEmpty ? mammoFinding : "benign pattern"}) with ${mammoConfidence.toStringAsFixed(0)}% confidence. Short-interval follow-up mammogram in 6 months is recommended to confirm stability.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
        category: RecCategory.imaging,
        icon: '📅',
      ));
    } else if (mammoPrediction == 'Normal') {
      recs.add(Recommendation(
        title: 'Normal Mammogram — Routine Screening',
        detail: 'Mammogram AI found no suspicious findings. Continue routine annual screening as per age-based guidelines.',
        priority: RecPriority.low,
        category: RecCategory.monitoring,
        icon: '✅',
      ));
    }

    // ── RACE/ETHNICITY-BASED: Early screening for Black women ─────────────────
    if ((ethnicity.toLowerCase().contains('black') || ethnicity.toLowerCase().contains('african')) && age >= 25 && age < 40) {
      recs.add(Recommendation(
        title: 'Early Risk Assessment Recommended',
        detail: 'ACR 2023 guidelines recommend breast cancer risk assessment by age 25 for Black women due to 40% higher mortality rates and earlier onset. Schedule comprehensive risk evaluation.',
        priority: RecPriority.high,
        category: RecCategory.clinical,
        icon: '🩺',
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
        detail: 'High risk score warrants contrast-enhanced MRI for detailed staging and to assess extent of disease. MRI is the most sensitive imaging modality for high-risk patients.',
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

    // ── LIFESTYLE: Smoking cessation ──────────────────────────────────────────
    if (smokingStatus == 2) { // Current smoker
      recs.add(Recommendation(
        title: 'Smoking Cessation Program',
        detail: 'Active smoking increases breast cancer risk by 10-20% and significantly worsens treatment outcomes. Immediate referral to smoking cessation program is strongly recommended.',
        priority: RecPriority.high,
        category: RecCategory.lifestyle,
        icon: '🚭',
      ));
    } else if (smokingStatus == 1 && isHighRisk) { // Former smoker with high risk
      recs.add(Recommendation(
        title: 'Former Smoker - Enhanced Monitoring',
        detail: 'History of smoking combined with high risk score warrants closer monitoring. Ensure annual screening compliance.',
        priority: RecPriority.medium,
        category: RecCategory.monitoring,
        icon: '🚭',
      ));
    }

    // ── LIFESTYLE: Alcohol consumption ────────────────────────────────────────
    if (alcoholDrinks >= 7) { // 1+ drinks per day
      final drinksPerDay = alcoholDrinks / 7;
      final riskIncrease = (drinksPerDay * 10).toStringAsFixed(0);
      recs.add(Recommendation(
        title: 'Reduce Alcohol Consumption',
        detail: 'Current alcohol intake (${drinksPerDay.toStringAsFixed(1)} drinks/day) increases breast cancer risk by approximately $riskIncrease%. WHO recommends limiting to <3 drinks per week.',
        priority: RecPriority.high,
        category: RecCategory.lifestyle,
        icon: '🍷',
      ));
    } else if (alcoholDrinks >= 3 && alcoholDrinks < 7) {
      recs.add(Recommendation(
        title: 'Moderate Alcohol Intake',
        detail: 'Current alcohol consumption (${alcoholDrinks.toStringAsFixed(0)} drinks/week) is moderate. Consider reducing further as even moderate intake increases breast cancer risk.',
        priority: RecPriority.medium,
        category: RecCategory.lifestyle,
        icon: '🍷',
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

    // ── LIFESTYLE: Vitamin D deficiency ───────────────────────────────────────
    if (vitaminD > 0 && vitaminD < 20) { // Deficient
      recs.add(Recommendation(
        title: 'Vitamin D Supplementation',
        detail: 'Vitamin D level of ${vitaminD.toStringAsFixed(1)} ng/mL is deficient. Studies suggest adequate vitamin D (>30 ng/mL) may reduce breast cancer risk. Discuss supplementation (1000-2000 IU daily) with your physician.',
        priority: RecPriority.medium,
        category: RecCategory.lifestyle,
        icon: '☀️',
      ));
    } else if (vitaminD >= 20 && vitaminD < 30) { // Insufficient
      recs.add(Recommendation(
        title: 'Optimize Vitamin D Levels',
        detail: 'Vitamin D level of ${vitaminD.toStringAsFixed(1)} ng/mL is insufficient. Target level is >30 ng/mL. Consider supplementation and increased sun exposure.',
        priority: RecPriority.low,
        category: RecCategory.lifestyle,
        icon: '☀️',
      ));
    }

    // ── LIFESTYLE: Mediterranean diet recommendation ──────────────────────────
    if ((isHighRisk || bmi > 25) && !dietType.toLowerCase().contains('mediterranean')) {
      recs.add(Recommendation(
        title: 'Mediterranean Diet Consultation',
        detail: 'Mediterranean diet (high in vegetables, fruits, whole grains, olive oil, fish) has been shown to reduce breast cancer risk by 20-30%. Nutritionist consultation recommended.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
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

    // ── Age-based screening (USPSTF 2024 Guidelines) ──────────────────────────
    if (age >= 40 && age <= 74) {
      final interval = isHighRisk ? 'annual' : 'biennial (every 2 years)';
      final intervalDetail = isHighRisk 
          ? 'High-risk patients should undergo annual screening.'
          : 'USPSTF 2024 guidelines recommend screening every 2 years for average-risk women.';
      
      recs.add(Recommendation(
        title: '${isHighRisk ? "Annual" : "Biennial"} Mammogram Screening',
        detail: 'At age ${age.toInt()}, $interval mammogram screening is recommended. $intervalDetail Early detection significantly improves outcomes.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    } else if (age < 40 && isHighRisk) {
      recs.add(Recommendation(
        title: 'Early Screening Recommended',
        detail: 'Despite age ${age.toInt()}, high risk score warrants earlier screening. Discuss MRI or ultrasound-based screening with your physician. ACR recommends starting at age 30 for high-risk patients.',
        priority: RecPriority.high,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    } else if (age > 74 && isHighRisk) {
      recs.add(Recommendation(
        title: 'Individualized Screening Decision',
        detail: 'At age ${age.toInt()}, screening decisions should be individualized based on health status and life expectancy. Discuss continued screening with your physician.',
        priority: RecPriority.medium,
        category: RecCategory.imaging,
        icon: '📷',
      ));
    }

    // ── Menopause-related & HRT ───────────────────────────────────────────────
    if (menopause == 1 && hrtUse == 1) {
      final hrtDetail = hrtType.toLowerCase().contains('combined') 
          ? 'Combined estrogen-progestin HRT significantly increases breast cancer risk.'
          : 'Hormone replacement therapy may increase breast cancer risk.';
      
      recs.add(Recommendation(
        title: 'Review Hormone Therapy',
        detail: 'Post-menopausal status with active HRT use${isHighRisk ? " and high risk score" : ""}. $hrtDetail Discuss risks/benefits and alternatives with your physician.',
        priority: isHighRisk ? RecPriority.high : RecPriority.medium,
        category: RecCategory.clinical,
        icon: '💊',
      ));
    } else if (menopause == 1 && isHighRisk && hrtUse == 0) {
      recs.add(Recommendation(
        title: 'Avoid Hormone Replacement Therapy',
        detail: 'Post-menopausal status with high risk score. Avoid hormone replacement therapy if possible. Discuss non-hormonal alternatives for menopausal symptoms.',
        priority: RecPriority.medium,
        category: RecCategory.clinical,
        icon: '💊',
      ));
    }

    // ── Contraceptive use ─────────────────────────────────────────────────────
    if (oralContraceptive == 1 && oralContraceptiveYears > 5 && isHighRisk) {
      recs.add(Recommendation(
        title: 'Review Contraceptive Options',
        detail: 'Long-term oral contraceptive use (${oralContraceptiveYears.toInt()} years) combined with high risk score. Combined oral contraceptives slightly increase breast cancer risk during use. Discuss alternative contraceptive methods with your gynecologist.',
        priority: RecPriority.medium,
        category: RecCategory.clinical,
        icon: '💊',
      ));
    } else if (oralContraceptive == 1 && oralContraceptiveYears > 10) {
      recs.add(Recommendation(
        title: 'Long-term Contraceptive Use',
        detail: 'Oral contraceptive use for ${oralContraceptiveYears.toInt()} years. While risk increase is small, consider discussing alternatives with your gynecologist at your next visit.',
        priority: RecPriority.low,
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
      final followUpDetail = usConfidence >= 95
          ? 'Follow-up ultrasound in 6 months, then annually if stable for 2 years (BI-RADS 3 protocol).'
          : 'Follow-up ultrasound in 6 months to monitor for changes. Consider biopsy if confidence is lower or changes occur.';
      
      recs.add(Recommendation(
        title: 'Benign Mass — Short-Interval Follow-Up',
        detail: 'Ultrasound shows benign characteristics (${usConfidence.toStringAsFixed(0)}% confidence). $followUpDetail',
        priority: RecPriority.medium,
        category: RecCategory.monitoring,
        icon: '🔍',
      ));
    }

    // ── Cross-analysis: Normal mammogram + high density ──────────────────────
    // No cancer visible NOW, but dense tissue is both a risk factor and a
    // limitation of mammography — the doctor must understand both dimensions.
    if (mammogramAnalysis != null && densityAnalysis != null) {
      final mammoNormal = mammoPrediction == 'Normal';
      final highDensity = (densityIndex ?? -1) >= 2;

      if (mammoNormal && highDensity) {
        final densLetter = densityIndex == 3 ? 'D (Extremely Dense)' : 'C (Heterogeneously Dense)';
        final missRate   = densityIndex == 3 ? '40–50%' : '30–40%';
        final suppImaging = densityIndex == 3
            ? 'contrast-enhanced MRI (preferred) or whole-breast ultrasound'
            : 'whole-breast ultrasound or breast MRI';

        recs.add(Recommendation(
          title: 'Normal Mammogram — But Dense Tissue Requires Attention',
          detail: 'The mammogram shows no suspicious findings. However, Density $densLetter means mammography alone may miss up to $missRate of cancers in this patient. '
              'Dense tissue appears white on mammograms — the same colour as tumours — making early lesions difficult to detect. '
              'This result means no cancer is currently visible, not that the breast is cancer-free. '
              'Supplemental $suppImaging is recommended to rule out occult (hidden) lesions.',
          priority: densityIndex == 3 ? RecPriority.high : RecPriority.medium,
          category: RecCategory.imaging,
          icon: '🔍',
        ));

        recs.add(Recommendation(
          title: 'Density Is an Independent Cancer Risk Factor',
          detail: 'Beyond limiting mammography sensitivity, Density $densLetter is itself an independent risk factor for developing breast cancer — separate from any current imaging findings. '
              'Women with heterogeneously or extremely dense breasts have a 1.2–2× higher lifetime risk compared to average-density women. '
              'This patient should be counselled about their density status and its implications for future screening strategy.',
          priority: RecPriority.medium,
          category: RecCategory.clinical,
          icon: '📋',
        ));
      }
    }


    if (densityAnalysis != null) {
      if (densityIndex == 3) {
        // Density D — extremely dense, significantly limits mammography
        if (isHighRisk || famHistory == 1) {
          recs.add(Recommendation(
            title: 'Annual Breast MRI Required',
            detail: '$densityClass detected with high-risk profile. Extremely dense tissue significantly reduces mammography sensitivity. Annual contrast-enhanced MRI is strongly recommended per ACR 2024 guidelines.',
            priority: RecPriority.high,
            category: RecCategory.imaging,
            icon: '🧲',
          ));
        } else {
          recs.add(Recommendation(
            title: 'Supplemental Screening Recommended',
            detail: '$densityClass detected. Extremely dense tissue significantly reduces mammography sensitivity. Supplemental whole-breast ultrasound or contrast-enhanced MRI is recommended.',
            priority: RecPriority.medium,
            category: RecCategory.imaging,
            icon: '🧲',
          ));
        }
        
        recs.add(Recommendation(
          title: 'Inform Patient of Dense Tissue',
          detail: 'Patients with extremely dense breasts (Density D) should be informed that mammography alone may miss up to 40% of cancers. Supplemental screening is essential.',
          priority: RecPriority.medium,
          category: RecCategory.clinical,
          icon: '💬',
        ));
      } else if (densityIndex == 2) {
        // Density C — heterogeneous, may obscure small masses
        if (isHighRisk || famHistory == 1) {
          recs.add(Recommendation(
            title: 'Supplemental MRI or Ultrasound',
            detail: '$densityClass detected with high-risk profile. Heterogeneously dense tissue may obscure small masses. Supplemental breast MRI (preferred) or whole-breast ultrasound is recommended per ACR 2024 guidelines.',
            priority: RecPriority.high,
            category: RecCategory.imaging,
            icon: '🧲',
          ));
        } else {
          recs.add(Recommendation(
            title: 'Consider Supplemental Ultrasound',
            detail: '$densityClass detected. Heterogeneously dense tissue may obscure small masses on mammography. Supplemental whole-breast ultrasound may be beneficial. Discuss with your physician.',
            priority: RecPriority.medium,
            category: RecCategory.imaging,
            icon: '🔊',
          ));
        }
      }
      // Density A or B — no additional imaging needed, but note it
      if (densityIndex != null && densityIndex <= 1 && !isHighRisk) {
        recs.add(Recommendation(
          title: 'Favorable Tissue Density',
          detail: '$densityClass — mammography has high sensitivity for this tissue type. Standard screening schedule (biennial for average risk, annual for high risk) is appropriate.',
          priority: RecPriority.low,
          category: RecCategory.monitoring,
          icon: '✅',
        ));
      }
    }

    // ── Normal / Low risk ─────────────────────────────────────────────────────
    if (!isHighRisk && usPrediction != 'Malignant') {
      final screeningInterval = (age >= 40 && age <= 74) ? 'biennial (every 2 years)' : 'annual';
      recs.add(Recommendation(
        title: 'Routine Follow-Up',
        detail: 'Low risk profile detected. Continue $screeningInterval screening per USPSTF 2024 guidelines. Contact physician immediately if new symptoms arise (lump, skin changes, nipple discharge, pain).',
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
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v);
        }
      } else {
        final v = p[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v);
        // skip Maps/Lists — they are nested objects, not numeric values
      }
    }
    return null;
  }

  static int? _getInt(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      final v = p[k];
      if (v is num) return v.toInt();
      if (v is bool) return v ? 1 : 0;
      if (v is String) return int.tryParse(v);
      // skip Maps/Lists
    }
    return null;
  }

  static int? _getIntNested(Map<String, dynamic> p, String parent, String key) {
    final nested = p[parent];
    if (nested is Map) {
      final v = nested[key];
      if (v is num) return v.toInt();
      if (v is bool) return v ? 1 : 0;
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  static double? _getDoubleNested(Map<String, dynamic> p, String parent, String key) {
    final nested = p[parent];
    if (nested is Map) {
      final v = nested[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is bool) return v ? 1 : 0;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _safeDouble(dynamic v, [double fallback = 0.0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
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
      'alcoholDrinksPerWeek': 'Alcohol Consumption',
      'smokingStatus': 'Smoking Status',
      'vitaminDLevel': 'Vitamin D Level',
      'oralContraceptiveUse': 'Oral Contraceptive Use',
      'oralContraceptiveYears': 'Oral Contraceptive Duration',
      'hrtUse': 'Hormone Replacement Therapy',
    };
    return labels[key] ?? key;
  }
}
