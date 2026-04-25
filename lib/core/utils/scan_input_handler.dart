import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/scan/scan_input_sheet.dart';

class ScanInputHandler {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> handleInput(
    BuildContext context,
    ScanInputType type,
  ) async {
    XFile? file;

    switch (type) {
      case ScanInputType.camera:
        file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          preferredCameraDevice: CameraDevice.rear,
        );
        break;

      case ScanInputType.gallery:
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        break;

      case ScanInputType.report:
        // Placeholder for PDF / file picker
        return null;

      case ScanInputType.fromDatabase:
        // Handled directly in ImagingCard — never reaches here
        return null;
    }

    if (file == null) return null;
    return File(file.path);
  }
}
