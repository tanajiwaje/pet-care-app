// Implements pet streaming, pagination, and CRUD operations in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_model.dart';
import '../services/audit_log_service.dart';
import 'pet_repository.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';

/// Implements Firestore data access for pet records.
class FirestorePetRepository implements PetRepository {
  final CollectionReference<Map<String, dynamic>> _collectionRef;

  /// Creates the pet repository, optionally using an injected Firestore collection.
  FirestorePetRepository({
    CollectionReference<Map<String, dynamic>>? collectionRef,
  }) : _collectionRef =
           collectionRef ?? FirebaseFirestore.instance.collection('pets');

  /// Subscribes to Firestore changes for pets and maps snapshots to typed records.
  @override
  Stream<List<PetModel>> watchPets() {
    return _collectionRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapDocument).toList();
        });
  }

  /// Streams records related to the requested customer, excluding unrelated customers.
  @override
  Stream<List<PetModel>> watchPetsForCustomer(String customerId) {
    return _collectionRef
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
          final pets = snapshot.docs.map(_mapDocument).toList();
          pets.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
          return pets;
        });
  }

  /// Loads at most ten pets after [cursor] for scroll-based lists.
  Future<FirestorePage<PetModel>> fetchPetPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<PetModel>(
      query: _collectionRef.orderBy('createdAt', descending: true),
      map: _mapDocument,
    ).load(cursor: cursor);
  }

  /// Adds a pet linked to its owner, pet type, and breed.
  @override
  Future<void> addPet({
    required String customerId,
    required String petTypeId,
    required String breedId,
    required bool gender,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await AuditLogService.instance.track(
      entity: 'Pet',
      action: 'create',
      operation: () =>
          FirestoreCodeSequence(collection: _collectionRef, prefix: 'PET').add({
            'customerId': customerId,
            'petTypeId': petTypeId,
            'breedId': breedId,
            'gender': gender,
            'isActive': isActive,
            'createdAt': now,
            'updatedAt': now,
          }),
    );
  }

  /// Updates the selected pet record with the supplied values.
  @override
  Future<void> updatePet({
    required String id,
    required String customerId,
    required String petTypeId,
    required String breedId,
    required bool gender,
    required bool isActive,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Pet',
      action: 'update',
      recordId: id,
      operation: () => _collectionRef.doc(id).update({
        'customerId': customerId,
        'petTypeId': petTypeId,
        'breedId': breedId,
        'gender': gender,
        'isActive': isActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected pet record and records the operation result.
  @override
  Future<void> deletePet(String id) async {
    await AuditLogService.instance.track(
      entity: 'Pet',
      action: 'delete',
      recordId: id,
      operation: () => _collectionRef.doc(id).delete(),
    );
  }

  /// Converts a Firestore pet document snapshot into a typed model.
  PetModel _mapDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    if (createdAt is Timestamp) {
      data['createdAt'] = createdAt.millisecondsSinceEpoch;
    }
    if (updatedAt is Timestamp) {
      data['updatedAt'] = updatedAt.millisecondsSinceEpoch;
    }
    return PetModel.fromMap(doc.id, data);
  }
}
