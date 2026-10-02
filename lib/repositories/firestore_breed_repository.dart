// Implements breed streaming, pagination, and CRUD operations in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/breed_model.dart';
import '../services/audit_log_service.dart';
import 'breed_repository.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';

/// Implements Firestore data access for breed records.
class FirestoreBreedRepository implements BreedRepository {
  final CollectionReference<Map<String, dynamic>> _collectionRef;

  /// Creates the breed repository, optionally using an injected Firestore collection.
  FirestoreBreedRepository({
    CollectionReference<Map<String, dynamic>>? collectionRef,
  }) : _collectionRef =
           collectionRef ?? FirebaseFirestore.instance.collection('breeds');

  /// Subscribes to Firestore changes for breeds and maps snapshots to typed records.
  @override
  Stream<List<BreedModel>> watchBreeds() {
    return _collectionRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            final createdAt = data['createdAt'];
            final updatedAt = data['updatedAt'];
            if (createdAt is Timestamp) {
              data['createdAt'] = createdAt.millisecondsSinceEpoch;
            }
            if (updatedAt is Timestamp) {
              data['updatedAt'] = updatedAt.millisecondsSinceEpoch;
            }
            return BreedModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  /// Loads at most ten breeds after [cursor] for scroll-based lists.
  Future<FirestorePage<BreedModel>> fetchBreedPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<BreedModel>(
      query: _collectionRef.orderBy('createdAt', descending: true),
      map: (doc) {
        final data = Map<String, dynamic>.from(doc.data());
        final createdAt = data['createdAt'];
        final updatedAt = data['updatedAt'];
        if (createdAt is Timestamp) {
          data['createdAt'] = createdAt.millisecondsSinceEpoch;
        }
        if (updatedAt is Timestamp) {
          data['updatedAt'] = updatedAt.millisecondsSinceEpoch;
        }
        return BreedModel.fromMap(doc.id, data);
      },
    ).load(cursor: cursor);
  }

  /// Adds a breed linked to a pet type, with the requested active status.
  @override
  Future<void> addBreed({
    required String name,
    required bool isActive,
    required String petTypeId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AuditLogService.instance.track(
      entity: 'Breed',
      action: 'create',
      operation: () =>
          FirestoreCodeSequence(collection: _collectionRef, prefix: 'BR').add({
            'petTypeId': petTypeId,
            'name': name,
            'isActive': isActive,
            'createdAt': now,
            'updatedAt': now,
          }),
    );
  }

  /// Updates the selected breed record with the supplied values.
  @override
  Future<void> updateBreed({
    required String id,
    required String name,
    required bool isActive,
    required String petTypeId,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Breed',
      action: 'update',
      recordId: id,
      operation: () => _collectionRef.doc(id).update({
        'petTypeId': petTypeId,
        'name': name,
        'isActive': isActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected breed record and records the operation result.
  @override
  Future<void> deleteBreed(String id) async {
    await AuditLogService.instance.track(
      entity: 'Breed',
      action: 'delete',
      recordId: id,
      operation: () => _collectionRef.doc(id).delete(),
    );
  }
}
