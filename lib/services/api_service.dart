import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Result from the mammogram gatekeeper validation model.
class MammogramValidationResult {
  final bool isValid;
  final double score;
  final String message;

  const MammogramValidationResult({
    required this.isValid,
    required this.score,
    required this.message,
  });

  factory MammogramValidationResult.fromJson(Map<String, dynamic> json) {
    return MammogramValidationResult(
      isValid: json['is_valid'] as bool,
      score: (json['score'] as num).toDouble(),
      message: json['message'] as String,
    );
  }
}

/// Result from the Random Forest tabular risk prediction model.
class TabularPredictionResult {
  final int prediction;        // 0 = low risk, 1 = high risk
  final double probability;    // 0.0 – 1.0
  final String riskLabel;      // "Low Risk" | "High Risk"
  final double riskPercentage; // 0 – 100
  final Map<String, double> shapValues;  // feature → impact
  final double baseValue;

  const TabularPredictionResult({
    required this.prediction,
    required this.probability,
    required this.riskLabel,
    required this.riskPercentage,
    required this.shapValues,
    required this.baseValue,
  });

  factory TabularPredictionResult.fromJson(Map<String, dynamic> json) {
    final rawShap = json['shap_values'] as Map<String, dynamic>? ?? {};
    return TabularPredictionResult(
      prediction: json['prediction'] as int,
      probability: (json['probability'] as num).toDouble(),
      riskLabel: json['risk_label'] as String,
      riskPercentage: (json['risk_percentage'] as num).toDouble(),
      shapValues: rawShap.map((k, v) => MapEntry(k, _toDouble(v))),
      baseValue: (json['base_value'] as num).toDouble(),
    );
  }

  /// Returns features sorted by absolute SHAP impact (descending).
  List<MapEntry<String, double>> get sortedShapEntries {
    final entries = shapValues.entries.toList();
    entries.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return entries;
  }
}

/// Unified API client for the OncoGuide FastAPI backend.
class ApiService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static const Duration _timeout = Duration(seconds: 30);

  // ─────────────────────────────────────────────
  // Mammogram image validation
  // ─────────────────────────────────────────────

  /// Sends [imageFile] to the gatekeeper model.
  /// Returns [MammogramValidationResult] or throws [ApiException] on error.
  static Future<MammogramValidationResult> validateMammogram(
      File imageFile) async {
    return _validateImage(imageFile, 'mammogram');
  }

  /// Sends [imageFile] to the ultrasound gatekeeper model.
  static Future<MammogramValidationResult> validateUltrasound(
      File imageFile) async {
    return _validateImage(imageFile, 'ultrasound');
  }

  static Future<MammogramValidationResult> _validateImage(
      File imageFile, String type) async {
    final uri = Uri.parse('$_baseUrl/validate/$type');
    final request = http.MultipartRequest('POST', uri);

    final ext = imageFile.path.split('.').last.toLowerCase();
    final contentType = MediaType('image', ext == 'png' ? 'png' : 'jpeg');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MammogramValidationResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractDetail(response.body),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Tabular (Random Forest) prediction
  // ─────────────────────────────────────────────

  /// Sends patient clinical data to the RF model.
  static Future<TabularPredictionResult> predictTabular(
      Map<String, dynamic> patientData) async {
    final uri = Uri.parse('$_baseUrl/predict/tabular');
    final payload = _buildTabularPayload(patientData);

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TabularPredictionResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractDetail(response.body),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Ultrasound analysis (classification)
  // ─────────────────────────────────────────────

  /// Sends ultrasound image to the DualOutputModel for classification.
  static Future<UltrasoundAnalysisResult> analyzeUltrasound(
      File imageFile) async {
    final uri = Uri.parse('$_baseUrl/analyze/ultrasound');
    final request = http.MultipartRequest('POST', uri);

    final ext = imageFile.path.split('.').last.toLowerCase();
    final contentType = MediaType('image', ext == 'png' ? 'png' : 'jpeg');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return UltrasoundAnalysisResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractDetail(response.body),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Mammogram analysis (BI-RADS classification)
  // ─────────────────────────────────────────────

  /// Sends a single CC mammogram to the EfficientNet-B0 model.
  /// Returns [MammogramAnalysisResult] with Normal/Benign/Suspicious classification.
  static Future<MammogramAnalysisResult> analyzeMammogram(File imageFile) async {
    final uri     = Uri.parse('$_baseUrl/analyze/mammogram');
    final request = http.MultipartRequest('POST', uri);

    final ext         = imageFile.path.split('.').last.toLowerCase();
    final contentType = MediaType('image', ext == 'png' ? 'png' : 'jpeg');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ),
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MammogramAnalysisResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractDetail(response.body),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Density analysis (Siamese CC + MLO)
  // ─────────────────────────────────────────────

  /// Sends CC and MLO mammogram views to the Siamese density model.
  /// Returns [DensityAnalysisResult] with BI-RADS A–D classification.
  static Future<DensityAnalysisResult> analyzeDensity({
    required File ccFile,
    required File mloFile,
  }) async {
    final uri     = Uri.parse('$_baseUrl/analyze/density');
    final request = http.MultipartRequest('POST', uri);

    String _ext(File f) => f.path.split('.').last.toLowerCase();
    MediaType _ct(File f) =>
        MediaType('image', _ext(f) == 'png' ? 'png' : 'jpeg');

    request.files.add(
      await http.MultipartFile.fromPath(
        'cc_file',
        ccFile.path,
        contentType: _ct(ccFile),
      ),
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        'mlo_file',
        mloFile.path,
        contentType: _ct(mloFile),
      ),
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DensityAnalysisResult.fromJson(json);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractDetail(response.body),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Health check
  // ─────────────────────────────────────────────
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Maps Firestore patient document fields → backend feature names.
  /// Handles both the Flutter app's flat field names AND the web portal's
  /// nested structure (familyHistory object, reproductive object, lifestyle object).
  static Map<String, dynamic> _buildTabularPayload(
      Map<String, dynamic> patient) {
    // Safe numeric extractors — never throw on unexpected types
    double d(dynamic v, [double fallback = 0.0]) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }
    int i(dynamic v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      if (v is bool) return v ? 1 : 0;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    // ── Nested sub-documents (web portal schema) ──────────────────────────
    final reproductive =
        patient['reproductive'] as Map<String, dynamic>? ?? {};
    final clinical =
        patient['clinicalAssessment'] as Map<String, dynamic>? ?? {};
    final lifestyle =
        patient['lifestyle'] as Map<String, dynamic>? ?? {};

    // ── familyHistory: web portal stores as nested object ─────────────────
    // { hasHistory: 0|1, count: N, degree: 1|2, relations: [...] }
    // Flutter app stores flat: family_history: 0|1
    final famHistoryRaw = patient['familyHistory'];
    final int famHistory;
    final double famCount;
    final double famDegree;
    if (famHistoryRaw is Map) {
      famHistory = i(famHistoryRaw['hasHistory']);
      famCount   = d(famHistoryRaw['count']);
      famDegree  = d(famHistoryRaw['degree']);
    } else {
      famHistory = i(famHistoryRaw ?? patient['family_history']);
      famCount   = d(patient['familyHistoryCount'] ?? patient['family_history_count']);
      famDegree  = d(patient['familyHistoryDegree'] ?? patient['family_history_degree']);
    }

    // ── reproductive: web portal uses different key names ─────────────────
    // menarcheAge vs menarche, menopauseAge vs menopause,
    // firstChildAge vs agefirst, breastfeedingMonths (>0 → 1) vs breastfeeding
    final menarcheVal = reproductive['menarcheAge'] ?? reproductive['menarche'] ?? patient['menarche'];
    final menopauseAgeVal = reproductive['menopauseAge'] ?? reproductive['menopause'] ?? patient['menopause'];
    final firstChildVal = reproductive['firstChildAge'] ?? reproductive['ageFirstPregnancy'] ?? patient['agefirst'];
    final childrenVal = reproductive['numberOfChildren'] ?? patient['children'];
    final menopauseStatusVal = reproductive['menopauseStatus'] ?? patient['menopause_status'];
    final pregnancyVal = reproductive['pregnancy'] ?? patient['pregnancy'];

    // breastfeeding: web portal stores months (>0 → binary 1), Flutter stores binary
    final breastfeedingRaw = reproductive['breastfeedingMonths'] ?? reproductive['breastfeeding'] ?? patient['breastfeeding'];
    final int breastfeeding;
    if (breastfeedingRaw is num && breastfeedingRaw > 1) {
      // months value — convert to binary
      breastfeeding = breastfeedingRaw > 0 ? 1 : 0;
    } else {
      breastfeeding = i(breastfeedingRaw);
    }

    // ── exercise: web portal stores in lifestyle.exerciseRegular ──────────
    final exerciseVal = lifestyle['exerciseRegular'] ?? patient['exerciseRegular'] ?? patient['exercise_regular'];

    return {
      'age':                   d(patient['age']),
      'menarche':              d(menarcheVal, 13),
      'menopause':             d(menopauseAgeVal, 0),
      'agefirst':              d(firstChildVal, 0),
      'children':              d(childrenVal, 0),
      'breastfeeding':         breastfeeding,
      'imc':                   d(clinical['imc'] ?? patient['imc'], 25.0),
      'weight':                d(patient['weight'], 60.0),
      'menopause_status':      i(menopauseStatusVal),
      'pregnancy':             i(pregnancyVal),
      'family_history':        famHistory,
      'family_history_count':  famCount,
      'family_history_degree': famDegree,
      'exercise_regular':      i(exerciseVal),
    };
  }

  static String _extractDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? 'Unknown server error';
    } catch (_) {
      return body.isNotEmpty ? body : 'Unknown server error';
    }
  }
}

/// Result from the ultrasound analysis model (DualOutputModel).
class UltrasoundAnalysisResult {
  final String prediction;      // "Benign" | "Normal" | "Malignant"
  final int predictionIndex;    // 0=benign, 1=normal, 2=malignant
  final double confidence;      // 0–100
  final Map<String, double> probabilities;
  final String gradcamImage;    // base64 PNG heatmap overlay

  const UltrasoundAnalysisResult({
    required this.prediction,
    required this.predictionIndex,
    required this.confidence,
    required this.probabilities,
    required this.gradcamImage,
  });

  factory UltrasoundAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawProbs = json['probabilities'] as Map<String, dynamic>? ?? {};
    return UltrasoundAnalysisResult(
      prediction: json['prediction'] as String,
      predictionIndex: json['prediction_index'] as int,
      confidence: _toDouble(json['confidence']),
      probabilities: rawProbs.map((k, v) => MapEntry(k, _toDouble(v))),
      gradcamImage: json['gradcam_image'] as String? ?? '',
    );
  }

  bool get isMalignant => predictionIndex == 2;
  bool get isNormal => predictionIndex == 1;
  bool get hasGradcam => gradcamImage.isNotEmpty;
}
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Safely converts any JSON numeric value to double.
/// Handles num, int, double, and gracefully returns 0.0 for unexpected types.
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

/// Result from the Siamese density model (CC + MLO views).
class DensityAnalysisResult {
  /// Full label e.g. "Density B (Scattered)"
  final String densityClass;
  /// Short label e.g. "B - Scattered"
  final String densityLabel;
  /// 0=A (Fatty), 1=B (Scattered), 2=C (Heterogeneous), 3=D (Extremely Dense)
  final int densityIndex;
  /// Confidence 0–100
  final double confidence;
  /// Per-class probabilities
  final Map<String, double> probabilities;
  /// Base64-encoded PNG GradCAM overlay of the CC view
  final String gradcamImage;

  const DensityAnalysisResult({
    required this.densityClass,
    required this.densityLabel,
    required this.densityIndex,
    required this.confidence,
    required this.probabilities,
    required this.gradcamImage,
  });

  factory DensityAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawProbs = json['probabilities'] as Map<String, dynamic>? ?? {};
    return DensityAnalysisResult(
      densityClass:  json['density_class']  as String,
      densityLabel:  json['density_label']  as String,
      densityIndex:  json['density_index']  as int,
      confidence:    _toDouble(json['confidence']),
      probabilities: rawProbs.map((k, v) => MapEntry(k, _toDouble(v))),
      gradcamImage:  json['gradcam_image']  as String? ?? '',
    );
  }

  bool get isHighDensity => densityIndex >= 2;   // C or D
  bool get hasGradcam    => gradcamImage.isNotEmpty;

  /// Clinical interpretation for the density class.
  String get clinicalNote {
    switch (densityIndex) {
      case 0: return 'Fatty tissue — highest sensitivity for mammography.';
      case 1: return 'Scattered fibroglandular — generally good sensitivity.';
      case 2: return 'Heterogeneous dense — may obscure small masses.';
      case 3: return 'Extremely dense — significantly reduces mammography sensitivity.';
      default: return '';
    }
  }
}

/// Result from the mammogram analysis model (EfficientNet-B0, VinDr-Mammo).
class MammogramAnalysisResult {
  /// "Normal" | "Benign" | "Suspicious"
  final String prediction;
  /// 0=Normal, 1=Benign, 2=Suspicious
  final int predictionIndex;
  /// Confidence 0–100
  final double confidence;
  /// Per-class probabilities
  final Map<String, double> probabilities;
  /// Base64-encoded PNG GradCAM overlay
  final String gradcamImage;
  /// Estimated finding category (e.g. "Mass", "No Finding", "Suspicious Calcification")
  final String findingCategory;

  const MammogramAnalysisResult({
    required this.prediction,
    required this.predictionIndex,
    required this.confidence,
    required this.probabilities,
    required this.gradcamImage,
    required this.findingCategory,
  });

  factory MammogramAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawProbs = json['probabilities'] as Map<String, dynamic>? ?? {};
    return MammogramAnalysisResult(
      prediction:      json['prediction']       as String,
      predictionIndex: json['prediction_index'] as int,
      confidence:      _toDouble(json['confidence']),
      probabilities:   rawProbs.map((k, v) => MapEntry(k, _toDouble(v))),
      gradcamImage:    json['gradcam_image']    as String? ?? '',
      findingCategory: json['finding_category'] as String? ?? '',
    );
  }

  bool get isSuspicious => predictionIndex == 2;
  bool get isNormal     => predictionIndex == 0;
  bool get hasGradcam   => gradcamImage.isNotEmpty;

  /// Clinical description for the prediction.
  String get clinicalNote {
    switch (predictionIndex) {
      case 0: return 'No suspicious findings detected. Routine screening recommended.';
      case 1: return 'Benign finding detected. Follow-up as per physician recommendation.';
      case 2: return 'Suspicious finding detected. Immediate clinical evaluation required.';
      default: return '';
    }
  }
}
