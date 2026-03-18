import 'dart:io';
import 'package:flutter/material.dart';

/// Stub implementation of ImageCropper for web
class ImageCropper {
  /// On web, return null for cropImage to use our alternative approach
  Future<dynamic> cropImage({
    required String sourcePath,
    List<dynamic>? aspectRatioPresets,
    dynamic cropStyle,
    List<dynamic>? uiSettings,
  }) async {
    // Return null to trigger our web-specific behavior
    return null;
  }
}

/// Stub enum for crop aspect ratio presets
enum CropAspectRatioPreset {
  original,
  square,
  ratio3x2,
  ratio5x3,
  ratio4x3,
  ratio5x4,
  ratio7x5,
  ratio16x9,
}

/// Stub enum for crop style
enum CropStyle {
  rectangle,
  circle,
}

/// Stub class for web UI settings
class WebUiSettings {
  final BuildContext context;
  final dynamic presentStyle;
  final dynamic boundary;
  final dynamic viewPort;
  final bool enableExif;
  final bool enableZoom;
  final bool enableResize;

  WebUiSettings({
    required this.context,
    this.presentStyle,
    required this.boundary,
    required this.viewPort,
    this.enableExif = false,
    this.enableZoom = true,
    this.enableResize = false,
  });
}

/// Stub class for cropper present style
enum CropperPresentStyle {
  dialog,
  page,
  popup,
}

/// Stub class for croppie boundary
class CroppieBoundary {
  final int width;
  final int height;

  const CroppieBoundary({
    required this.width,
    required this.height,
  });
}

/// Stub class for croppie viewport
class CroppieViewPort {
  final int width;
  final int height;
  final String type;

  const CroppieViewPort({
    required this.width,
    required this.height,
    this.type = 'square',
  });
}

/// Additional stub classes for mobile platforms
class AndroidUiSettings {
  final String? toolbarTitle;
  final Color? toolbarColor;
  final Color? toolbarWidgetColor;
  final CropAspectRatioPreset? initAspectRatio;
  final bool? lockAspectRatio;
  final bool? hideBottomControls;

  AndroidUiSettings({
    this.toolbarTitle,
    this.toolbarColor,
    this.toolbarWidgetColor,
    this.initAspectRatio,
    this.lockAspectRatio,
    this.hideBottomControls,
  });
}

class IOSUiSettings {
  final String? title;
  final bool? aspectRatioLockEnabled;
  final bool? resetAspectRatioEnabled;
  final bool? aspectRatioPickerButtonHidden;

  IOSUiSettings({
    this.title,
    this.aspectRatioLockEnabled,
    this.resetAspectRatioEnabled,
    this.aspectRatioPickerButtonHidden,
  });
}

// This is a stub implementation of image_cropper for web
// It's deliberately empty to avoid importing the real package
// The actual web implementation is in profile_image_handler.dart
