import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import the mobile-specific implementation
import 'package:firebase_orscheduler/features/profile/utils/profile_image_handler.dart'
    if (dart.library.html) 'package:firebase_orscheduler/web_stubs/profile_image_handler.dart';

/// Creates the appropriate image handler based on the platform
ProfileImageHandler getProfileImageHandler(BuildContext context) {
  return ProfileImageHandler(context);
}
