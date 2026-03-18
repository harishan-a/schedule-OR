import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

/// Thin wrapper around FirebaseAuth for testability.
class FirebaseAuthService {
  final FirebaseAuth _auth;
  final _logger = Logger('FirebaseAuthService');

  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    _logger.info('Signing in: $email');
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    _logger.info('Creating account: $email');
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async {
    _logger.info('Signing out');
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _logger.info('Sending password reset to: $email');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    _logger.info('Updated display name: $name');
  }

  Future<void> updatePhotoURL(String url) async {
    await _auth.currentUser?.updatePhotoURL(url);
    _logger.info('Updated photo URL');
  }
}
