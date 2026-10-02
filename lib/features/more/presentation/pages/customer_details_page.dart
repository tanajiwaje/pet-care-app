// Shows a customer profile with related pets, visits, payments, and balances.

import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../models/breed_model.dart';
import '../../../../models/customer_model.dart';
import '../../../../models/pet_model.dart';
import '../../../../models/pet_type_model.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/service_type_model.dart';
import '../../../../models/visit_model.dart';
import '../../../../repositories/firestore_breed_repository.dart';
import '../../../../repositories/firestore_pet_repository.dart';
import '../../../../repositories/firestore_service_type_repository.dart';
import '../../../../repositories/firestore_visit_repository.dart';
import '../../../../repositories/pet_type_firestore_repository.dart';

/// Presents a customer profile with related pets, visits, payments, and balances.
class CustomerDetailsPage extends StatefulWidget {
  final CustomerModel customer;

  /// Creates a detail screen for the selected customer.
  const CustomerDetailsPage({super.key, required this.customer});

  /// Creates the state that loads and presents the selected customer's records.
  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

/// Loads and renders one customer?s related records and actions.
class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final _petRepository = FirestorePetRepository();
  final _petTypeRepository = PetTypeFirestoreRepository();
  final _breedRepository = FirestoreBreedRepository();
  final _visitRepository = FirestoreVisitRepository();
  final _serviceTypeRepository = FirestoreServiceTypeRepository();
  int _selectedTab = 0;

  late final Stream<List<PetModel>> _petsStream;
  late final Stream<List<PetTypeModel>> _petTypesStream;
  late final Stream<List<BreedModel>> _breedsStream;
  late final Stream<List<VisitModel>> _visitsStream;
  late final Stream<List<PaymentModel>> _paymentsStream;
  late final Stream<List<ServiceTypeModel>> _serviceTypesStream;

  /// Initializes customer details state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _petsStream = _petRepository.watchPetsForCustomer(widget.customer.id);
    _petTypesStream = _petTypeRepository.watchPetTypes();
    _breedsStream = _breedRepository.watchBreeds();
    _visitsStream = _visitRepository.watchVisitsForCustomer(widget.customer.id);
    _paymentsStream = _visitRepository.watchPaymentsForCustomer(
      widget.customer.id,
    );
    _serviceTypesStream = _serviceTypeRepository.watchServiceTypes();
  }

  /// Opens the pet create/edit form and saves the validated pet details.
  Future<void> _showPetDialog({
    PetModel? record,
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
  }) async {
    final petTypesWithBreeds = petTypes
        .where((type) => breeds.any((breed) => breed.petTypeId == type.id))
        .toList();
    if (petTypesWithBreeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a pet type and at least one breed before adding a pet.',
          ),
        ),
      );
      return;
    }

    var selectedPetTypeId =
        petTypesWithBreeds.any((type) => type.id == record?.petTypeId)
        ? record!.petTypeId
        : petTypesWithBreeds.first.id;
    var availableBreeds = breeds
        .where((breed) => breed.petTypeId == selectedPetTypeId)
        .toList();
    var selectedBreedId =
        availableBreeds.any((breed) => breed.id == record?.breedId)
        ? record!.breedId
        : availableBreeds.first.id;
    var gender = record?.gender ?? false;
    var isActive = record?.isActive ?? true;
    final colors = Theme.of(context).colorScheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Theme(
          data: Theme.of(dialogContext).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.8),
              ),
            ),
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            title: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    record == null ? Icons.pets_outlined : Icons.edit_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record == null ? 'Add Pet' : 'Edit Pet',
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose the pet type, breed and profile status.',
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedPetTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Pet Type',
                        ),
                        items: petTypesWithBreeds
                            .map(
                              (type) => DropdownMenuItem(
                                value: type.id,
                                child: Text(type.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedPetTypeId = value;
                            availableBreeds = breeds
                                .where((breed) => breed.petTypeId == value)
                                .toList();
                            selectedBreedId = availableBreeds.first.id;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedPetTypeId),
                        initialValue: selectedBreedId,
                        decoration: const InputDecoration(labelText: 'Breed'),
                        items: availableBreeds
                            .map(
                              (breed) => DropdownMenuItem(
                                value: breed.id,
                                child: Text(breed.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(
                          () => selectedBreedId = value ?? selectedBreedId,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        title: const Text('Female'),
                        value: gender,
                        onChanged: (value) =>
                            setDialogState(() => gender = value),
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        title: const Text('Active'),
                        subtitle: Text(
                          isActive
                              ? 'Available for visits'
                              : 'Hidden from active selections',
                        ),
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(dialogContext, false),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check),
                label: const Text('Save pet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;

    try {
      if (record == null) {
        await _petRepository.addPet(
          customerId: widget.customer.id,
          petTypeId: selectedPetTypeId,
          breedId: selectedBreedId,
          gender: gender,
          isActive: isActive,
        );
      } else {
        await _petRepository.updatePet(
          id: record.id,
          customerId: widget.customer.id,
          petTypeId: selectedPetTypeId,
          breedId: selectedBreedId,
          gender: gender,
          isActive: isActive,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save pet: $error')));
    }
  }

  /// Confirms pet deletion and reports repository errors.
  Future<void> _deletePet(PetModel pet) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete pet?',
      message:
          'Delete this ${pet.code.isEmpty ? 'pet' : pet.code}? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _petRepository.deletePet(pet.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete pet: $error')));
    }
  }

  /// Builds the widget tree for customer details page state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: StreamBuilder<List<PetTypeModel>>(
          stream: _petTypesStream,
          builder: (context, petTypeSnapshot) {
            if (petTypeSnapshot.hasError) {
              return _loadError(
                'Could not load pet types: ${petTypeSnapshot.error}',
              );
            }
            final petTypes = petTypeSnapshot.data ?? [];
            return StreamBuilder<List<BreedModel>>(
              stream: _breedsStream,
              builder: (context, breedSnapshot) {
                if (breedSnapshot.hasError) {
                  return _loadError(
                    'Could not load breeds: ${breedSnapshot.error}',
                  );
                }
                final breeds = breedSnapshot.data ?? [];
                return StreamBuilder<List<PetModel>>(
                  stream: _petsStream,
                  builder: (context, petSnapshot) {
                    if (petSnapshot.hasError) {
                      return _loadError(
                        'Could not load pets: ${petSnapshot.error}',
                      );
                    }
                    final pets = petSnapshot.data ?? [];
                    return StreamBuilder<List<VisitModel>>(
                      stream: _visitsStream,
                      builder: (context, visitSnapshot) {
                        if (visitSnapshot.hasError) {
                          return _loadError(
                            'Could not load visits: ${visitSnapshot.error}',
                          );
                        }
                        return StreamBuilder<List<PaymentModel>>(
                          stream: _paymentsStream,
                          builder: (context, paymentSnapshot) {
                            if (paymentSnapshot.hasError) {
                              return _loadError(
                                'Could not load payments: ${paymentSnapshot.error}',
                              );
                            }
                            return StreamBuilder<List<ServiceTypeModel>>(
                              stream: _serviceTypesStream,
                              builder: (context, serviceSnapshot) {
                                if (serviceSnapshot.hasError) {
                                  return _loadError(
                                    'Could not load service types: ${serviceSnapshot.error}',
                                  );
                                }
                                final waiting =
                                    petTypeSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    breedSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    petSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    visitSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    paymentSnapshot.connectionState ==
                                        ConnectionState.waiting ||
                                    serviceSnapshot.connectionState ==
                                        ConnectionState.waiting;
                                if (waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                return _buildCustomerDetails(
                                  petTypes: petTypes,
                                  breeds: breeds,
                                  pets: pets,
                                  visits: visitSnapshot.data ?? [],
                                  payments: paymentSnapshot.data ?? [],
                                  services: serviceSnapshot.data ?? [],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Builds an error state for a failed customer-related query.
  Widget _loadError(String message) => Center(child: Text(message));

  /// Builds the customer profile and related-record sections.
  Widget _buildCustomerDetails({
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
    required List<PetModel> pets,
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
    required List<ServiceTypeModel> services,
  }) {
    final availablePetTypes = petTypes
        .where((type) => breeds.any((breed) => breed.petTypeId == type.id))
        .toList();
    final billedAmount = visits.fold<double>(
      0,
      (sum, visit) => sum + visit.actualAmount,
    );
    final paidAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final pendingAmount = billedAmount - paidAmount;
    final paymentsByVisit = <String, List<PaymentModel>>{};
    for (final payment in payments) {
      paymentsByVisit.putIfAbsent(payment.visitId, () => []).add(payment);
    }
    final summaryCards = _summaryCards(
      visitCount: visits.length,
      paymentCount: payments.length,
      paidAmount: paidAmount,
      pendingAmount: pendingAmount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _customerHeader(),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.event_note_outlined),
              label: Text('Visits (${visits.length})'),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.pets_outlined),
              label: Text('Pets (${pets.length})'),
            ),
          ],
          selected: {_selectedTab},
          onSelectionChanged: (selection) {
            setState(() => _selectedTab = selection.first);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              IndexedStack(
                index: _selectedTab,
                children: [
                  _buildVisitsList(
                    visits,
                    pets,
                    petTypes,
                    breeds,
                    services,
                    paymentsByVisit,
                    summaryCards,
                  ),
                  _buildPetsList(pets, petTypes, breeds),
                ],
              ),
              if (_selectedTab == 1)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: FloatingActionButton.extended(
                    heroTag: 'customer-details-add-pet',
                    onPressed: availablePetTypes.isEmpty
                        ? null
                        : () => _showPetDialog(
                            petTypes: petTypes,
                            breeds: breeds,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add pet'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds customer totals and balance summary cards.
  Widget _summaryCards({
    required int visitCount,
    required int paymentCount,
    required double paidAmount,
    required double pendingAmount,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        _summaryTile(
          icon: Icons.event_note_outlined,
          label: 'Total visits',
          value: '$visitCount',
          color: const Color(0xFF3477A5),
        ),
        _summaryTile(
          icon: Icons.payments_outlined,
          label: 'Payments',
          value: '$paymentCount',
          color: const Color(0xFF6657B8),
        ),
        _summaryTile(
          icon: Icons.check_circle_outline,
          label: 'Amount paid',
          value: paidAmount.toStringAsFixed(2),
          color: const Color(0xFF27856B),
        ),
        _summaryTile(
          icon: Icons.account_balance_wallet_outlined,
          label: pendingAmount < 0 ? 'Credit balance' : 'Pending amount',
          value: pendingAmount.abs().toStringAsFixed(2),
          color: pendingAmount < 0
              ? const Color(0xFF27856B)
              : const Color(0xFFC2762B),
        ),
      ],
    );
  }

  /// Builds the customer identity and contact header.
  Widget _customerHeader() {
    final colors = Theme.of(context).colorScheme;
    final customerName =
        '${widget.customer.firstName} ${widget.customer.lastName}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.person_outline, color: colors.onPrimary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.customer.code.isNotEmpty)
                      Text(
                        widget.customer.code,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onPrimary.withValues(alpha: .8),
                            ),
                      ),
                    Text(
                      customerName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _statusChip(widget.customer.isActive),
            ],
          ),
          const SizedBox(height: 14),
          _contactRow(Icons.phone_outlined, widget.customer.mobile),
          if (widget.customer.address.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _contactRow(Icons.location_on_outlined, widget.customer.address),
          ],
        ],
      ),
    );
  }

  /// Displays one customer contact value beside its icon.
  Widget _contactRow(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colors.onPrimary.withValues(alpha: 0.88)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    );
  }

  /// Displays one labeled customer summary metric.
  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the customer?s pet list and its record actions.
  Widget _buildPetsList(
    List<PetModel> pets,
    List<PetTypeModel> petTypes,
    List<BreedModel> breeds,
  ) {
    final petTypeNames = {for (final type in petTypes) type.id: type.name};
    final breedNames = {for (final breed in breeds) breed.id: breed.name};
    return CustomScrollView(
      slivers: [
        if (pets.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No pets for this customer yet.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 84),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final pet = pets[index];
                final colors = Theme.of(context).colorScheme;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == pets.length - 1 ? 0 : 10,
                  ),
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6657B8,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.pets_outlined,
                              color: Color(0xFF6657B8),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${petTypeNames[pet.petTypeId] ?? 'Unknown type'} · ${breedNames[pet.breedId] ?? 'Unknown breed'}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pet.code.isEmpty ? '' : '${pet.code} · '}'
                                  '${pet.gender ? 'Female' : 'Male'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 7),
                                _statusChip(pet.isActive),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Pet actions',
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showPetDialog(
                                  record: pet,
                                  petTypes: petTypes,
                                  breeds: breeds,
                                );
                              } else {
                                _deletePet(pet);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit pet'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete pet'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: pets.length),
            ),
          ),
      ],
    );
  }

  /// Builds the customer?s visit and payment history.
  Widget _buildVisitsList(
    List<VisitModel> visits,
    List<PetModel> pets,
    List<PetTypeModel> petTypes,
    List<BreedModel> breeds,
    List<ServiceTypeModel> services,
    Map<String, List<PaymentModel>> paymentsByVisit,
    Widget summaryCards,
  ) {
    final petById = {for (final pet in pets) pet.id: pet};
    final typeById = {for (final type in petTypes) type.id: type};
    final breedById = {for (final breed in breeds) breed.id: breed};
    final serviceById = {for (final service in services) service.id: service};
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: summaryCards,
          ),
        ),
        if (visits.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No visits for this customer yet.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final visit = visits[index];
                final serviceName =
                    serviceById[visit.serviceTypeId]?.name ?? 'Service';
                final pet = petById[visit.petId];
                final petDescription = pet == null
                    ? 'Pet unavailable'
                    : '${typeById[pet.petTypeId]?.name ?? 'Pet'} · ${breedById[pet.breedId]?.name ?? 'Breed'}';
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visits.length - 1 ? 0 : 10,
                  ),
                  child: _visitCard(
                    visit: visit,
                    serviceName: serviceName,
                    petDescription: petDescription,
                    payments: paymentsByVisit[visit.id] ?? const [],
                  ),
                );
              }, childCount: visits.length),
            ),
          ),
      ],
    );
  }

  /// Builds a visit history card with billing and payment status.
  Widget _visitCard({
    required VisitModel visit,
    required String serviceName,
    required String petDescription,
    required List<PaymentModel> payments,
  }) {
    final colors = Theme.of(context).colorScheme;
    final paidAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final pendingAmount = (visit.actualAmount - paidAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final isPaid = pendingAmount <= 0.005;
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: colors.primaryContainer.withValues(alpha: 0.55),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visit.code.isEmpty ? 'Visit' : visit.code,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        serviceName,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _customerVisitAmountBadge(
                        label: 'TOTAL',
                        amount: visit.actualAmount,
                        color: colors.primary,
                        background: colors.surface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _customerVisitAmountBadge(
                        label: isPaid ? 'PAID' : 'PENDING',
                        amount: isPaid ? null : pendingAmount,
                        color: isPaid
                            ? const Color(0xFF21805F)
                            : const Color(0xFFB76516),
                        background: colors.surface.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pets_outlined, size: 19, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        petDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(visit.visitDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (payments.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PAYMENT HISTORY',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...payments.map(
                    (payment) => Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.code.isEmpty
                                      ? 'Payment'
                                      : payment.code,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 3,
                                  children: [
                                    _customerPaymentDetail(
                                      Icons.credit_card_outlined,
                                      payment.paymentMode,
                                    ),
                                    _customerPaymentDetail(
                                      Icons.calendar_today_outlined,
                                      MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(payment.paymentDate),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            payment.amount.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFF21805F),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Displays a customer visit amount with its semantic status color.
  Widget _customerVisitAmountBadge({
    required String label,
    required double? amount,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                amount.toStringAsFixed(2),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Displays one customer payment detail with an icon.
  Widget _customerPaymentDetail(IconData icon, String value) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.primary),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Displays whether a record is active or inactive.
  Widget _statusChip(bool isActive) {
    final colors = Theme.of(context).colorScheme;
    final color = isActive ? const Color(0xFF27856B) : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? colors.onPrimary.withValues(alpha: 0.18)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? colors.onPrimary : color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
