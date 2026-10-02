// Implements pet-type streaming, pagination, and CRUD operations in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_type_model.dart';
import '../services/audit_log_service.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';
import 'pet_type_repository.dart';

/// Implements Firestore data access for pet type records.
class PetTypeFirestoreRepository implements PetTypeRepository {
  final CollectionReference<Map<String, dynamic>> _collectionRef;

  /// Creates the pet-type repository, optionally using an injected Firestore collection.
  PetTypeFirestoreRepository({
    CollectionReference<Map<String, dynamic>>? collectionRef,
  }) : _collectionRef =
           collectionRef ?? FirebaseFirestore.instance.collection('petTypes');

  /// Subscribes to Firestore changes for pet types and maps snapshots to typed records.
  @override
  Stream<List<PetTypeModel>> watchPetTypes() {
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
            return PetTypeModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  /// Loads at most ten pet types after [cursor] for scroll-based lists.
  Future<FirestorePage<PetTypeModel>> fetchPetTypePage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<PetTypeModel>(
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
        return PetTypeModel.fromMap(doc.id, data);
      },
    ).load(cursor: cursor);
  }

  /// Adds a pet type with the requested active status.
  @override
  Future<void> addPetType({
    required String name,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AuditLogService.instance.track(
      entity: 'Pet type',
      action: 'create',
      operation: () =>
          FirestoreCodeSequence(collection: _collectionRef, prefix: 'PT').add({
            'name': name,
            'isActive': isActive,
            'createdAt': now,
            'updatedAt': now,
          }),
    );
  }

  /// Updates the selected pet type record with the supplied values.
  @override
  Future<void> updatePetType({
    required String id,
    required String name,
    required bool isActive,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Pet type',
      action: 'update',
      recordId: id,
      operation: () => _collectionRef.doc(id).update({
        'name': name,
        'isActive': isActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected pet type record and records the operation result.
  @override
  Future<void> deletePetType(String id) async {
    await AuditLogService.instance.track(
      entity: 'Pet type',
      action: 'delete',
      recordId: id,
      operation: () => _collectionRef.doc(id).delete(),
    );
  }
}
