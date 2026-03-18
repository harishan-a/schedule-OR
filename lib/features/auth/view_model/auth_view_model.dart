import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_orscheduler/data/services/firebase_auth_service.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:logging/logging.dart';

/// ViewModel for the authentication screen.
/// Manages login/signup state and delegates to services.
class AuthViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService;
  final UserRepository _userRepository;
  final _logger = Logger('AuthViewModel');

  bool _isLoading = false;
  String? _error;

  AuthViewModel({
    FirebaseAuthService? authService,
    UserRepository? userRepository,
  })  : _authService = authService ?? FirebaseAuthService(),
        _userRepository = userRepository ?? UserRepository();

  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get currentUser => _authService.currentUser;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// Sign in with email and password.
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(email, password);
      _logger.info('User signed in: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Authentication failed';
      _logger.warning('Sign in failed: ${e.code}');
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _logger.warning('Sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new account.
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String role,
    required String department,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential =
          await _authService.createUserWithEmailAndPassword(email, password);
      final user = credential.user;
      if (user == null) throw Exception('User creation failed');

      // Update display name
      await _authService.updateDisplayName('$firstName $lastName');

      // Create user profile in Firestore
      await _userRepository.createUserProfile(user.uid, {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber ?? '',
        'role': role,
        'department': department,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _logger.info('User created: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Registration failed';
      _logger.warning('Sign up failed: ${e.code}');
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _logger.warning('Sign up error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _logger.info('User signed out');
    } catch (e) {
      _logger.warning('Sign out error: $e');
    }
  }

  /// Send password reset email.
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _logger.info('Password reset sent to: $email');
      return true;
    } catch (e) {
      _error = 'Failed to send password reset email';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
