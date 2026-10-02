// Declares the data-access contract for pet records.

import '../models/pet_model.dart';

/// Declares the data-access contract for pet records.
abstract class PetRepository {
  /// Subscribes to Firestore changes for pets and maps snapshots to typed records.
  Stream<List<PetModel>> watchPets();

  /// Streams records related to the requested customer, excluding unrelated customers.
  Stream<List<PetModel>> watchPetsForCustomer(String customerId);

  /// Adds a pet linked to its owner, pet type, and breed.
  Future<void> addPet({
    required String customerId,
    required String petTypeId,
    required String breedId,
    required bool gender,
    required bool isActive,
  });

  /// Updates the selected pet record with the supplied values.
  Future<void> updatePet({
    required String id,
    required String customerId,
    required String petTypeId,
    required String breedId,
    required bool gender,
    required bool isActive,
  });

  /// Deletes the selected pet record and records the operation result.
  Future<void> deletePet(String id);
}
