// Implements service-type streaming, pagination, and CRUD operations in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_type_model.dart';
import '../services/audit_log_service.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';
import 'service_type_repository.dart';

/// Implements Firestore data access for service type records.
class FirestoreServiceTypeRepository implements ServiceTypeRepository {
  final CollectionReference<Map<String, dynamic>> _collectionRef;

  /// Creates the service-type repository, optionally using an injected Firestore collection.
  FirestoreServiceTypeRepository({
    CollectionReference<Map<String, dynamic>>? collectionRef,
  }) : _collectionRef =
           collectionRef ??
           FirebaseFirestore.instance.collection('serviceTypes');

  /// Subscribes to Firestore changes for service types and maps snapshots to typed records.
  @override
  Stream<List<ServiceTypeModel>> watchServiceTypes() {
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
            return ServiceTypeModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  /// Loads at most ten service types after [cursor] for scroll-based lists.
  Future<FirestorePage<ServiceTypeModel>> fetchServiceTypePage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<ServiceTypeModel>(
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
        return ServiceTypeModel.fromMap(doc.id, data);
      },
    ).load(cursor: cursor);
  }

  /// Adds a service type with its default amount and active status.
  @override
  Future<void> addServiceType({
    required String name,
    required num defaultAmount,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AuditLogService.instance.track(
      entity: 'Service type',
      action: 'create',
      operation: () =>
          FirestoreCodeSequence(collection: _collectionRef, prefix: 'ST').add({
            'name': name,
            'defaultAmount': defaultAmount,
            'isActive': isActive,
            'createdAt': now,
            'updatedAt': now,
          }),
    );
  }

  /// Updates the selected service type record with the supplied values.
  @override
  Future<void> updateServiceType({
    required String id,
    required String name,
    required num defaultAmount,
    required bool isActive,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Service type',
      action: 'update',
      recordId: id,
      operation: () => _collectionRef.doc(id).update({
        'name': name,
        'defaultAmount': defaultAmount,
        'isActive': isActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected service type record and records the operation result.
  @override
  Future<void> deleteServiceType(String id) async {
    await AuditLogService.instance.track(
      entity: 'Service type',
      action: 'delete',
      recordId: id,
      operation: () => _collectionRef.doc(id).delete(),
    );
  }
}
