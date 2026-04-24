import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/new_analysis_screen.dart';
import 'package:oncoguide_v2/services/api_service.dart';
import 'package:oncoguide_v2/services/report_service.dart';
import '../../../conts/colors.dart';
import '../../../widgets/resuable_top_bar.dart';
import 'scan_result.dart';

/// Shown while the app:
///  1. Validates the mammogram image (if selected) via the gatekeeper model
///  2. Runs the tabular risk prediction via the Random Forest model
///  3. Navigates to [ScanResultPage] with real results
class AnalysisLoadingScreen extends StatefulWidget {
  final Map<String, dynamic> selectedPatient;
  final Map<ImagingType, File?> uploadedImages;
  final Set<ImagingType> selectedImagingTypes;

  const AnalysisLoadingScreen({
    super.key,
    required this.selectedPatient,
    required this.uploadedImages,
    required this.selectedImagingTypes,
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

  // Pulse animation for the spinner ring
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    // Kick off the pipeline after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Pipeline ───────────────────────────────────────────────────────────────
  Future<void> _runPipeline() async {
    // ── Step 1a: Mammogram validation ───────────────────────────────────
    final mammogramFile = widget.uploadedImages[ImagingType.mammogram];
    MammogramValidationResult? validationResult;

    if (widget.selectedImagingTypes.contains(ImagingType.mammogram) &&
        mammogramFile != null) {
      _setStep(_Step.validating, 'Validating mammogram image…');

      try {
        validationResult = await ApiService.validateMammogram(mammogramFile);
      } on ApiException catch (e) {
        _showError('Validation failed (${e.statusCode}): ${e.message}');
        return;
      } catch (e) {
        _showError(
            'Could not reach the server. Make sure the backend is running.\n\n$e');
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

    // ── Step 1b: Ultrasound validation ───────────────────────────────────
    final ultrasoundFile = widget.uploadedImages[ImagingType.ultrasound];
    MammogramValidationResult? usValidationResult;

    if (widget.selectedImagingTypes.contains(ImagingType.ultrasound) &&
        ultrasoundFile != null) {
      _setStep(_Step.validating, 'Validating ultrasound image…');

      try {
        usValidationResult =
            await ApiService.validateUltrasound(ultrasoundFile);
      } on ApiException catch (e) {
        _showError('Validation failed (${e.statusCode}): ${e.message}');
        return;
      } catch (e) {
        _showError(
            'Could not reach the server. Make sure the backend is running.\n\n$e');
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
      _showError(
          'Could not reach the server. Make sure the backend is running.\n\n$e');
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
        _showError('Could not reach the server.\n\n$e');
        return;
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
            // Animated spinner
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
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Step indicators
            _buildStepRow(
              icon: Icons.shield_outlined,
              label: 'Image Validation',
              state: _stepState(_Step.validating),
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
      child: Padding(
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
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark
                    ? const Color(0xFFB0B3C5)
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
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
