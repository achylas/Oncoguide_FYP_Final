import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../conts/colors.dart';
import '../../widgets/app_text_feild.dart';
import '../../widgets/buttons/animated_buttons.dart';
import '../../widgets/resuable_top_bar.dart';
import '../../widgets/step_indicator.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController menarcheAgeController = TextEditingController();
  final TextEditingController menopauseAgeController = TextEditingController();
  final TextEditingController firstChildAgeController = TextEditingController();
  final TextEditingController childrenController = TextEditingController();
  final TextEditingController breastfeedingController = TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController medicalHistoryController = TextEditingController();
  final TextEditingController medicationsController = TextEditingController();
  final TextEditingController commentsController = TextEditingController();
  final TextEditingController imcController = TextEditingController();
  final TextEditingController biopsiesController = TextEditingController();

  int currentStep = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    [
      nameController, ageController, weightController, menarcheAgeController,
      menopauseAgeController, firstChildAgeController, childrenController,
      breastfeedingController, allergiesController, medicalHistoryController,
      medicationsController, commentsController, imcController, biopsiesController,
    ].forEach((c) => c.dispose());
    _pageController.dispose();
    super.dispose();
  }

  void nextStep() {
    // Validate current step before advancing
    String? error;
    if (currentStep == 0) {
      if (nameController.text.trim().isEmpty) error = 'Full name is required';
      else if (ageController.text.trim().isEmpty) error = 'Age is required';
      else if (weightController.text.trim().isEmpty) error = 'Weight is required';
      else if (imcController.text.trim().isEmpty) error = 'BMI is required';
    } else if (currentStep == 1) {
      if (menarcheAgeController.text.trim().isEmpty) error = 'Menarche age is required';
      else if (childrenController.text.trim().isEmpty) error = 'Number of children is required';
      else if (breastfeedingController.text.trim().isEmpty) error = 'Breastfeeding duration is required';
      else if (biopsiesController.text.trim().isEmpty) error = 'Number of biopsies is required';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    if (currentStep < 2) {
      setState(() => currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> savePatient() async {
    await FirebaseFirestore.instance.collection('patients').add({
      'name': nameController.text.trim(),
      'age': int.parse(ageController.text),
      'weight': int.parse(weightController.text),
      'reproductive': {
        'menarcheAge': int.parse(menarcheAgeController.text),
        'menopauseAge': int.parse(menopauseAgeController.text),
        'firstChildAge': int.parse(firstChildAgeController.text),
        'numberOfChildren': int.parse(childrenController.text),
        'breastfeedingMonths': int.parse(breastfeedingController.text),
      },
      'medical': {
        'allergies': allergiesController.text.trim(),
        'history': medicalHistoryController.text.trim(),
        'medications': medicationsController.text.trim(),
        'comments': commentsController.text.trim(),
      },
      'clinicalAssessment': {
        'imc': imcController.text.trim().isNotEmpty
            ? double.parse(imcController.text.trim())
            : null,
        'biopsies': biopsiesController.text.trim().isNotEmpty
            ? int.parse(biopsiesController.text.trim())
            : null,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Patient added successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ReusableTopBar(
        title: 'Add New Patient',
        subtitle: const Text('Patient registration'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      backgroundColor: AppColors.getBackground(context),
      body: Column(
        children: [
          // Step Indicator
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: AppColors.borderDark) : null,
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: StepIndicator(currentStep: currentStep),
          ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _BasicInfoStep(
                  nameController: nameController,
                  ageController: ageController,
                  weightController: weightController,
                  imcController: imcController,
                ),
                _CancerInfoStep(
                  menarcheAgeController: menarcheAgeController,
                  menopauseAgeController: menopauseAgeController,
                  firstChildAgeController: firstChildAgeController,
                  childrenController: childrenController,
                  breastfeedingController: breastfeedingController,
                  biopsiesController: biopsiesController,
                ),
                _MedicalInfoStep(
                  allergiesController: allergiesController,
                  medicalHistoryController: medicalHistoryController,
                  medicationsController: medicationsController,
                  commentsController: commentsController,
                ),
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              border: isDark
                  ? Border(top: BorderSide(color: AppColors.borderDark))
                  : null,
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (currentStep > 0) ...[
                    Expanded(
                      child: AnimatedButton(
                        text: 'Previous',
                        isPrimary: false,
                        onPressed: previousStep,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    flex: currentStep > 0 ? 1 : 1,
                    child: AnimatedButton(
                      text: currentStep == 2 ? 'Save Patient' : 'Continue',
                      onPressed: currentStep == 2 ? savePatient : nextStep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// STEP 1: Basic Information
class _BasicInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController weightController;
  final TextEditingController imcController;

  const _BasicInfoStep({
    required this.nameController,
    required this.ageController,
    required this.weightController,
    required this.imcController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.getPrimaryGradient(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: AppColors.shadowPink,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Basic Information', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Patient identification details', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: AppColors.borderDark) : null,
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Full Name', Icons.badge_outlined, context),
                const SizedBox(height: 8),
                AppTextField(controller: nameController, hintText: 'Enter patient full name'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Age', Icons.calendar_today_outlined, context),
                          const SizedBox(height: 8),
                          AppTextField(controller: ageController, hintText: 'Years', keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Weight', Icons.monitor_weight_outlined, context),
                          const SizedBox(height: 8),
                          AppTextField(controller: weightController, hintText: 'Kg', keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('BMI (IMC)', Icons.analytics_outlined, context),
                const SizedBox(height: 8),
                AppTextField(
                  controller: imcController,
                  hintText: 'Body Mass Index (e.g., 23.5)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getInfoBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(isDark ? 0.5 : 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please ensure all information is accurate for proper patient care',
                    style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
      ],
    );
  }
}

// STEP 2: Cancer Info
class _CancerInfoStep extends StatelessWidget {
  final TextEditingController menarcheAgeController;
  final TextEditingController menopauseAgeController;
  final TextEditingController firstChildAgeController;
  final TextEditingController childrenController;
  final TextEditingController breastfeedingController;
  final TextEditingController biopsiesController;

  const _CancerInfoStep({
    required this.menarcheAgeController,
    required this.menopauseAgeController,
    required this.firstChildAgeController,
    required this.childrenController,
    required this.breastfeedingController,
    required this.biopsiesController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.primary.withOpacity(0.8), AppColors.accent.withOpacity(0.8)]
                    : [AppColors.gradientPink1, AppColors.gradientBlue2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: AppColors.shadowPink, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_border, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reproductive Health', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Risk assessment factors', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _buildSectionCard(
            context: context,
            title: 'Menstrual History',
            icon: Icons.water_drop_outlined,
            children: [
              _buildFieldWithLabel('Menarche Age', 'Age at first period', menarcheAgeController, context),
              const SizedBox(height: 20),
              _buildFieldWithLabel('Menopause Age', 'Age at menopause (if applicable)', menopauseAgeController, context),
            ],
          ),
          const SizedBox(height: 20),

          _buildSectionCard(
            context: context,
            title: 'Pregnancy History',
            icon: Icons.child_care_outlined,
            children: [
              _buildFieldWithLabel('Age at First Child', 'Years', firstChildAgeController, context),
              const SizedBox(height: 20),
              _buildFieldWithLabel('Number of Children', 'Total number of children', childrenController, context),
              const SizedBox(height: 20),
              _buildFieldWithLabel('Breastfeeding Duration', 'Total months breastfed', breastfeedingController, context),
            ],
          ),
          const SizedBox(height: 20),

          _buildSectionCard(
            context: context,
            title: 'Clinical Assessment',
            icon: Icons.biotech_outlined,
            iconColor: AppColors.accent,
            children: [
              _buildFieldWithLabel('Number of Biopsies', 'Total number performed', biopsiesController, context),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getWarningBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(isDark ? 0.5 : 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security_outlined, color: AppColors.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This information helps assess breast cancer risk factors and diagnostic status',
                    style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldWithLabel(String label, String hint, TextEditingController controller, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        const SizedBox(height: 8),
        AppTextField(controller: controller, hintText: hint, keyboardType: TextInputType.number),
      ],
    );
  }
}

// STEP 3: Medical Info
class _MedicalInfoStep extends StatelessWidget {
  final TextEditingController allergiesController;
  final TextEditingController medicalHistoryController;
  final TextEditingController medicationsController;
  final TextEditingController commentsController;

  const _MedicalInfoStep({
    required this.allergiesController,
    required this.medicalHistoryController,
    required this.medicationsController,
    required this.commentsController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.getAccentGradient(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: AppColors.shadowLight, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_information_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medical Information', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Health history and medications', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: AppColors.borderDark) : null,
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldSection(
                  context: context,
                  icon: Icons.warning_amber_outlined,
                  label: 'Allergies',
                  hint: 'List any known allergies',
                  controller: allergiesController,
                  maxLines: 2,
                  iconColor: AppColors.danger,
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: AppColors.getDivider(context)),
                const SizedBox(height: 24),

                _buildFieldSection(
                  context: context,
                  icon: Icons.history_outlined,
                  label: 'Medical History',
                  hint: 'Previous diagnoses, surgeries, conditions',
                  controller: medicalHistoryController,
                  maxLines: 3,
                  iconColor: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: AppColors.getDivider(context)),
                const SizedBox(height: 24),

                _buildFieldSection(
                  context: context,
                  icon: Icons.medication_outlined,
                  label: 'Current Medications',
                  hint: 'List all current medications and dosages',
                  controller: medicationsController,
                  maxLines: 2,
                  iconColor: AppColors.accent,
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: AppColors.getDivider(context)),
                const SizedBox(height: 24),

                _buildFieldSection(
                  context: context,
                  icon: Icons.note_outlined,
                  label: 'Additional Notes',
                  hint: 'Any other relevant information',
                  controller: commentsController,
                  maxLines: 3,
                  iconColor: AppColors.getTextSecondary(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSuccessBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(isDark ? 0.5 : 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Review all information before saving the patient record',
                    style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFieldSection({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required int maxLines,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(controller: controller, hintText: hint, maxLines: maxLines),
      ],
    );
  }
}