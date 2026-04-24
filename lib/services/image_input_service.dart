import 'dart:io';

import 'package:image_picker/image_picker.dart';

class ImageInputService {
  static final ImagePicker _picker = ImagePicker();

  /// Capture image using camera
  static Future<File?> captureFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (image == null) return null;
    return File(image.path);
  }

  /// Select image from gallery
  static Future<File?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return null;
    return File(image.path);
  }
}
