import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oncoguide_v2/core/conts/colors.dart';
import 'package:oncoguide_v2/services/patient_images_service.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/resuable_top_bar.dart';

/// Shows all previously uploaded images for a patient.
/// Doctor can tap one to select it for the current analysis.
class PatientImagePickerScreen extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String imageType; // 'mammogram' | 'ultrasound'

  const PatientImagePickerScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.imageType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label  = imageType == 'mammogram' ? 'Mammogram' : 'Ultrasound';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : const Color(0xFFF0F2F8),
      appBar: ReusableTopBar(
        title: 'Patient Records',
        subtitle: Text('$label images for $patientName'),
        showBackButton: true,
        showSettingsButton: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: PatientImagesService.patientImagesByType(patientId, imageType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    imageType == 'mammogram'
                        ? Icons.monitor_heart_outlined
                        : Icons.waves_rounded,
                    size: 56,
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $label images found\nfor this patient',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = {'id': docs[i].id, ...docs[i].data()};
              return _ImageTile(
                data: data,
                onSelect: () async {
                  // Download image to temp file and return as File
                  final url = data['imageUrl']?.toString() ?? '';
                  if (url.isEmpty) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final response = await http.get(Uri.parse(url));
                    final dir  = await getTemporaryDirectory();
                    final file = File('${dir.path}/${data['fileName'] ?? 'scan.jpg'}');
                    await file.writeAsBytes(response.bodyBytes);
                    if (context.mounted) {
                      Navigator.pop(context); // close loading
                      Navigator.pop(context, file); // return file
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to load image: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSelect;
  const _ImageTile({required this.data, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final url      = data['imageUrl']?.toString() ?? '';
    final ts       = data['uploadedAt'];
    String dateStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_rounded, size: 40),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_outlined, size: 40),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Select',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
