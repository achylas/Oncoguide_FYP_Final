import 'dart:io';

import 'package:flutter/material.dart';
import 'package:oncoguide_v2/core/pages/new_analysis/screens/analysis_loading_screen.dart';
import '../../../conts/colors.dart';
import '../../../widgets/resuable_top_bar.dart';
import '../widgets/bottom_cta.dart';
import '../widgets/imaging_card.dart';
import '../widgets/learn_more_section.dart';
import '../widgets/progress_card.dart';
import '../widgets/quick_overview_card.dart';
import '../widgets/section_header.dart';
import '../widgets/tabular_data_card.dart';
import 'existing_patient.dart';

enum ImagingType { ultrasound, mammogram, both }

class NewAnalysisScreen extends StatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen>
    with TickerProviderStateMixin {
  bool tabularAdded = false;
  Set<ImagingType> selectedImaging = {};
  bool _showFullInfo = false;
  Map<String, dynamic>? selectedPatient;
  Map<ImagingType, File?> uploadedImages = {
    ImagingType.mammogram: null,
    ImagingType.ultrasound: null,
  };

  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeIn),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut),
    );

    _headerAnimController.forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ReusableTopBar(
        title: 'New Analysis Screen',
        subtitle: const Text('Structured data & imaging input'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const QuickOverviewCard(),
                    const SizedBox(height: 24),
                    ProgressCard(
                      tabularAdded: tabularAdded,
                      selectedImaging: selectedImaging,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      "Setup Your Analysis",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.getTextPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Complete both steps to start AI diagnosis",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                        step: "Step 1",
                        title: "Clinical Data",
                        isLocked: false),
                    const SizedBox(height: 12),
                    TabularDataCard(
                      tabularAdded: tabularAdded,
                      selectedPatient: selectedPatient,
                      onNewPatient: () {
                        setState(() {
                          tabularAdded = true;
                          selectedPatient = {
                            'name': 'New Patient',
                            'age': 0,
                            'status': 'New Entry',
                          };
                        });
                      },
                      onSelectExisting: () async {
                        final patient = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SelectPatientScreen(),
                          ),
                        );
                        if (patient != null && mounted) {
                          setState(() {
                            tabularAdded = true;
                            selectedPatient = patient;
                          });
                        }
                      },
                      onEditPatient: () async {
                        final patient = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SelectPatientScreen(),
                          ),
                        );
                        if (patient != null && mounted) {
                          setState(() {
                            selectedPatient = patient;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      step: "Step 2",
                      title: "Medical Imaging",
                      isLocked: !tabularAdded,
                    ),
                    const SizedBox(height: 6),
                    _buildImagingInfoRow(context),
                    const SizedBox(height: 12),
                    ImagingCard(
                      type: ImagingType.mammogram,
                      title: 'Mammogram',
                      description: 'X-ray imaging of breast tissue',
                      icon: Icons.image_search_rounded,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Color(0xFFFF6F91), Color(0xFFFF8FA3)]
                            : [Color(0xFFFF6F91), Color(0xFFFF8FA3)],
                      ),
                      isSelected:
                      selectedImaging.contains(ImagingType.mammogram),
                      isDisabled: !tabularAdded,
                      uploadedFile: uploadedImages[ImagingType.mammogram],
                      onToggle: (file) =>
                          _toggleImaging(ImagingType.mammogram, file),
                    ),
                    const SizedBox(height: 12),
                    ImagingCard(
                      type: ImagingType.ultrasound,
                      title: 'Ultrasound',
                      description: 'Sound wave imaging for dense tissue',
                      icon: Icons.waves_rounded,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Color(0xFF6C63FF), Color(0xFF8B84FF)]
                            : [Color(0xFF6C63FF), Color(0xFF8B84FF)],
                      ),
                      isSelected:
                      selectedImaging.contains(ImagingType.ultrasound),
                      isDisabled: !tabularAdded,
                      uploadedFile: uploadedImages[ImagingType.ultrasound],
                      onToggle: (file) =>
                          _toggleImaging(ImagingType.ultrasound, file),
                    ),
                    const SizedBox(height: 32),
                    LearnMoreSection(
                      showFullInfo: _showFullInfo,
                      onToggle: () =>
                          setState(() => _showFullInfo = !_showFullInfo),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BottomCTA(
        tabularAdded: tabularAdded,
        selectedImaging: selectedImaging,
        onStartAnalysis: () {
          if (tabularAdded && selectedImaging.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalysisLoadingScreen(
                  selectedPatient: selectedPatient!,
                  uploadedImages: uploadedImages,
                  selectedImagingTypes: selectedImaging,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return FadeTransition(
      opacity: _headerFadeAnimation,
      child: SlideTransition(
        position: _headerSlideAnimation,
        child: Container(
          // Keep your existing top bar content
        ),
      ),
    );
  }

  Widget _buildImagingInfoRow(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.getTextSecondary(context),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            "Select at least one • You can select both for better analysis",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleImaging(ImagingType type, File? newFile) async {
    if (newFile != null) {
      setState(() {
        uploadedImages[type] = newFile;
        selectedImaging.add(type);
      });
      return;
    }

    setState(() {
      selectedImaging.remove(type);
      uploadedImages[type] = null;
    });
  }
}