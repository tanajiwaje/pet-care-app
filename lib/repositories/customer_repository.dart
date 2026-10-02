// Declares the data-access contract for customer records.

import '../models/customer_model.dart';

/// Declares the data-access contract for customer records.
abstract class CustomerRepository {
  /// Subscribes to Firestore changes for customers and maps snapshots to typed records.
  Stream<List<CustomerModel>> watchCustomers();

  /// Adds a customer using the supplied identity, contact, and address details.
  Future<void> addCustomer({
    required String firstName,
    required String lastName,
    required String mobile,
    required String address,
    required bool isActive,
  });

  /// Updates the selected customer record with the supplied values.
  Future<void> updateCustomer({
    required String id,
    required String firstName,
    required String lastName,
    required String mobile,
    required String address,
    required bool isActive,
  });

  /// Deletes the selected customer record and records the operation result.
  Future<void> deleteCustomer(String id);
}
