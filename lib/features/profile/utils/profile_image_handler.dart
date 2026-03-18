import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImageHandler {
  final BuildContext context;

  ProfileImageHandler(this.context);

  /// Pick image from gallery
  Future<File?> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image == null) return null;

      // No cropping, just return the image file
      return File(image.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      return null;
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image == null) return null;

      // No cropping, just return the image file
      return File(image.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      return null;
    }
  }

  /// Camera is available on mobile platforms
  bool isCameraAvailable() {
    return true;
  }
}
