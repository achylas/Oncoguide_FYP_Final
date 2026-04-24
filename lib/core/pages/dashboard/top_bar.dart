import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../conts/colors.dart';

class EnhancedTopBar extends StatefulWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;

  const EnhancedTopBar({
    super.key,
    required this.onProfileTap,
    required this.onNotificationTap,
  });

  @override
  State<EnhancedTopBar> createState() => _EnhancedTopBarState();
}

class _EnhancedTopBarState extends State<EnhancedTopBar> {
  String _doctorName = "Doctor";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorName();
  }

  Future<void> _loadDoctorName() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('doctors').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _doctorName = doc.data()!['name'] ?? "Doctor";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error loading doctor name: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
            AppColors.surfaceDark.withOpacity(0.5),
            AppColors.cardBackgroundDark.withOpacity(0.3),
          ]
              : [
            AppColors.primary.withOpacity(0.08),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.getPrimaryGradient(context),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.getCardBackground(context),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark
                          ? AppColors.surfaceDark
                          : AppColors.primaryLight.withOpacity(0.2),
                      child: Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back,",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _isLoading
                        ? SizedBox(
                      height: 18,
                      width: 100,
                      child: LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.getBorder(context),
                      ),
                    )
                        : Text(
                      _doctorName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(color: AppColors.borderDark, width: 1)
                      : null,
                  boxShadow: isDark
                      ? null
                      : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onNotificationTap,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: AppColors.getTextPrimary(context),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
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