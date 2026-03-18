import 'package:flutter/foundation.dart' show kIsWeb;

/// Feature flags to enable/disable features based on platform or configuration
class FeatureFlags {
  /// Whether image cropping is enabled
  ///
  /// Disabled on web to avoid issues with UnmodifiableUint8ListView in the CroppedFile class
  static bool get isImageCroppingEnabled => !kIsWeb;

  /// Whether camera functionality is available
  ///
  /// Camera functionality is limited on web platforms
  static bool get isCameraAvailable => !kIsWeb;
}
