import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImageHandler {
  final BuildContext context;

  ProfileImageHandler(this.context);

  /// Pick image from gallery for web platforms
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

      // On web, simply return the image file
      return File(image.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      return null;
    }
  }

  /// Stub method for camera on web - this is called but will show a message and return null
  Future<File?> pickImageFromCamera() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Camera access is limited on web. Please use gallery instead.')),
    );
    return null;
  }

  /// Disable camera option for web
  bool isCameraAvailable() {
    return false;
  }
}
