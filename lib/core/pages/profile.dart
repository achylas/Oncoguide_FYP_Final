import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../conts/colors.dart';
import '../../services/storage_service.dart';

// ═══════════════════════════════════════════════════════════════════
// Entry point — checks profileComplete, routes to setup or view
// ═══════════════════════════════════════════════════════════════════

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _checking = true;
  bool _profileComplete = false;

  @override
  void initState() {
    super.initState();
    _checkProfileComplete();
  }

  Future<void> _checkProfileComplete() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _checking = false); return; }
      final doc = await FirebaseFirestore.instance.collection('doctors').doc(user.uid).get();
      setState(() {
        _profileComplete = doc.data()?['profileComplete'] == true;
        _checking = false;
      });
    } catch (_) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_profileComplete) {
      return _ProfileSetupScreen(
        onComplete: () => setState(() => _profileComplete = true),
      );
    }
    return const _ProfileViewScreen();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Setup Screen — shown once
// ═══════════════════════════════════════════════════════════════════

class _ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const _ProfileSetupScreen({required this.onComplete});

  @override
  State<_ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<_ProfileSetupScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _specCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _yearsCtrl   = TextEditingController();

  File? _pickedImage;
  bool  _saving = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? photoUrl;
      if (_pickedImage != null) {
        photoUrl = await StorageService.uploadFile(
          file: _pickedImage!,
          folder: 'doctor_profiles',
          fileName: '${user.uid}.jpg',
        );
      }
      await FirebaseFirestore.instance.collection('doctors').doc(user.uid).set({
        'name'             : _nameCtrl.text.trim(),
        'specialization'   : _specCtrl.text.trim(),
        'phone'            : _phoneCtrl.text.trim(),
        'hospital'         : _hospitalCtrl.text.trim(),
        'yearsOfExperience': int.tryParse(_yearsCtrl.text.trim()) ?? 0,
        'profileComplete'  : true,
        if (photoUrl != null) 'photoUrl': photoUrl,
      }, SetOptions(merge: true));
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _specCtrl.dispose(); _phoneCtrl.dispose();
    _hospitalCtrl.dispose(); _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button row (only shown when there's a screen to go back to)
                if (Navigator.canPop(context))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.primary, size: 16),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Complete Your Profile',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('One-time setup — takes 1 minute',
                                style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Photo picker
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                        child: _pickedImage == null
                            ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('Tap to add photo (optional)',
                    style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 28),

                _SetupField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _SetupField(controller: _specCtrl, label: 'Specialization', icon: Icons.medical_services_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _SetupField(controller: _phoneCtrl, label: 'Phone', icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _SetupField(controller: _hospitalCtrl, label: 'Hospital / Clinic Name', icon: Icons.local_hospital_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 14),
                _SetupField(controller: _yearsCtrl, label: 'Years of Experience', icon: Icons.timeline_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                      return null;
                    }),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save Profile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _SetupField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.getTextPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.getCardBackground(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorder(context).withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Profile View Screen
// ═══════════════════════════════════════════════════════════════════

class _ProfileViewScreen extends StatefulWidget {
  const _ProfileViewScreen();

  @override
  State<_ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<_ProfileViewScreen> {
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving  = false;

  String  _name             = '';
  String  _specialization   = '';
  String  _phone            = '';
  String  _hospital         = '';
  int     _yearsOfExperience = 0;
  String? _photoUrl;
  int     _patientCount     = 0;

  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _hospitalCtrl = TextEditingController();

  File?   _newPhoto;
  late String _uid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      _uid = user.uid;

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('doctors').doc(_uid).get(),
        FirebaseFirestore.instance.collection('patients').get(),
      ]);

      final doctorDoc    = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final patientsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (doctorDoc.exists) {
        final d = doctorDoc.data()!;
        _name              = d['name'] ?? '';
        _specialization    = d['specialization'] ?? '';
        _phone             = d['phone'] ?? '';
        _hospital          = d['hospital'] ?? '';
        _yearsOfExperience = (d['yearsOfExperience'] as num?)?.toInt() ?? 0;
        _photoUrl          = d['photoUrl'] as String?;
      }

      _patientCount = patientsSnap.docs.length;
      _nameCtrl.text     = _name;
      _phoneCtrl.text    = _phone;
      _hospitalCtrl.text = _hospital;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _newPhoto = File(picked.path));
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      String? newPhotoUrl = _photoUrl;
      if (_newPhoto != null) {
        newPhotoUrl = await StorageService.uploadFile(
          file: _newPhoto!,
          folder: 'doctor_profiles',
          fileName: '$_uid.jpg',
        );
      }
      await FirebaseFirestore.instance.collection('doctors').doc(_uid).update({
        'name'    : _nameCtrl.text.trim(),
        'phone'   : _phoneCtrl.text.trim(),
        'hospital': _hospitalCtrl.text.trim(),
        if (newPhotoUrl != null) 'photoUrl': newPhotoUrl,
      });
      setState(() {
        _name     = _nameCtrl.text.trim();
        _phone    = _phoneCtrl.text.trim();
        _hospital = _hospitalCtrl.text.trim();
        if (newPhotoUrl != null) _photoUrl = newPhotoUrl;
        _newPhoto  = null;
        _isEditing = false;
        _isSaving  = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success));
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _name.isNotEmpty ? _name[0].toUpperCase() : 'D';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _hospitalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Professional Identity'),
                        const SizedBox(height: 12),
                        _infoCard(label: 'Full Name', icon: Icons.person_outline,
                            controller: _nameCtrl, editable: _isEditing, value: _name),
                        const SizedBox(height: 12),
                        _infoCard(label: 'Specialization', icon: Icons.medical_services_outlined,
                            controller: null, editable: false, value: _specialization, locked: true),
                        const SizedBox(height: 24),
                        _sectionLabel('Contact & Workplace'),
                        const SizedBox(height: 12),
                        _infoCard(label: 'Phone', icon: Icons.phone_outlined,
                            controller: _phoneCtrl, editable: _isEditing, value: _phone),
                        const SizedBox(height: 12),
                        _infoCard(label: 'Hospital / Clinic', icon: Icons.local_hospital_outlined,
                            controller: _hospitalCtrl, editable: _isEditing, value: _hospital),
                        const SizedBox(height: 12),
                        _infoCard(label: 'Years of Experience', icon: Icons.timeline_outlined,
                            controller: null, editable: false, value: '$_yearsOfExperience years', locked: true),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                            label: const Text('Logout',
                                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.danger, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : () {
          if (_isEditing) _saveChanges();
          else setState(() => _isEditing = true);
        },
        backgroundColor: _isEditing ? AppColors.success : AppColors.primary,
        child: _isSaving
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Wave background — taller so the name sits fully inside it
        ClipPath(
          clipper: HeaderWaveClipper(),
          child: Container(
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isEditing ? _pickPhoto : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    backgroundImage: _newPhoto != null
                        ? FileImage(_newPhoto!) as ImageProvider
                        : (_photoUrl != null && _photoUrl!.isNotEmpty
                            ? NetworkImage(_photoUrl!)
                            : null),
                    child: (_newPhoto == null &&
                            (_photoUrl == null || _photoUrl!.isEmpty))
                        ? Text(
                            _initials,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Name — padded so it never overflows the wave width
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _specialization,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statChip('$_yearsOfExperience', 'Yrs Exp', Icons.timeline_rounded, const Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _statChipWide(_hospital, Icons.local_hospital_rounded, const Color(0xFFFF6F91)),
          ),
          const SizedBox(width: 10),
          _statChip('$_patientCount', 'Patients', Icons.people_rounded, const Color(0xFF26C6DA)),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            Text(label,
                style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _statChipWide(String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          Text('Hospital', style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(context))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)));

  Widget _infoCard({
    required String label,
    required IconData icon,
    required TextEditingController? controller,
    required bool editable,
    required String value,
    bool locked = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: editable ? AppColors.primary.withOpacity(0.6) : AppColors.getBorder(context).withOpacity(0.4),
          width: editable ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.getTextTertiary(context), letterSpacing: 0.8)),
                const SizedBox(height: 4),
                editable && controller != null
                    ? TextField(
                        controller: controller,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context)),
                        decoration: const InputDecoration(
                            isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      )
                    : Text(value,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context))),
              ],
            ),
          ),
          if (locked)
            Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.getTextTertiary(context)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HeaderWaveClipper
// ═══════════════════════════════════════════════════════════════════

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 40);
    path.quadraticBezierTo(size.width * 0.75, size.height - 80, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
