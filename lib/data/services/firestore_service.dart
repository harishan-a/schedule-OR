import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

/// Generic Firestore service for common operations.
class FirestoreService {
  final FirebaseFirestore _firestore;
  final _logger = Logger('FirestoreService');

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get instance => _firestore;

  /// Get a document by collection and ID.
  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Set a document (create or overwrite).
  Future<void> setDocument(
      String collection, String docId, Map<String, dynamic> data,
      {bool merge = false}) async {
    await _firestore
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
    _logger.info('Set document $docId in $collection');
  }

  /// Update fields in a document.
  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await _firestore.collection(collection).doc(docId).update(data);
    _logger.info('Updated document $docId in $collection');
  }

  /// Delete a document.
  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
    _logger.info('Deleted document $docId from $collection');
  }

  /// Add a document (auto-generated ID).
  Future<String> addDocument(
      String collection, Map<String, dynamic> data) async {
    final docRef = await _firestore.collection(collection).add(data);
    _logger.info('Added document ${docRef.id} to $collection');
    return docRef.id;
  }

  /// Stream a collection.
  Stream<QuerySnapshot> collectionStream(String collection,
      {String? orderBy, bool descending = false}) {
    Query query = _firestore.collection(collection);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    return query.snapshots();
  }
}
