// Declares the data-access contract for breed records.

import '../models/breed_model.dart';

/// Declares the data-access contract for breed records.
abstract class BreedRepository {
  /// Subscribes to Firestore changes for breeds and maps snapshots to typed records.
  Stream<List<BreedModel>> watchBreeds();

  /// Adds a breed linked to a pet type, with the requested active status.
  Future<void> addBreed({
    required String name,
    required bool isActive,
    required String petTypeId,
  });

  /// Updates the selected breed record with the supplied values.
  Future<void> updateBreed({
    required String id,
    required String name,
    required bool isActive,
    required String petTypeId,
  });

  /// Deletes the selected breed record and records the operation result.
  Future<void> deleteBreed(String id);
}
