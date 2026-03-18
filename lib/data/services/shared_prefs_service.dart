import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper around SharedPreferences for testability and convenience.
class SharedPrefsService {
  SharedPreferences? _prefs;

  /// Initialize the service.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences? get instance => _prefs;

  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs?.getBool(key) ?? defaultValue;

  Future<bool> setBool(String key, bool value) async =>
      await _prefs?.setBool(key, value) ?? false;

  String? getString(String key) => _prefs?.getString(key);

  Future<bool> setString(String key, String value) async =>
      await _prefs?.setString(key, value) ?? false;

  int? getInt(String key) => _prefs?.getInt(key);

  Future<bool> setInt(String key, int value) async =>
      await _prefs?.setInt(key, value) ?? false;

  double? getDouble(String key) => _prefs?.getDouble(key);

  Future<bool> setDouble(String key, double value) async =>
      await _prefs?.setDouble(key, value) ?? false;

  Future<bool> remove(String key) async => await _prefs?.remove(key) ?? false;

  Future<bool> clear() async => await _prefs?.clear() ?? false;
}
