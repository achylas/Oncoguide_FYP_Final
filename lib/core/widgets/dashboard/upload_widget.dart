import 'package:flutter/material.dart';

import '../../conts/colors.dart';

class UploadWidget extends StatelessWidget {
  final VoidCallback onUpload;

  const UploadWidget({super.key, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onUpload,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.upload_file, size: 36, color: AppColors.accent),
                SizedBox(height: 8),
                Text("Upload Patient Data",
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
