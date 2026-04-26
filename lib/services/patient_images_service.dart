import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oncoguide_v2/services/storage_service.dart';

/// Manages per-patient image records.
/// Firestore collection: patient_images
/// Supabase bucket: scan-reports/patient_images/<patientId>/
class PatientImagesService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  // ── Save image ─────────────────────────────────────────────────────────────

  /// Upload [imageFile] to Supabase and save metadata to Firestore.
  /// Returns the public URL.
  static Future<String?> savePatientImage({
    required String patientId,
    required String patientName,
    required File imageFile,
    required String imageType, // 'mammogram' | 'ultrasound'
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName  = '${imageType}_$timestamp.jpg';

      // Upload to Supabase
      final url = await StorageService.uploadFile(
        file: imageFile,
        folder: 'patient_images/$patientId',
        fileName: fileName,
      );

      if (url == null) return null;

      // Save metadata to Firestore
      await _db.collection('patient_images').add({
        'patientId'  : patientId,
        'patientName': patientName,
        'doctorId'   : _uid,
        'imageType'  : imageType,
        'imageUrl'   : url,
        'fileName'   : fileName,
        'uploadedAt' : FieldValue.serverTimestamp(),
      });

      return url;
    } catch (e) {
      print('[PatientImagesService] Save failed: $e');
      return null;
    }
  }

  // ── Fetch images ───────────────────────────────────────────────────────────

  /// Stream all images for a patient, newest first.
  static Stream<QuerySnapshot<Map<String, dynamic>>> patientImagesStream(
      String patientId) {
    return _db
        .collection('patient_images')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  /// Get all images of a specific type for a patient.
  /// Filters client-side to avoid requiring a composite Firestore index.
  static Stream<List<Map<String, dynamic>>> patientImagesByType(
      String patientId, String imageType) {
    return _db
        .collection('patient_images')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((d) => d['imageType'] == imageType)
            .toList());
  }

  /// Delete a patient image record from Firestore.
  static Future<void> deleteImage(String docId) async {
    await _db.collection('patient_images').doc(docId).delete();
  }
}
