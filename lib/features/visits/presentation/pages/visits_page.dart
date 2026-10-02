// Manages visit and payment records, search, balances, and record forms.

import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/customer_search_field.dart';
import '../../../../models/customer_model.dart';
import '../../../../models/breed_model.dart';
import '../../../../models/pet_model.dart';
import '../../../../models/pet_type_model.dart';
import '../../../../models/service_type_model.dart';
import '../../../../models/visit_model.dart';
import '../../../../models/payment_model.dart';
import '../../../../repositories/firestore_customer_repository.dart';
import '../../../../repositories/firestore_breed_repository.dart';
import '../../../../repositories/firestore_pet_repository.dart';
import '../../../../repositories/firestore_service_type_repository.dart';
import '../../../../repositories/firestore_visit_repository.dart';
import '../../../../repositories/pet_type_firestore_repository.dart';

/// Presents visit and payment management workflows.
class VisitsPage extends StatefulWidget {
  /// Creates the screen for managing visits and payments.
  const VisitsPage({super.key});

  /// Creates the state that manages visit and payment records.
  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

/// Loads visit-related data and coordinates search, balances, and CRUD forms.
class _VisitsPageState extends State<VisitsPage> {
  static const _paymentModes = [
    'Cash',
    'Card',
    'UPI',
    'Bank Transfer',
    'Other',
  ];

  final _visitRepository = FirestoreVisitRepository();
  final _customerRepository = FirestoreCustomerRepository();
  final _petRepository = FirestorePetRepository();
  final _petTypeRepository = PetTypeFirestoreRepository();
  final _breedRepository = FirestoreBreedRepository();
  final _serviceTypeRepository = FirestoreServiceTypeRepository();
  final _mobileSearchController = TextEditingController();
  late final Stream<List<CustomerModel>> _customersStream;
  late final Stream<List<PetModel>> _petsStream;
  late final Stream<List<ServiceTypeModel>> _serviceTypesStream;
  late final Stream<List<VisitModel>> _visitsStream;
  late final Stream<List<PaymentModel>> _paymentsStream;
  late final Stream<List<PetTypeModel>> _petTypesStream = _petTypeRepository
      .watchPetTypes();
  late final Stream<List<BreedModel>> _breedsStream = _breedRepository
      .watchBreeds();

  /// Initializes visits and payments state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _customersStream = _customerRepository.watchCustomers();
    _petsStream = _petRepository.watchPets();
    _serviceTypesStream = _serviceTypeRepository.watchServiceTypes();
    _visitsStream = _visitRepository.watchVisits();
    _paymentsStream = _visitRepository.watchPayments();
  }

  /// Releases resources owned by visits and payments, including controllers and subscriptions.
  @override
  void dispose() {
    _mobileSearchController.dispose();
    super.dispose();
  }

  /// Combines a customer first and last name into a display label.
  String _customerName(CustomerModel customer) =>
      '${customer.firstName} ${customer.lastName}'.trim();

  /// Creates consistent input styling for visit and payment forms.
  ThemeData _formTheme(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.32),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.8),
        ),
      ),
    );
  }

  /// Builds the title row and optional status detail for a data-entry form.
  Widget _formHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  /// Groups related form fields beneath a labeled heading.
  Widget _formSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  /// Calculates billed customer totals less recorded payments.
  double _customerBalance(
    String customerId,
    List<VisitModel> visits,
    Map<String, double> paymentsByCustomer,
  ) {
    final billed = visits
        .where((visit) => visit.customerId == customerId)
        .fold<double>(0, (sum, visit) => sum + visit.actualAmount);
    final paid = paymentsByCustomer[customerId] ?? 0;
    return billed - paid;
  }

  /// Aggregates payment amounts by visit for efficient balance calculations.
  Map<String, double> _paymentTotalsByVisit(List<PaymentModel> payments) {
    final totals = <String, double>{};
    for (final payment in payments) {
      totals.update(
        payment.visitId,
        (amount) => amount + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    return totals;
  }

  /// Aggregates payment amounts by customer for efficient balance calculations.
  Map<String, double> _paymentTotalsByCustomer(List<PaymentModel> payments) {
    final totals = <String, double>{};
    for (final payment in payments) {
      totals.update(
        payment.customerId,
        (amount) => amount + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    return totals;
  }

  /// Calculates the unpaid amount for a visit from pre-aggregated payments.
  double _visitPendingAmount(
    VisitModel visit,
    Map<String, double> paymentsByVisit,
  ) {
    final paid = paymentsByVisit[visit.id] ?? 0;
    return (visit.actualAmount - paid).clamp(0, double.infinity).toDouble();
  }

  /// Returns customer visits that still have an outstanding balance.
  List<VisitModel> _pendingVisits(
    String customerId,
    List<VisitModel> visits,
    Map<String, double> paymentsByVisit,
  ) {
    return visits
        .where(
          (visit) =>
              visit.customerId == customerId &&
              _visitPendingAmount(visit, paymentsByVisit) > 0.005,
        )
        .toList();
  }

  /// Formats a balance as either an outstanding amount or customer credit.
  String _balanceLabel(double balance) => balance < 0
      ? 'Credit: ${(-balance).toStringAsFixed(2)}'
      : 'Pending: ${balance.toStringAsFixed(2)}';

  /// Formats a visit or payment date using the active locale.
  String _dateLabel(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  /// Opens a date picker and returns the user-selected date, if any.
  Future<DateTime?> _pickDate(DateTime initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
  }

  /// Opens the visit and initial-payment form and saves both records together.
  Future<void> _showVisitDialog({
    required List<CustomerModel> customers,
    required List<PetModel> pets,
    required List<ServiceTypeModel> serviceTypes,
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
  }) async {
    if (customers.isEmpty || pets.isEmpty || serviceTypes.isEmpty) {
      _showMessage(
        'Add a customer, a pet, and a service type before creating a visit.',
      );
      return;
    }

    var selectedCustomerId = customers.first.id;
    var customerPets = pets
        .where((pet) => pet.customerId == selectedCustomerId)
        .toList();
    if (customerPets.isEmpty) {
      selectedCustomerId = customers
          .firstWhere(
            (customer) => pets.any((pet) => pet.customerId == customer.id),
            orElse: () => customers.first,
          )
          .id;
      customerPets = pets
          .where((pet) => pet.customerId == selectedCustomerId)
          .toList();
    }
    if (customerPets.isEmpty) {
      _showMessage('Add a pet to a customer before creating a visit.');
      return;
    }

    final availableCustomers = customers
        .where((customer) => pets.any((pet) => pet.customerId == customer.id))
        .toList();
    selectedCustomerId = availableCustomers.first.id;
    customerPets = pets
        .where((pet) => pet.customerId == selectedCustomerId)
        .toList();
    var selectedPetId = customerPets.first.id;
    final activeServiceTypes = serviceTypes
        .where((serviceType) => serviceType.isActive)
        .toList();
    if (activeServiceTypes.isEmpty) {
      _showMessage('Add an active service type before creating a visit.');
      return;
    }

    var selectedServiceTypeId = activeServiceTypes.first.id;
    final paymentsByCustomer = _paymentTotalsByCustomer(payments);
    final actualAmountController = TextEditingController(
      text: activeServiceTypes.first.defaultAmount.toString(),
    );
    final paymentAmountController = TextEditingController(
      text: activeServiceTypes.first.defaultAmount.toString(),
    );
    var visitDate = DateTime.now();
    var paymentMode = _paymentModes.first;
    var visitAmountIsSynced = true;
    var paymentAmountIsSynced = true;
    String? savedActualAmount;
    String? savedPaymentAmount;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DialogControllerOwner(
        controllers: [actualAmountController, paymentAmountController],
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selectedService = activeServiceTypes.firstWhere(
              (service) => service.id == selectedServiceTypeId,
            );
            final actualAmount =
                double.tryParse(actualAmountController.text.trim()) ?? 0;
            final initialPayment =
                double.tryParse(paymentAmountController.text.trim()) ?? 0;
            final pendingAmount =
                _customerBalance(
                  selectedCustomerId,
                  visits,
                  paymentsByCustomer,
                ) +
                actualAmount -
                initialPayment;
            return Theme(
              data: _formTheme(dialogContext),
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                title: _formHeader(
                  icon: Icons.event_available,
                  title: 'Add Visit',
                  subtitle: 'Record a service and its initial payment',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _balanceLabel(pendingAmount),
                      style: Theme.of(dialogContext).textTheme.labelMedium
                          ?.copyWith(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _formSection(
                          icon: Icons.assignment_outlined,
                          title: 'Visit details',
                          children: [
                            CustomerSearchField(
                              customers: availableCustomers,
                              selectedCustomerId: selectedCustomerId,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedCustomerId = value;
                                  customerPets = pets
                                      .where((pet) => pet.customerId == value)
                                      .toList();
                                  selectedPetId = customerPets.first.id;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(selectedCustomerId),
                              initialValue: selectedPetId,
                              decoration: const InputDecoration(
                                labelText: 'Pet',
                              ),
                              items: customerPets
                                  .map(
                                    (pet) => DropdownMenuItem(
                                      value: pet.id,
                                      child: Text(
                                        _petDescription(pet, petTypes, breeds),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedPetId = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedServiceTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Service type',
                              ),
                              items: activeServiceTypes
                                  .map(
                                    (service) => DropdownMenuItem(
                                      value: service.id,
                                      child: Text(service.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedServiceTypeId = value;
                                  if (visitAmountIsSynced) {
                                    actualAmountController.text =
                                        activeServiceTypes
                                            .firstWhere(
                                              (service) => service.id == value,
                                            )
                                            .defaultAmount
                                            .toString();
                                  }
                                  if (paymentAmountIsSynced) {
                                    paymentAmountController.text =
                                        actualAmountController.text;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: actualAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Actual amount',
                              ),
                              onChanged: (value) {
                                visitAmountIsSynced =
                                    value ==
                                    selectedService.defaultAmount.toString();
                                if (paymentAmountIsSynced) {
                                  paymentAmountController.text = value;
                                }
                                setDialogState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            _datePickerTile(
                              label: 'Visit date',
                              date: visitDate,
                              onTap: () async {
                                final selected = await _pickDate(visitDate);
                                if (selected != null) {
                                  setDialogState(() => visitDate = selected);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _formSection(
                          icon: Icons.payments_outlined,
                          title: 'Initial payment',
                          children: [
                            TextField(
                              controller: paymentAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Payment amount',
                              ),
                              onChanged: (_) {
                                paymentAmountIsSynced = false;
                                setDialogState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: paymentMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment mode',
                              ),
                              items: _paymentModes
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => paymentMode = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ],
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
                    onPressed: () {
                      savedActualAmount = actualAmountController.text;
                      savedPaymentAmount = paymentAmountController.text;
                      Navigator.pop(dialogContext, true);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save visit and payment'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (saved != true) return;

    final actualAmount = double.tryParse(savedActualAmount?.trim() ?? '');
    final paymentAmount = double.tryParse(savedPaymentAmount?.trim() ?? '');
    if (actualAmount == null ||
        actualAmount < 0 ||
        paymentAmount == null ||
        paymentAmount < 0) {
      _showMessage('Enter valid non-negative visit and payment amounts.');
      return;
    }

    try {
      await _visitRepository.addVisitWithPayment(
        customerId: selectedCustomerId,
        petId: selectedPetId,
        serviceTypeId: selectedServiceTypeId,
        defaultAmount: activeServiceTypes
            .firstWhere((service) => service.id == selectedServiceTypeId)
            .defaultAmount
            .toDouble(),
        actualAmount: actualAmount,
        visitNotes: '',
        visitDate: visitDate,
        paymentAmount: paymentAmount,
        paymentNotes: '',
        paymentDate: visitDate,
        paymentMode: paymentMode,
        referenceNo: '',
      );
    } catch (error) {
      _showMessage('Could not save visit and payment: $error');
    }
  }

  /// Combines pet type and breed names into a readable pet label.
  String _petDescription(
    PetModel pet,
    List<PetTypeModel> petTypes,
    List<BreedModel> breeds,
  ) {
    final petType = petTypes.where((item) => item.id == pet.petTypeId);
    final breed = breeds.where((item) => item.id == pet.breedId);
    final petTypeName = petType.isEmpty ? 'Pet' : petType.first.name;
    final breedName = breed.isEmpty ? 'Breed unavailable' : breed.first.name;
    return '$petTypeName - $breedName';
  }

  /// Opens the payment form for a customer visit with an outstanding balance.
  Future<void> _showPaymentDialog({
    required List<CustomerModel> customers,
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
  }) async {
    final paymentsByVisit = _paymentTotalsByVisit(payments);
    final eligibleCustomers = customers
        .where(
          (customer) =>
              _pendingVisits(customer.id, visits, paymentsByVisit).isNotEmpty,
        )
        .toList();
    if (eligibleCustomers.isEmpty) {
      _showMessage(
        'There are no visits with an outstanding balance for payment.',
      );
      return;
    }
    var selectedCustomerId = eligibleCustomers.first.id;
    var customerVisits = _pendingVisits(
      selectedCustomerId,
      visits,
      paymentsByVisit,
    );
    var selectedVisitId = customerVisits.first.id;
    final amountController = TextEditingController();
    var paymentDate = DateTime.now();
    var paymentMode = _paymentModes.first;
    String? savedAmount;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DialogControllerOwner(
        controllers: [amountController],
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final enteredAmount =
                double.tryParse(amountController.text.trim()) ?? 0;
            final selectedVisit = customerVisits.firstWhere(
              (visit) => visit.id == selectedVisitId,
            );
            final visitPendingAmount = _visitPendingAmount(
              selectedVisit,
              paymentsByVisit,
            );
            final customerPendingAmount = customerVisits.fold<double>(
              0,
              (sum, visit) => sum + _visitPendingAmount(visit, paymentsByVisit),
            );
            return Theme(
              data: _formTheme(dialogContext),
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                title: _formHeader(
                  icon: Icons.payments_outlined,
                  title: 'Add Payment',
                  subtitle: 'Record a payment against a visit',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _balanceLabel(customerPendingAmount),
                      style: Theme.of(dialogContext).textTheme.labelMedium
                          ?.copyWith(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _formSection(
                          icon: Icons.receipt_long_outlined,
                          title: 'Payment details',
                          children: [
                            CustomerSearchField(
                              customers: eligibleCustomers,
                              selectedCustomerId: selectedCustomerId,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedCustomerId = value;
                                  customerVisits = _pendingVisits(
                                    value,
                                    visits,
                                    paymentsByVisit,
                                  );
                                  selectedVisitId = customerVisits.first.id;
                                  amountController.clear();
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(selectedCustomerId),
                              initialValue: selectedVisitId,
                              decoration: const InputDecoration(
                                labelText: 'Visit',
                              ),
                              items: customerVisits
                                  .map(
                                    (visit) => DropdownMenuItem(
                                      value: visit.id,
                                      child: Text(
                                        '${visit.code.isEmpty ? 'Visit' : visit.code} • ${_dateLabel(context, visit.visitDate)} • Pending ${_visitPendingAmount(visit, paymentsByVisit).toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedVisitId = value);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Visit pending: ${visitPendingAmount.toStringAsFixed(2)}',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        dialogContext,
                                      ).colorScheme.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Remaining on this visit: ${_balanceLabel(visitPendingAmount - enteredAmount)}',
                                style: Theme.of(
                                  dialogContext,
                                ).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: paymentMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment mode',
                              ),
                              items: _paymentModes
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => paymentMode = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _datePickerTile(
                              label: 'Payment date',
                              date: paymentDate,
                              onTap: () async {
                                final selected = await _pickDate(paymentDate);
                                if (selected != null) {
                                  setDialogState(() => paymentDate = selected);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
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
                    onPressed: () {
                      savedAmount = amountController.text;
                      Navigator.pop(dialogContext, true);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save payment'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (saved != true) return;

    final amount = double.tryParse(savedAmount?.trim() ?? '');
    if (amount == null || amount <= 0) {
      _showMessage('Enter a payment amount greater than zero.');
      return;
    }
    final selectedVisit = visits.firstWhere(
      (visit) => visit.id == selectedVisitId,
    );
    final pendingAmount = _visitPendingAmount(selectedVisit, paymentsByVisit);
    if (pendingAmount <= 0.005) {
      _showMessage('This visit no longer has an outstanding balance.');
      return;
    }
    if (amount > pendingAmount) {
      _showMessage(
        'Payment cannot exceed this visit’s pending amount of ${pendingAmount.toStringAsFixed(2)}.',
      );
      return;
    }

    try {
      await _visitRepository.addPayment(
        customerId: selectedCustomerId,
        visitId: selectedVisitId,
        amount: amount,
        notes: '',
        paymentDate: paymentDate,
        paymentMode: paymentMode,
        referenceNo: '',
      );
    } catch (error) {
      _showMessage('Could not save payment: $error');
    }
  }

  /// Opens the visit edit form and persists the validated changes.
  Future<void> _showEditVisitDialog({
    required VisitModel visit,
    required List<PetModel> pets,
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
    required List<ServiceTypeModel> serviceTypes,
  }) async {
    final customerPets = pets
        .where((pet) => pet.customerId == visit.customerId)
        .toList();
    final editableServices = serviceTypes
        .where(
          (service) => service.isActive || service.id == visit.serviceTypeId,
        )
        .toList();
    if (customerPets.isEmpty || editableServices.isEmpty) {
      _showMessage('The visit pet or service is unavailable.');
      return;
    }

    var selectedPetId = customerPets.any((pet) => pet.id == visit.petId)
        ? visit.petId
        : customerPets.first.id;
    var selectedServiceTypeId =
        editableServices.any((service) => service.id == visit.serviceTypeId)
        ? visit.serviceTypeId
        : editableServices.first.id;
    var actualAmount = visit.actualAmount.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Theme(
          data: _formTheme(dialogContext),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            title: _formHeader(
              icon: Icons.edit_calendar_outlined,
              title: 'Edit visit',
              subtitle: visit.code.isEmpty
                  ? 'Update visit details'
                  : visit.code,
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: _formSection(
                  icon: Icons.assignment_outlined,
                  title: 'Visit details',
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedPetId,
                      decoration: const InputDecoration(labelText: 'Pet'),
                      items: customerPets
                          .map(
                            (pet) => DropdownMenuItem(
                              value: pet.id,
                              child: Text(
                                _petDescription(pet, petTypes, breeds),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedPetId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedServiceTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Service type',
                      ),
                      items: editableServices
                          .map(
                            (service) => DropdownMenuItem(
                              value: service.id,
                              child: Text(service.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedServiceTypeId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: actualAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Actual amount',
                      ),
                      onChanged: (value) => actualAmount = value,
                    ),
                  ],
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
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;

    final parsedAmount = double.tryParse(actualAmount.trim());
    if (parsedAmount == null || parsedAmount < 0) {
      _showMessage('Enter a valid non-negative amount.');
      return;
    }

    try {
      await _visitRepository.updateVisit(
        id: visit.id,
        petId: selectedPetId,
        serviceTypeId: selectedServiceTypeId,
        defaultAmount: editableServices
            .firstWhere((service) => service.id == selectedServiceTypeId)
            .defaultAmount
            .toDouble(),
        actualAmount: parsedAmount,
      );
    } catch (error) {
      _showMessage('Could not update visit: $error');
    }
  }

  /// Opens the payment edit form and persists the validated changes.
  Future<void> _showEditPaymentDialog(PaymentModel payment) async {
    var amount = payment.amount.toString();
    var paymentMode = _paymentModes.contains(payment.paymentMode)
        ? payment.paymentMode
        : _paymentModes.first;
    var paymentDate = payment.paymentDate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Theme(
          data: _formTheme(dialogContext),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            title: _formHeader(
              icon: Icons.edit_note_outlined,
              title: 'Edit payment',
              subtitle: payment.code.isEmpty
                  ? 'Update payment details'
                  : payment.code,
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: _formSection(
                  icon: Icons.payments_outlined,
                  title: 'Payment details',
                  children: [
                    TextFormField(
                      initialValue: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      onChanged: (value) => amount = value,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: paymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment mode',
                      ),
                      items: _paymentModes
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(mode),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => paymentMode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _datePickerTile(
                      label: 'Payment date',
                      date: paymentDate,
                      onTap: () async {
                        final selected = await _pickDate(paymentDate);
                        if (selected != null) {
                          setDialogState(() => paymentDate = selected);
                        }
                      },
                    ),
                  ],
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
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;

    final parsedAmount = double.tryParse(amount.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      _showMessage('Enter a payment amount greater than zero.');
      return;
    }

    try {
      await _visitRepository.updatePayment(
        id: payment.id,
        amount: parsedAmount,
        paymentMode: paymentMode,
        paymentDate: paymentDate,
      );
    } catch (error) {
      _showMessage('Could not update payment: $error');
    }
  }

  /// Confirms and deletes a payment, showing any repository failure to the user.
  Future<void> _deletePayment(PaymentModel payment) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete payment',
      message:
          'Delete ${payment.code.isEmpty ? 'this payment' : payment.code}? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _visitRepository.deletePayment(payment.id);
    } catch (error) {
      _showMessage('Could not delete payment: $error');
    }
  }

  /// Confirms and deletes a visit and its linked payments.
  Future<void> _deleteVisit(VisitModel visit) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete visit',
      message:
          'Delete this visit and all of its payments? This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _visitRepository.deleteVisit(visit.id);
    } catch (error) {
      _showMessage('Could not delete visit: $error');
    }
  }

  /// Displays a brief user-facing status or validation message.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Presents the available actions for adding a visit or payment.
  Future<void> _showAddActions({
    required List<CustomerModel> customers,
    required List<PetModel> pets,
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
    required List<ServiceTypeModel> services,
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Add Visit'),
              onTap: () => Navigator.pop(sheetContext, 'visit'),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Add Payment'),
              onTap: () => Navigator.pop(sheetContext, 'payment'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'visit') {
      await _showVisitDialog(
        customers: customers,
        pets: pets,
        serviceTypes: services,
        petTypes: petTypes,
        breeds: breeds,
        visits: visits,
        payments: payments,
      );
    } else if (action == 'payment') {
      await _showPaymentDialog(
        customers: customers,
        visits: visits,
        payments: payments,
      );
    }
  }

  /// Builds a compact labeled chip for visit details.
  Widget _visitInfoChip({required IconData icon, required String label}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSecondaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a form row that opens a date picker for the selected date.
  Widget _datePickerTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateLabel(context, date),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the widget tree for visits page state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: StreamBuilder<List<CustomerModel>>(
            stream: _customersStream,
            builder: (context, customerSnapshot) {
              if (customerSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load customers: ${customerSnapshot.error}',
                  ),
                );
              }
              final customers = customerSnapshot.data ?? [];
              return StreamBuilder<List<PetModel>>(
                stream: _petsStream,
                builder: (context, petSnapshot) {
                  if (petSnapshot.hasError) {
                    return Center(
                      child: Text('Could not load pets: ${petSnapshot.error}'),
                    );
                  }
                  final pets = petSnapshot.data ?? [];
                  return StreamBuilder<List<PetTypeModel>>(
                    stream: _petTypesStream,
                    builder: (context, petTypeSnapshot) {
                      if (petTypeSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load pet types: ${petTypeSnapshot.error}',
                          ),
                        );
                      }
                      final petTypes = petTypeSnapshot.data ?? [];
                      return StreamBuilder<List<BreedModel>>(
                        stream: _breedsStream,
                        builder: (context, breedSnapshot) {
                          if (breedSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load breeds: ${breedSnapshot.error}',
                              ),
                            );
                          }
                          final breeds = breedSnapshot.data ?? [];
                          return StreamBuilder<List<ServiceTypeModel>>(
                            stream: _serviceTypesStream,
                            builder: (context, serviceSnapshot) {
                              if (serviceSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Could not load service types: ${serviceSnapshot.error}',
                                  ),
                                );
                              }
                              final services = serviceSnapshot.data ?? [];
                              return StreamBuilder<List<VisitModel>>(
                                stream: _visitsStream,
                                builder: (context, visitSnapshot) {
                                  if (visitSnapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Could not load visits: ${visitSnapshot.error}',
                                      ),
                                    );
                                  }
                                  final visits = visitSnapshot.data ?? [];
                                  return StreamBuilder<List<PaymentModel>>(
                                    stream: _paymentsStream,
                                    builder: (context, paymentSnapshot) {
                                      if (paymentSnapshot.hasError) {
                                        return Center(
                                          child: Text(
                                            'Could not load payments: ${paymentSnapshot.error}',
                                          ),
                                        );
                                      }
                                      final payments =
                                          paymentSnapshot.data ?? [];
                                      final loading =
                                          customerSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          petSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          petTypeSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          breedSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          serviceSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          visitSnapshot.connectionState ==
                                              ConnectionState.waiting ||
                                          paymentSnapshot.connectionState ==
                                              ConnectionState.waiting;
                                      if (loading) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      return _buildContent(
                                        customers: customers,
                                        pets: pets,
                                        petTypes: petTypes,
                                        breeds: breeds,
                                        services: services,
                                        visits: visits,
                                        payments: payments,
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
              );
            },
          ),
        ),
      ),
    );
  }

  /// Displays a billed, paid, or pending visit amount with status styling.
  Widget _visitAmountBadge({
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

  /// Displays one payment detail with a descriptive icon.
  Widget _paymentDetail(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Builds the content UI section using current visits and payments data and state.
  Widget _buildContent({
    required List<CustomerModel> customers,
    required List<PetModel> pets,
    required List<PetTypeModel> petTypes,
    required List<BreedModel> breeds,
    required List<ServiceTypeModel> services,
    required List<VisitModel> visits,
    required List<PaymentModel> payments,
  }) {
    final customerById = {for (final item in customers) item.id: item};
    final petById = {for (final item in pets) item.id: item};
    final serviceById = {for (final item in services) item.id: item};
    final paymentsByVisit = <String, List<PaymentModel>>{};
    final paymentTotalsByVisit = _paymentTotalsByVisit(payments);
    for (final payment in payments) {
      paymentsByVisit.putIfAbsent(payment.visitId, () => []).add(payment);
    }
    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visits and Payments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search customer name or mobile',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Clear search',
                        onPressed: _mobileSearchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _mobileSearchController,
                builder: (context, searchValue, _) {
                  final customerSearch = searchValue.text.trim().toLowerCase();
                  final matchingCustomerIds = customers
                      .where((customer) {
                        final matchesName = _customerName(
                          customer,
                        ).toLowerCase().contains(customerSearch);
                        final matchesMobile = customer.mobile
                            .toLowerCase()
                            .contains(customerSearch);
                        return customerSearch.isEmpty ||
                            matchesName ||
                            matchesMobile;
                      })
                      .map((customer) => customer.id)
                      .toSet();
                  final filteredVisits = visits
                      .where(
                        (visit) =>
                            matchingCustomerIds.contains(visit.customerId),
                      )
                      .toList();
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: filteredVisits.isEmpty
                        ? 1
                        : filteredVisits.length,
                    itemBuilder: (context, index) {
                      if (filteredVisits.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No visits match this search.'),
                        );
                      }
                      final visit = filteredVisits[index];
                      final customer = customerById[visit.customerId];
                      final pet = petById[visit.petId];
                      final service = serviceById[visit.serviceTypeId];
                      final visitPayments = paymentsByVisit[visit.id] ?? [];
                      final petDescription = pet == null
                          ? 'Pet unavailable'
                          : _petDescription(pet, petTypes, breeds);
                      final pendingAmount = _visitPendingAmount(
                        visit,
                        paymentTotalsByVisit,
                      );
                      final colors = Theme.of(context).colorScheme;
                      return Card(
                        color: colors.surface,
                        elevation: 1,
                        shadowColor: colors.shadow.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: colors.primaryContainer.withValues(
                                  alpha: 0.55,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  8,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            visit.code.isEmpty
                                                ? 'Visit'
                                                : visit.code,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color:
                                                      colors.onPrimaryContainer,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            service?.name ?? 'Service',
                                            textAlign: TextAlign.right,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onPrimaryContainer,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              _showEditVisitDialog(
                                                visit: visit,
                                                pets: pets,
                                                petTypes: petTypes,
                                                breeds: breeds,
                                                serviceTypes: services,
                                              );
                                            } else if (action == 'delete') {
                                              _deleteVisit(visit);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit visit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                'Delete visit and payments',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _visitAmountBadge(
                                            label: 'TOTAL',
                                            amount: visit.actualAmount,
                                            color: colors.primary,
                                            background: colors.surface,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _visitAmountBadge(
                                            label: pendingAmount > 0.005
                                                ? 'PENDING'
                                                : 'PAID',
                                            amount: pendingAmount > 0.005
                                                ? pendingAmount
                                                : null,
                                            color: pendingAmount > 0.005
                                                ? const Color(0xFFB76516)
                                                : const Color(0xFF21805F),
                                            background: colors.surface
                                                .withValues(alpha: 0.82),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 19,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            customer == null
                                                ? 'Customer unavailable'
                                                : _customerName(customer),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        if (customer != null)
                                          Text(
                                            customer.mobile,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                    if (customer != null &&
                                        customer.address.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 27,
                                          top: 5,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                customer.address.trim(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _visitInfoChip(
                                          icon: Icons.pets_outlined,
                                          label: petDescription,
                                        ),
                                        _visitInfoChip(
                                          icon: Icons.calendar_today,
                                          label: _dateLabel(
                                            context,
                                            visit.visitDate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (visitPayments.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...visitPayments.map(
                                        (payment) => Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 7,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      payment.code.isEmpty
                                                          ? 'Payment'
                                                          : payment.code,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 3,
                                                      children: [
                                                        _paymentDetail(
                                                          Icons
                                                              .credit_card_outlined,
                                                          payment.paymentMode,
                                                        ),
                                                        _paymentDetail(
                                                          Icons
                                                              .calendar_today_outlined,
                                                          _dateLabel(
                                                            context,
                                                            payment.paymentDate,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                payment.amount.toStringAsFixed(
                                                  2,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                        0xFF21805F,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                onSelected: (action) {
                                                  if (action == 'edit') {
                                                    _showEditPaymentDialog(
                                                      payment,
                                                    );
                                                  } else if (action ==
                                                      'delete') {
                                                    _deletePayment(payment);
                                                  }
                                                },
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit payment'),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(
                                                      'Delete payment',
                                                    ),
                                                  ),
                                                ],
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: FloatingActionButton(
            heroTag: 'visits-add-action',
            tooltip: 'Add visit or payment',
            onPressed: () => _showAddActions(
              customers: customers,
              pets: pets,
              petTypes: petTypes,
              breeds: breeds,
              services: services,
              visits: visits,
              payments: payments,
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/// Owns and disposes text controllers used by a visit/payment dialog.
class _DialogControllerOwner extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget child;

  /// Associates a dialog child with the text controllers that it owns.
  const _DialogControllerOwner({
    required this.controllers,
    required this.child,
  });

  /// Creates the state that disposes controllers when the dialog closes.
  @override
  State<_DialogControllerOwner> createState() => _DialogControllerOwnerState();
}

/// Provides the dialog child and disposes its owned controllers.
class _DialogControllerOwnerState extends State<_DialogControllerOwner> {
  /// Builds the widget tree for dialog controller owner state.
  @override
  Widget build(BuildContext context) => widget.child;

  /// Releases resources owned by visits and payments, including controllers and subscriptions.
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
