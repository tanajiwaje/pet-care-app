// Declares the data-access contract for service-type records.

import '../models/service_type_model.dart';

/// Declares the data-access contract for service type records.
abstract class ServiceTypeRepository {
  /// Subscribes to Firestore changes for service types and maps snapshots to typed records.
  Stream<List<ServiceTypeModel>> watchServiceTypes();

  /// Adds a service type with its default amount and active status.
  Future<void> addServiceType({
    required String name,
    required num defaultAmount,
    required bool isActive,
  });

  /// Updates the selected service type record with the supplied values.
  Future<void> updateServiceType({
    required String id,
    required String name,
    required num defaultAmount,
    required bool isActive,
  });

  /// Deletes the selected service type record and records the operation result.
  Future<void> deleteServiceType(String id);
}
