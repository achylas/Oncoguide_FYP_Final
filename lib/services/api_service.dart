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
      shapValues: rawShap.map((k, v) => MapEntry(k, (v as num).toDouble())),
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
  static Map<String, dynamic> _buildTabularPayload(
      Map<String, dynamic> patient) {
    double d(dynamic v, [double fallback = 0.0]) =>
        (v as num?)?.toDouble() ?? fallback;
    int i(dynamic v, [int fallback = 0]) =>
        (v as num?)?.toInt() ?? fallback;

    final reproductive =
        patient['reproductive'] as Map<String, dynamic>? ?? {};
    final clinical =
        patient['clinicalAssessment'] as Map<String, dynamic>? ?? {};

    return {
      'age': d(patient['age']),
      'menarche': d(reproductive['menarche'] ?? patient['menarche'], 13),
      'menopause':
          d(reproductive['menopauseAge'] ?? patient['menopause'], 0),
      'agefirst': d(
          reproductive['ageFirstPregnancy'] ?? patient['agefirst'], 0),
      'children':
          d(reproductive['numberOfChildren'] ?? patient['children'], 0),
      'breastfeeding':
          i(reproductive['breastfeeding'] ?? patient['breastfeeding']),
      'imc': d(clinical['imc'] ?? patient['imc'], 25.0),
      'weight': d(patient['weight'], 60.0),
      'menopause_status': i(
          reproductive['menopauseStatus'] ?? patient['menopause_status']),
      'pregnancy':
          i(reproductive['pregnancy'] ?? patient['pregnancy']),
      'family_history':
          i(patient['familyHistory'] ?? patient['family_history']),
      'family_history_count': d(
          patient['familyHistoryCount'] ?? patient['family_history_count']),
      'family_history_degree': d(
          patient['familyHistoryDegree'] ??
              patient['family_history_degree']),
      'exercise_regular':
          i(patient['exerciseRegular'] ?? patient['exercise_regular']),
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
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: rawProbs.map((k, v) => MapEntry(k, (v as num).toDouble())),
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
      confidence:    (json['confidence']    as num).toDouble(),
      probabilities: rawProbs.map((k, v) => MapEntry(k, (v as num).toDouble())),
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
