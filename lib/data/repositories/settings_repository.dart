import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

/// Repository for user settings (local SharedPreferences + remote Firestore).
class SettingsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('SettingsRepository');
  SharedPreferences? _prefs;

  SettingsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SharedPreferences? prefs,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _prefs = prefs;

  /// Initialize SharedPreferences.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ---- Local Settings (SharedPreferences) ----

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  // Theme settings
  bool get isDarkMode => getBool('darkMode');
  Future<bool> setDarkMode(bool value) => setBool('darkMode', value);

  bool get isLargeText => getBool('largeText');
  Future<bool> setLargeText(bool value) => setBool('largeText', value);

  bool get isHighContrast => getBool('highContrast');
  Future<bool> setHighContrast(bool value) => setBool('highContrast', value);

  // ---- Remote Settings (Firestore) ----

  /// Get user settings from Firestore.
  Future<Map<String, dynamic>> getRemoteSettings() async {
    final user = _auth.currentUser;
    if (user == null) return {};
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .get();
      return doc.data() ?? {};
    } catch (e) {
      _logger.warning('Error fetching remote settings: $e');
      return {};
    }
  }

  /// Save user settings to Firestore.
  Future<void> saveRemoteSettings(Map<String, dynamic> settings) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .set(settings, SetOptions(merge: true));
    } catch (e) {
      _logger.warning('Error saving remote settings: $e');
      rethrow;
    }
  }
}
