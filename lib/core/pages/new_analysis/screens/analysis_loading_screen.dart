import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/new_analysis_screen.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/report_service.dart';
import '../../../conts/colors.dart';
import '../../../widgets/resuable_top_bar.dart';
import 'scan_result.dart';
///  1. Validates the mammogram image (if selected) via the gatekeeper model
///  2. Runs the tabular risk prediction via the Random Forest model
///  3. Navigates to [ScanResultPage] with real results
class AnalysisLoadingScreen extends StatefulWidget {
  final Map<String, dynamic> selectedPatient;
  final Map<ImagingType, File?> uploadedImages;
  final Set<ImagingType> selectedImagingTypes;
  /// When true, skip the gatekeeper validation step (images already validated by radiologist).
  final bool skipValidation;

  const AnalysisLoadingScreen({
    super.key,
    required this.selectedPatient,
    required this.uploadedImages,
    required this.selectedImagingTypes,
    this.skipValidation = false,
  });

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  _Step _currentStep = _Step.validating;
  String _statusMessage = 'Validating mammogram image…';
  bool _hasError = false;
  String _errorMessage = '';

  // Guard: ensures the pipeline (and report save) runs exactly once
  bool _pipelineStarted = false;

  // Pulse animation for the spinner ring
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Image carousel animation
  late AnimationController _imageController;
  late Animation<double> _imageFadeAnimation;
  int _activeImageIndex = 0;
  late List<MapEntry<ImagingType, File>> _imagesToShow;
  late List<String> _imageLabels;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Build list of uploaded images to cycle through
    _imagesToShow = widget.uploadedImages.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!))
        .toList();

    _imageLabels = _imagesToShow.map((e) {
      switch (e.key) {
        case ImagingType.mammogram:    return 'Mammogram (CC)';
        case ImagingType.mammogramMlo: return 'Mammogram (MLO)';
        case ImagingType.ultrasound:   return 'Ultrasound';
        default:                       return 'Scan';
      }
    }).toList();

    // Fade animation for image transitions
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _imageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeIn),
    );
    if (_imagesToShow.isNotEmpty) {
      _imageController.forward();
      _startImageCycling();
    }

    // Kick off the pipeline after the first frame — guarded against double-run
    WidgetsBinding.instance.addPostFrameCallback((_) => _showConsentThenRun());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // ── Image cycling ──────────────────────────────────────────────────────────
  void _startImageCycling() {
    if (_imagesToShow.length <= 1) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _imageController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _activeImageIndex = (_activeImageIndex + 1) % _imagesToShow.length;
        });
        _imageController.forward().then((_) => _startImageCycling());
      });
    });
  }

  // ── Consent ────────────────────────────────────────────────────────────────
  Future<void> _showConsentThenRun() async {
    if (_pipelineStarted) return;

    final patientName = widget.selectedPatient['name']?.toString() ?? 'this patient';

    final consented = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1D1F33) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Patient Consent',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before running AI-assisted analysis for $patientName, please confirm:',
                style: TextStyle(
                  fontSize: 13.5, height: 1.5,
                  color: isDark ? const Color(0xFFB0B3C5) : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 14),
              _consentPoint(isDark, Icons.check_circle_outline_rounded,
                  'The patient has been informed that AI will assist in their diagnosis.'),
              _consentPoint(isDark, Icons.check_circle_outline_rounded,
                  'The patient has consented to their medical images and clinical data being processed.'),
              _consentPoint(isDark, Icons.check_circle_outline_rounded,
                  'This AI analysis is a decision-support tool and does not replace clinical judgment.'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Results must be reviewed by a qualified medical professional before any clinical decision.',
                    style: TextStyle(
                      fontSize: 11.5, height: 1.5,
                      color: isDark ? const Color(0xFFB0B3C5) : Colors.brown[700],
                    ),
                  )),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('I Confirm — Proceed',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (consented != true) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _runPipeline();
  }

  Widget _consentPoint(bool isDark, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(
          fontSize: 12.5, height: 1.5,
          color: isDark ? const Color(0xFFB0B3C5) : Colors.grey[700],
        ))),
      ]),
    );
  }

  // ── Pipeline ───────────────────────────────────────────────────────────────
  Future<void> _runPipeline() async {
    // Guard: only run once even if the widget rebuilds
    if (_pipelineStarted) return;
    _pipelineStarted = true;
    // ── Step 1a: Mammogram validation (skip if images from DB) ──────────
    final mammogramFile = widget.uploadedImages[ImagingType.mammogram];
    MammogramValidationResult? validationResult;

    if (!widget.skipValidation &&
        widget.selectedImagingTypes.contains(ImagingType.mammogram) &&
        mammogramFile != null) {
      _setStep(_Step.validating, 'Validating mammogram image…');

      try {
        validationResult = await ApiService.validateMammogram(mammogramFile);
      } on ApiException catch (e) {
        _showError('Validation failed (${e.statusCode}): ${e.message}');
        return;
      } catch (e) {
        _showError('Mammogram validation error:\n\n$e');
        return;
      }

      if (!validationResult.isValid) {
        if (!mounted) return;
        await _showInvalidImageDialog(
            'Mammogram', validationResult.message);
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    // ── Step 1b: Ultrasound validation (skip if images from DB) ─────────
    final ultrasoundFile = widget.uploadedImages[ImagingType.ultrasound];
    MammogramValidationResult? usValidationResult;

    if (!widget.skipValidation &&
        widget.selectedImagingTypes.contains(ImagingType.ultrasound) &&
        ultrasoundFile != null) {
      _setStep(_Step.validating, 'Validating ultrasound image…');

      try {
        usValidationResult =
            await ApiService.validateUltrasound(ultrasoundFile);
      } on ApiException catch (e) {
        _showError('Validation failed (${e.statusCode}): ${e.message}');
        return;
      } catch (e) {
        _showError('Ultrasound validation error:\n\n$e');
        return;
      }

      if (!usValidationResult.isValid) {
        if (!mounted) return;
        await _showInvalidImageDialog(
            'Ultrasound', usValidationResult.message);
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    // ── Step 2: Tabular prediction ───────────────────────────────────────────
    _setStep(_Step.predicting, 'Running risk prediction model…');

    TabularPredictionResult? tabularResult;
    try {
      tabularResult = await ApiService.predictTabular(widget.selectedPatient);
    } on ApiException catch (e) {
      _showError('Prediction failed (${e.statusCode}): ${e.message}');
      return;
    } catch (e) {
      _showError('Risk prediction error:\n\n$e');
      return;
    }

    // ── Step 2b: Ultrasound analysis (if ultrasound selected & valid) ─────────
    UltrasoundAnalysisResult? usAnalysisResult;
    if (widget.selectedImagingTypes.contains(ImagingType.ultrasound) &&
        ultrasoundFile != null &&
        (usValidationResult == null || usValidationResult.isValid)) {
      _setStep(_Step.predicting, 'Analysing ultrasound image…');
      try {
        usAnalysisResult = await ApiService.analyzeUltrasound(ultrasoundFile);
      } on ApiException catch (e) {
        _showError('Ultrasound analysis failed (${e.statusCode}): ${e.message}');
        return;
      } catch (e) {
        _showError('Ultrasound analysis error:\n\n$e');
        return;
      }
    }

    // ── Step 2c: Density analysis (if both CC + MLO uploaded) ────────────────
    DensityAnalysisResult? densityResult;
    final mloFile = widget.uploadedImages[ImagingType.mammogramMlo];
    if (widget.selectedImagingTypes.contains(ImagingType.mammogram) &&
        widget.selectedImagingTypes.contains(ImagingType.mammogramMlo) &&
        mammogramFile != null &&
        mloFile != null) {
      _setStep(_Step.predicting, 'Analysing mammogram density (CC + MLO)…');
      try {
        densityResult = await ApiService.analyzeDensity(
          ccFile:  mammogramFile,
          mloFile: mloFile,
        );
      } on ApiException catch (e) {
        // Non-fatal — log and continue without density result
        print('[!] Density analysis failed (${e.statusCode}): ${e.message}');
      } catch (e) {
        print('[!] Density analysis error: $e');
      }
    }

    // ── Step 2d: Mammogram analysis (BI-RADS classification) ─────────────────
    MammogramAnalysisResult? mammogramAnalysisResult;
    if (widget.selectedImagingTypes.contains(ImagingType.mammogram) &&
        mammogramFile != null &&
        (validationResult == null || validationResult.isValid)) {
      _setStep(_Step.predicting, 'Analysing mammogram findings…');
      try {
        mammogramAnalysisResult = await ApiService.analyzeMammogram(mammogramFile);
      } on ApiException catch (e) {
        // Non-fatal — log and continue without mammogram analysis result
        print('[!] Mammogram analysis failed (${e.statusCode}): ${e.message}');
      } catch (e) {
        print('[!] Mammogram analysis error: $e');
      }
    }

    // ── Step 3: Save report ───────────────────────────────────────────────────
    _setStep(_Step.done, 'Saving report…');
    ReportService.saveReport(
      patient: widget.selectedPatient,
      imagingTypes: widget.selectedImagingTypes,
      uploadedImages: widget.uploadedImages,
      tabularResult: tabularResult,
      mammogramValidation: validationResult,
      ultrasoundValidation: usValidationResult,
      ultrasoundAnalysis: usAnalysisResult,
      densityAnalysis: densityResult,
      mammogramAnalysis: mammogramAnalysisResult,
    ); // fire-and-forget — don't block navigation

    // ── Step 4: Navigate to results ───────────────────────────────────────────
    _setStep(_Step.done, 'Analysis complete!');
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultPage(
          selectedPatient: widget.selectedPatient,
          uploadedImages: widget.uploadedImages,
          selectedImagingTypes: widget.selectedImagingTypes,
          tabularResult: tabularResult,
          mammogramValidation: validationResult,
          ultrasoundValidation: usValidationResult,
          ultrasoundAnalysis: usAnalysisResult,
          densityAnalysis: densityResult,
          mammogramAnalysis: mammogramAnalysisResult,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setStep(_Step step, String message) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _statusMessage = message;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }

  Future<void> _showInvalidImageDialog(String scanType, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1D1F33)
                : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text('Invalid $scanType Image',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Go Back & Re-upload',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ReusableTopBar(
        title: 'AI Analysis',
        subtitle: const Text('Processing your data'),
        showBackButton: false,
        showSettingsButton: false,
      ),
      backgroundColor:
          isDark ? const Color(0xFF0A0E21) : const Color(0xFFF8F9FB),
      body: SafeArea(
        child: _hasError ? _buildErrorView(isDark) : _buildLoadingView(isDark),
      ),
    );
  }

  Widget _buildLoadingView(bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Uploaded image preview ──────────────────────────────────────
            if (_imagesToShow.isNotEmpty) ...[
              _buildImagePreview(isDark),
              const SizedBox(height: 32),
            ],

            // Animated spinner with icon inside
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6F91).withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    Icon(
                      Icons.psychology_rounded,
                      color: Colors.white.withOpacity(0.85),
                      size: 36,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Step indicators
            _buildStepRow(
              icon: Icons.shield_outlined,
              label: widget.skipValidation
                  ? 'Pre-validated by Radiologist'
                  : 'Image Validation',
              state: widget.skipValidation
                  ? _StepState.done
                  : _stepState(_Step.validating),
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildStepRow(
              icon: Icons.analytics_outlined,
              label: 'Risk Prediction',
              state: _stepState(_Step.predicting),
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildStepRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Generating Report',
              state: _stepState(_Step.done),
              isDark: isDark,
            ),

            const SizedBox(height: 40),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFB0B3C5)
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool isDark) {
    final entry = _imagesToShow[_activeImageIndex];
    final label = _imageLabels[_activeImageIndex];
    final file  = entry.value;

    return Column(
      children: [
        // Label + dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F91).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6F91).withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_rounded,
                      size: 13, color: Color(0xFFFF6F91)),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6F91),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Image card
        FadeTransition(
          opacity: _imageFadeAnimation,
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6F91).withOpacity(0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6F91).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The actual image — web uses Image.network (blob URL),
                  // mobile uses Image.file
                  kIsWeb
                      ? Image.network(
                          file.path,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imagePlaceholder(isDark),
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imagePlaceholder(isDark),
                        ),

                  // Subtle dark gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // "Analysing…" badge
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Analysing…',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Dot indicators (only when multiple images)
        if (_imagesToShow.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_imagesToShow.length, (i) {
              final active = i == _activeImageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFF6F91)
                      : (isDark
                          ? const Color(0xFF4A4D6A)
                          : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _imagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A1D2E) : const Color(0xFFF0F2F8),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: isDark ? const Color(0xFF4A4D6A) : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String label,
    required _StepState state,
    required bool isDark,
  }) {
    Color color;
    Widget trailing;

    switch (state) {
      case _StepState.active:
        color = const Color(0xFFFF6F91);
        trailing = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF6F91),
          ),
        );
        break;
      case _StepState.done:
        color = AppColors.success;
        trailing = const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 20);
        break;
      case _StepState.pending:
        color = isDark ? const Color(0xFF4A4D6A) : Colors.grey[400]!;
        trailing = Icon(Icons.radio_button_unchecked,
            color: color, size: 20);
        break;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: state == _StepState.pending
                  ? (isDark
                      ? const Color(0xFF4A4D6A)
                      : Colors.grey[400])
                  : AppColors.getTextPrimary(context),
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildErrorView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 56),
          ),
          const SizedBox(height: 24),
          Text(
            'Analysis Failed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? const Color(0xFFB0B3C5) : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Go Back & Fix'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step state helpers ─────────────────────────────────────────────────────
  _StepState _stepState(_Step step) {
    final order = [_Step.validating, _Step.predicting, _Step.done];
    final current = order.indexOf(_currentStep);
    final target = order.indexOf(step);

    if (target < current) return _StepState.done;
    if (target == current) return _StepState.active;
    return _StepState.pending;
  }
}

enum _Step { validating, predicting, done }

enum _StepState { pending, active, done }
