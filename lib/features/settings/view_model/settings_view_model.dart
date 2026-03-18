import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/data/repositories/settings_repository.dart';
import 'package:logging/logging.dart';

/// ViewModel for the settings screen.
class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final _logger = Logger('SettingsViewModel');

  bool _isDarkMode = false;
  bool _isLargeText = false;
  bool _isHighContrast = false;
  bool _isLoading = false;

  // Notification settings
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;

  SettingsViewModel({SettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? SettingsRepository() {
    _loadSettings();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isLargeText => _isLargeText;
  bool get isHighContrast => _isHighContrast;
  bool get isLoading => _isLoading;
  bool get pushNotifications => _pushNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get smsNotifications => _smsNotifications;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsRepository.init();
      _isDarkMode = _settingsRepository.isDarkMode;
      _isLargeText = _settingsRepository.isLargeText;
      _isHighContrast = _settingsRepository.isHighContrast;

      // Load remote notification settings
      final remote = await _settingsRepository.getRemoteSettings();
      _pushNotifications = remote['pushNotifications'] as bool? ?? true;
      _emailNotifications = remote['emailNotifications'] as bool? ?? false;
      _smsNotifications = remote['smsNotifications'] as bool? ?? false;
    } catch (e) {
      _logger.warning('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await _settingsRepository.setDarkMode(value);
  }

  Future<void> setLargeText(bool value) async {
    _isLargeText = value;
    notifyListeners();
    await _settingsRepository.setLargeText(value);
  }

  Future<void> setHighContrast(bool value) async {
    _isHighContrast = value;
    notifyListeners();
    await _settingsRepository.setHighContrast(value);
  }

  Future<void> setPushNotifications(bool value) async {
    _pushNotifications = value;
    notifyListeners();
    await _settingsRepository.saveRemoteSettings({'pushNotifications': value});
  }

  Future<void> setEmailNotifications(bool value) async {
    _emailNotifications = value;
    notifyListeners();
    await _settingsRepository.saveRemoteSettings({'emailNotifications': value});
  }

  Future<void> setSmsNotifications(bool value) async {
    _smsNotifications = value;
    notifyListeners();
    await _settingsRepository.saveRemoteSettings({'smsNotifications': value});
  }
}
