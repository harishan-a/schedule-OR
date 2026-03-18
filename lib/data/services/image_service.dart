import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'dart:typed_data';

/// Unified image service handling pick, crop, and upload across platforms.
class ImageService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final _logger = Logger('ImageService');

  ImageService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  /// Pick an image from gallery.
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      return await _picker.pickImage(
          source: source, maxWidth: 512, maxHeight: 512);
    } catch (e) {
      _logger.warning('Error picking image: $e');
      return null;
    }
  }

  /// Upload image bytes to Firebase Storage.
  /// Returns the download URL.
  Future<String?> uploadImage({
    required Uint8List imageBytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      await ref.putData(imageBytes, metadata);
      final url = await ref.getDownloadURL();
      _logger.info('Uploaded image to: $path');
      return url;
    } catch (e) {
      _logger.warning('Error uploading image: $e');
      return null;
    }
  }

  /// Upload a profile image for a user.
  /// Returns the download URL.
  Future<String?> uploadProfileImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    return uploadImage(
      imageBytes: imageBytes,
      path: 'profile_images/$userId.jpg',
    );
  }

  /// Delete an image from Firebase Storage.
  Future<void> deleteImage(String path) async {
    try {
      await _storage.ref().child(path).delete();
      _logger.info('Deleted image at: $path');
    } catch (e) {
      _logger.warning('Error deleting image: $e');
    }
  }
}
