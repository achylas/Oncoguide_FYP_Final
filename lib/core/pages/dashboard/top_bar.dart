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
  String _doctorName = 'Doctor';
  String? _photoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }

      final doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _doctorName = data['name'] ?? 'Doctor';
          _photoUrl   = data['photoUrl'] as String?;
          _isLoading  = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('EnhancedTopBar: $e');
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final parts = _doctorName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : _doctorName;
  }

  String get _initials {
    final parts = _doctorName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _doctorName.isNotEmpty ? _doctorName[0].toUpperCase() : 'D';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              GestureDetector(
                onTap: widget.onProfileTap,
                child: _buildAvatar(),
              ),
              const SizedBox(width: 12),

              // ── Greeting ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isLoading
                        ? SizedBox(
                            height: 14,
                            width: 160,
                            child: LinearProgressIndicator(
                              color: AppColors.primary,
                              backgroundColor: AppColors.getBorder(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Text(
                            '${_greeting()}, Dr. $_firstName',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getTextPrimary(context),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    const SizedBox(height: 2),
                    Text(
                      'OncoGuide AI',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Settings ─────────────────────────────────────────────────
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.getTextPrimary(context),
                  size: 24,
                ),
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(_photoUrl!),
        backgroundColor: AppColors.primary.withOpacity(0.15),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF6F91), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
