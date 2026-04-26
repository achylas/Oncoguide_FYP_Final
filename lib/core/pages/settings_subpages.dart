// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../conts/colors.dart';
import '../widgets/resuable_top_bar.dart';
import 'profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _subPageScaffold({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Widget body,
}) {
  return Scaffold(
    backgroundColor: AppColors.getBackground(context),
    appBar: ReusableTopBar(
      title: title,
      subtitle: Text(subtitle),
      showSettingsButton: false,
    ),
    body: body,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Profile Settings — navigates to DoctorProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Just push the existing full profile screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorProfileScreen()),
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Privacy & Security — change password
// ─────────────────────────────────────────────────────────────────────────────

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl     = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _loading     = false;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('Not signed in');

      // Re-authenticate with current password
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPwCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);

      // Update to new password
      await user.updatePassword(_newPwCtrl.text);

      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to update password';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        msg = 'New password is too weak (min 6 characters)';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Please log out and log back in before changing your password';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _subPageScaffold(
      context: context,
      title: 'Privacy & Security',
      subtitle: 'Change your password',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your current password to verify your identity, then set a new password.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _PwField(
                label: 'Current Password',
                controller: _currentPwCtrl,
                show: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _PwField(
                label: 'New Password',
                controller: _newPwCtrl,
                show: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  if (v == _currentPwCtrl.text) {
                    return 'New password must differ from current';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _PwField(
                label: 'Confirm New Password',
                controller: _confirmCtrl,
                show: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newPwCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PwField({
    required this.label,
    required this.controller,
    required this.show,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !show,
          validator: validator,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.cardBackgroundDark : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.getBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.getBorder(context).withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.danger),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.getTextTertiary(context),
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Help & Support — FAQs
// ─────────────────────────────────────────────────────────────────────────────

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  static const _faqs = [
    _Faq(
      q: 'What is OncoGuide?',
      a: 'OncoGuide is an AI-assisted breast cancer diagnostic platform designed for medical professionals. It combines clinical data, mammogram imaging, and ultrasound analysis to provide risk assessments and personalized clinical recommendations.',
    ),
    _Faq(
      q: 'How does the risk prediction model work?',
      a: 'The risk model uses a Random Forest classifier trained on clinical features including age, BMI, family history, reproductive history, and lifestyle factors. It outputs a risk percentage (0–100%) along with SHAP values that explain which factors contributed most to the prediction.',
    ),
    _Faq(
      q: 'What does the ultrasound analysis do?',
      a: 'The ultrasound model (EfficientNet-B3 with U-Net) classifies uploaded ultrasound images as Benign, Normal, or Malignant. It also generates a GradCAM heatmap highlighting the regions that most influenced the classification.',
    ),
    _Faq(
      q: 'What is mammogram density classification?',
      a: 'The density model uses a Siamese EfficientNetV2-S network that takes two mammogram views (CC and MLO) and classifies breast tissue density into BI-RADS categories A (Fatty), B (Scattered), C (Heterogeneous), or D (Extremely Dense). Higher density can reduce mammography sensitivity.',
    ),
    _Faq(
      q: 'How are images stored?',
      a: 'All uploaded images are securely stored in Supabase Storage (scan-reports bucket). Image metadata and analysis results are saved in Firebase Firestore. Images are associated with the patient record and accessible from the patient profile.',
    ),
    _Faq(
      q: 'Can I export or share a report?',
      a: 'Yes. From the Analysis Result screen, tap the "Share Report" button to generate a PDF containing the patient summary, risk score, SHAP values, ultrasound findings, GradCAM visualizations, and personalized clinical recommendations.',
    ),
    _Faq(
      q: 'What does "High Risk" mean?',
      a: 'A High Risk prediction (RF model output = 1) means the clinical data pattern is associated with elevated breast cancer risk. This does not constitute a diagnosis — it is a decision-support signal that should prompt further clinical evaluation.',
    ),
    _Faq(
      q: 'What is SHAP and why does it matter?',
      a: 'SHAP (SHapley Additive exPlanations) values quantify how much each clinical feature contributed to the risk prediction. Positive SHAP values increase risk; negative values decrease it. This helps clinicians understand which specific factors are driving the AI\'s assessment.',
    ),
    _Faq(
      q: 'Is this app a replacement for clinical judgment?',
      a: 'No. OncoGuide is a decision-support tool only. All AI outputs must be interpreted by a qualified medical professional in the context of the full clinical picture. The app does not provide diagnoses.',
    ),
    _Faq(
      q: 'How do I add a new patient?',
      a: 'From the Dashboard or Patients screen, tap "Add Patient" and complete the 3-step form: Basic Info (name, age, weight, BMI), Reproductive Health (menarche, menopause, pregnancy history), and Medical Info (allergies, history, medications).',
    ),
  ];

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _subPageScaffold(
      context: context,
      title: 'Help & Support',
      subtitle: 'Frequently asked questions',
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          final open = _expanded.contains(i);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBackgroundDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: open
                    ? AppColors.primary.withOpacity(0.4)
                    : AppColors.getBorder(context).withOpacity(0.3),
                width: open ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => setState(() {
                if (open) {
                  _expanded.remove(i);
                } else {
                  _expanded.add(i);
                }
              }),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            faq.q,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                        Icon(
                          open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ],
                    ),
                    if (open) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Text(
                          faq.a,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Send Feedback
// ─────────────────────────────────────────────────────────────────────────────

class SendFeedbackPage extends StatefulWidget {
  const SendFeedbackPage({super.key});

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  static const _feedbackEmail = 'inshk17@gmail.com';

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your feedback before sending')),
      );
      return;
    }
    setState(() => _sending = true);

    // Save feedback to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId':    user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? '',
        'subject':   _subjectCtrl.text.trim(),
        'message':   _messageCtrl.text.trim(),
        'rating':    _rating,
        'sentTo':    _feedbackEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() { _sending = false; _sent = true; });
    } catch (_) {
      setState(() => _sending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send feedback. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _subPageScaffold(
      context: context,
      title: 'Send Feedback',
      subtitle: 'Help us improve OncoGuide',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _sent ? _buildSuccessView(context) : _buildForm(context, isDark),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Feedback Sent!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thank you for your feedback.\nWe\'ll review it at $_feedbackEmail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _sent = false;
                  _subjectCtrl.clear();
                  _messageCtrl.clear();
                  _rating = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Send Another'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recipient info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your feedback will be sent to $_feedbackEmail',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Star rating
        Text(
          'Overall Rating',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? const Color(0xFFF59E0B) : Colors.grey[400],
                  size: 34,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Subject
        _FeedbackField(
          label: 'Subject (optional)',
          controller: _subjectCtrl,
          hint: 'e.g. Feature request, Bug report…',
          maxLines: 1,
          isDark: isDark,
          context: context,
        ),
        const SizedBox(height: 16),

        // Message
        _FeedbackField(
          label: 'Your Feedback',
          controller: _messageCtrl,
          hint: 'Tell us what you think, what\'s working well, or what could be improved…',
          maxLines: 6,
          isDark: isDark,
          context: context,
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool isDark;
  final BuildContext context;

  const _FeedbackField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: AppColors.getTextTertiary(context), fontSize: 13),
            filled: true,
            fillColor: isDark ? AppColors.cardBackgroundDark : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.getBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.getBorder(context).withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. About
// ─────────────────────────────────────────────────────────────────────────────

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _subPageScaffold(
      context: context,
      title: 'About',
      subtitle: 'OncoGuide v1.0.0',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App logo + name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OncoGuide',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _AboutSection(
              icon: Icons.info_outline_rounded,
              title: 'What is OncoGuide?',
              body:
                  'OncoGuide is an AI-powered breast cancer diagnostic assistant built for medical professionals. It integrates clinical risk prediction, mammogram analysis, ultrasound classification, and breast density assessment into a single streamlined workflow — helping doctors make faster, more informed decisions.',
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.psychology_outlined,
              title: 'AI Models',
              body:
                  'OncoGuide uses five deep learning models:\n\n'
                  '• Random Forest + SHAP — clinical risk prediction from patient data\n'
                  '• MobileNetV3 — mammogram image validation (gatekeeper)\n'
                  '• EfficientNet-B0 — ultrasound image validation (gatekeeper)\n'
                  '• EfficientNet-B3 U-Net — ultrasound classification (Benign / Normal / Malignant) with GradCAM\n'
                  '• Siamese EfficientNetV2-S — mammogram density classification (BI-RADS A–D) with GradCAM',
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.security_outlined,
              title: 'Data & Privacy',
              body:
                  'All patient data is stored securely in Firebase Firestore with role-based access control. Medical images are stored in Supabase Storage with public URLs accessible only through authenticated sessions. OncoGuide does not share patient data with third parties.',
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.warning_amber_outlined,
              title: 'Medical Disclaimer',
              body:
                  'OncoGuide is a clinical decision-support tool only. All AI outputs — including risk scores, ultrasound classifications, and density assessments — are intended to assist, not replace, the judgment of qualified medical professionals. No output from this application constitutes a medical diagnosis.',
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.code_outlined,
              title: 'Technology Stack',
              body:
                  'Mobile App: Flutter (Dart)\n'
                  'Backend API: FastAPI (Python) on HuggingFace Spaces\n'
                  'Database: Firebase Firestore\n'
                  'Storage: Supabase Storage\n'
                  'Authentication: Firebase Auth\n'
                  'Web Portal: React + Tailwind CSS',
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.mail_outline_rounded,
              title: 'Contact',
              body: 'For support, feedback, or inquiries:\ninshk17@gmail.com',
            ),

            const SizedBox(height: 32),

            Center(
              child: Text(
                '© 2025 OncoGuide. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextTertiary(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AboutSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
