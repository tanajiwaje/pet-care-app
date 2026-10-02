// Implements customer streaming, pagination, and CRUD operations in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_model.dart';
import 'customer_repository.dart';
import 'firestore_code_sequence.dart';
import '../services/audit_log_service.dart';
import 'firestore_page.dart';

/// Implements Firestore data access for customer records.
class FirestoreCustomerRepository implements CustomerRepository {
  final CollectionReference<Map<String, dynamic>> _collectionRef;

  /// Creates the customer repository, optionally using an injected Firestore collection.
  FirestoreCustomerRepository({
    CollectionReference<Map<String, dynamic>>? collectionRef,
  }) : _collectionRef =
           collectionRef ?? FirebaseFirestore.instance.collection('customers');

  /// Subscribes to Firestore changes for customers and maps snapshots to typed records.
  @override
  Stream<List<CustomerModel>> watchCustomers() {
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
            return CustomerModel.fromMap(doc.id, data);
          }).toList();
        });
  }

  /// Loads at most ten customers after [cursor] for scroll-based lists.
  Future<FirestorePage<CustomerModel>> fetchCustomerPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<CustomerModel>(
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
        return CustomerModel.fromMap(doc.id, data);
      },
    ).load(cursor: cursor);
  }

  /// Adds a customer using the supplied identity, contact, and address details.
  @override
  Future<void> addCustomer({
    required String firstName,
    required String lastName,
    required String mobile,
    required String address,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AuditLogService.instance.track(
      entity: 'Customer',
      action: 'create',
      operation: () =>
          FirestoreCodeSequence(collection: _collectionRef, prefix: 'CU').add({
            'firstName': firstName,
            'lastName': lastName,
            'mobile': mobile,
            'address': address,
            'isActive': isActive,
            'createdAt': now,
            'updatedAt': now,
          }),
    );
  }

  /// Updates the selected customer record with the supplied values.
  @override
  Future<void> updateCustomer({
    required String id,
    required String firstName,
    required String lastName,
    required String mobile,
    required String address,
    required bool isActive,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Customer',
      action: 'update',
      recordId: id,
      operation: () => _collectionRef.doc(id).update({
        'firstName': firstName,
        'lastName': lastName,
        'mobile': mobile,
        'address': address,
        'isActive': isActive,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected customer record and records the operation result.
  @override
  Future<void> deleteCustomer(String id) async {
    await AuditLogService.instance.track(
      entity: 'Customer',
      action: 'delete',
      recordId: id,
      operation: () => _collectionRef.doc(id).delete(),
    );
  }
}
