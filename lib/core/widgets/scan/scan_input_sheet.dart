import 'package:flutter/material.dart';
import '../../conts/colors.dart';

enum ScanInputType {
  camera,
  gallery,
  report,
}

class ScanInputSheet extends StatelessWidget {
  final String title;
  final Function(ScanInputType) onSelected;

  const ScanInputSheet({
    super.key,
    required this.title,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 20),

          _OptionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Capture Image',
            subtitle: 'Use device camera',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context, ScanInputType.camera);
            },
          ),

          _OptionTile(
            icon: Icons.photo_library_outlined,
            title: 'Select from Device',
            subtitle: 'Gallery or file system',
            color: const Color(0xFF4D9DE0),
            onTap: () {
              Navigator.pop(context, ScanInputType.gallery);
            },
          ),

          _OptionTile(
            icon: Icons.upload_file_outlined,
            title: 'Upload Previous Report',
            subtitle: 'PDF or scanned image',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context, ScanInputType.report);
            },
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/* =========================
   OPTION TILE
========================= */

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
