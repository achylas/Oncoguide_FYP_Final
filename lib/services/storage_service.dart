import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' hide User, Session, AuthState, AuthChangeEvent;

/// Handles all file uploads to Supabase Storage.
/// Bucket: scan-reports (must be PUBLIC in Supabase dashboard)
class StorageService {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'scan-reports';

  /// Upload a local [File] to Supabase Storage.
  /// Returns the public URL or null on failure.
  static Future<String?> uploadFile({
    required File file,
    required String folder,
    required String fileName,
  }) async {
    try {
      final path  = '$folder/$fileName';
      final bytes = await file.readAsBytes();
      final ext   = file.path.split('.').last.toLowerCase();
      final mime  = ext == 'png' ? 'image/png' : 'image/jpeg';

      print('[StorageService] Uploading file to $path (${bytes.length} bytes, $mime)');

      await _supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      final url = _supabase.storage.from(_bucket).getPublicUrl(path);
      print('[StorageService] ✓ Uploaded file: $url');
      return url;
    } on StorageException catch (e) {
      print('[StorageService] Upload failed: ${e.message} | status: ${e.statusCode} | error: ${e.error}');
      return null;
    } catch (e) {
      print('[StorageService] Upload error: $e');
      return null;
    }
  }

  /// Upload raw bytes (GradCAM PNG, PDF, etc.)
  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    String contentType = 'image/png',
  }) async {
    try {
      final path = '$folder/$fileName';
      print('[StorageService] Uploading bytes to $path (${bytes.length} bytes)');
      await _supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = _supabase.storage.from(_bucket).getPublicUrl(path);
      print('[StorageService] ✓ Uploaded bytes: $url');
      return url;
    } on StorageException catch (e) {
      print('[StorageService] Upload bytes failed: ${e.message} | status: ${e.statusCode} | error: ${e.error}');
      return null;
    } catch (e) {
      print('[StorageService] Upload bytes error: $e');
      return null;
    }
  }
}
