// Declares the data-access contract for pet-type records.

import '../models/pet_type_model.dart';

/// Declares the data-access contract for pet type records.
abstract class PetTypeRepository {
  /// Subscribes to Firestore changes for pet types and maps snapshots to typed records.
  Stream<List<PetTypeModel>> watchPetTypes();

  /// Adds a pet type with the requested active status.
  Future<void> addPetType({required String name, required bool isActive});

  /// Updates the selected pet type record with the supplied values.
  Future<void> updatePetType({
    required String id,
    required String name,
    required bool isActive,
  });

  /// Deletes the selected pet type record and records the operation result.
  Future<void> deletePetType(String id);
}
