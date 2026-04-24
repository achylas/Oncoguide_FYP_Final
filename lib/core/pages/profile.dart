import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../conts/colors.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _uid;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = await _auth.authStateChanges().first;
      if (user == null) throw Exception("User not logged in");

      _uid = user.uid;

      final doc =
      await _firestore.collection('doctors').doc(_uid).get();

      if (!doc.exists) throw Exception("Doctor profile not found");

      final data = doc.data()!;

      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _specController.text = data['specialization'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _emailController.text = user.email ?? ''; // 🔥 always from Auth
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }


  Future<void> _saveDoctorData() async {
    try {
      setState(() => _isLoading = true);

      await _firestore.collection('doctors').doc(_uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _specController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile updated successfully"),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.getBackground(context),
      body: Stack(
        children: [
          FadeIn(
            duration: const Duration(milliseconds: 1200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                    AppColors.surfaceDark.withOpacity(0.3),
                    AppColors.backgroundDark,
                    AppColors.backgroundDark,
                  ]
                      : [
                    AppColors.ribbonGradient.colors[0].withOpacity(0.12),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildEnhancedHeader(),
                  const SizedBox(height: 32),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildQuickStats(),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel("Professional Identity"),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          "Full Name",
                          _nameController,
                          Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          "Specialization",
                          _specController,
                          Icons.medical_services_rounded,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionLabel("Contact Information"),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          "Phone Number",
                          _phoneController,
                          Icons.phone_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          "Email Address",
                          _emailController,
                          Icons.email_rounded,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionLabel("Professional Biography"),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          "About Me",
                          _bioController,
                          Icons.description_rounded,
                          maxLines: 5,
                          minLines: 4,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_isEditing) {
            _saveDoctorData();
          }
          setState(() => _isEditing = !_isEditing);
        },
        backgroundColor: _isEditing ? AppColors.success : AppColors.primary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded),
        label: Text(_isEditing ? "Save Changes" : "Edit Profile",
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEnhancedHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: HeaderWaveClipper(),
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.accent.withOpacity(0.8),
                ],
              )
                  : AppColors.ribbonGradient,
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 30,
          child: Pulse(
            duration: const Duration(milliseconds: 1800),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
        ),
        Positioned(
          top: 90,
          left: 40,
          child: Pulse(
            duration: const Duration(milliseconds: 2200),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 50),
            ZoomIn(
              duration: const Duration(milliseconds: 1000),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDark
                          ? LinearGradient(
                        colors: [AppColors.accent, AppColors.primary],
                      )
                          : AppColors.accentGradient,
                      boxShadow: isDark
                          ? null
                          : [
                        BoxShadow(
                          color: AppColors.primaryDark.withOpacity(0.35),
                          blurRadius: 25,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: CircleAvatar(
                      radius: 68,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 62,
                        backgroundImage: const NetworkImage(
                          'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                        ),
                      ),
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCard("150+", "Patients", const Color(0xFF1976D2), Icons.people_alt_rounded),
          _statCard("12+", "Years", const Color(0xFF388E3C), Icons.timeline_rounded),
          _statCard("4.9", "Rating", const Color(0xFFE91E63), Icons.star_rounded),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color accentColor, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: BounceInUp(
        duration: const Duration(milliseconds: 1000),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withOpacity(isDark ? 0.5 : 0.7),
              width: 1.8,
            ),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: accentColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      String label,
      TextEditingController controller,
      IconData icon, {
        int maxLines = 1,
        int minLines = 1,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmailField = label.toLowerCase().contains("email");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isEditing
              ? Color(0xFFE91E63)
              : AppColors.getBorder(context),
          width: _isEditing ? 2.5 : 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.getPrimaryGradient(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.getTextTertiary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  enabled: _isEditing && !isEmailField,
                  maxLines: maxLines,
                  minLines: minLines,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.getTextPrimary(context),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);

    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - 40);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height - 80);
    final secondEndPoint = Offset(size.width, size.height - 60);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}