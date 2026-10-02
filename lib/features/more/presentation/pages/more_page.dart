// Presents navigation to master data, application information, and activity tools.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'app_about_page.dart';
import 'app_logs_page.dart';
import '../../../../models/breed_model.dart';
import '../../../../models/customer_model.dart';
import '../../../../models/pet_type_model.dart';
import '../../../../models/service_type_model.dart';
import '../../../../repositories/firestore_breed_repository.dart';
import '../../../../repositories/firestore_customer_repository.dart';
import '../../../../repositories/firestore_page_controller.dart';
import '../../../../repositories/pet_type_firestore_repository.dart';
import '../../../../repositories/firestore_service_type_repository.dart';
import 'customer_details_page.dart';

/// Presents navigation to master data and application utilities.
class MorePage extends StatelessWidget {
  /// Creates the More screen that links to master data and app utilities.
  const MorePage({super.key});

  static const _items = [
    _MasterDataItem(
      'Customers',
      'Manage customer contact details.',
      Icons.people_outline,
      MasterDataKind.customers,
      Color(0xFF167D82),
    ),
    _MasterDataItem(
      'Pet Types',
      'Manage the types of pets your business supports.',
      Icons.category_outlined,
      MasterDataKind.petTypes,
      Color(0xFF6657B8),
    ),
    _MasterDataItem(
      'Breeds',
      'Organize breeds and link them to pet types.',
      Icons.pets_outlined,
      MasterDataKind.breeds,
      Color(0xFFC2762B),
    ),
    _MasterDataItem(
      'Service Types',
      'Set up services and their default pricing.',
      Icons.medical_services_outlined,
      MasterDataKind.serviceTypes,
      Color(0xFF3477A5),
    ),
  ];

  /// Builds the widget tree for more page.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Data')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _items.length + 5,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _MasterDataWelcomeCard();
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                'MANAGE YOUR DATA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (index == _items.length + 2) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Text(
                'APP & ACTIVITY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (index == _items.length + 3) {
            return _MoreActionCard(
              title: 'Activity Log',
              description:
                  'Review changes and application errors saved on this device.',
              icon: Icons.receipt_long_outlined,
              accentColor: const Color(0xFF3477A5),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppLogsPage()),
              ),
            );
          }
          if (index == _items.length + 4) {
            return _MoreActionCard(
              title: 'About PetCare',
              description: 'App information, version and open-source licenses.',
              icon: Icons.info_outline_rounded,
              accentColor: const Color(0xFF6657B8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppAboutPage()),
              ),
            );
          }
          final item = _items[index - 2];
          return _MasterDataCard(
            item: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MasterDataListPage(kind: item.kind),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Builds a reusable navigation card in the More screen.
class _MoreActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  /// Creates a navigation card with its label, description, icon, and action.
  const _MoreActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  /// Builds the widget tree for more action card.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: accentColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description),
        ),
        trailing: Icon(Icons.arrow_forward_rounded, color: accentColor),
      ),
    );
  }
}

/// Builds the introductory banner for the master-data screen.
class _MasterDataWelcomeCard extends StatelessWidget {
  /// Creates the introductory banner displayed above master-data options.
  const _MasterDataWelcomeCard();

  /// Builds the widget tree for master data welcome card.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your pet-care essentials',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep customers, pets, breeds and services organized in one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.tune_rounded, color: colors.onPrimary, size: 29),
          ),
        ],
      ),
    );
  }
}

/// Identifies the master-data category shown by the list screen.
enum MasterDataKind { customers, petTypes, breeds, serviceTypes }

/// Carries display metadata for one master-data navigation item.
class _MasterDataItem {
  final String title;
  final String description;
  final IconData icon;
  final MasterDataKind kind;
  final Color accentColor;

  /// Stores the display metadata and destination kind for a master-data option.
  const _MasterDataItem(
    this.title,
    this.description,
    this.icon,
    this.kind,
    this.accentColor,
  );
}

/// Builds a navigation card for an individual master-data category.
class _MasterDataCard extends StatelessWidget {
  final _MasterDataItem item;
  final VoidCallback onTap;

  /// Creates a selectable card for opening one master-data category.
  const _MasterDataCard({required this.item, required this.onTap});

  /// Builds the widget tree for master data card.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: item.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents searchable, paginated master-data records and CRUD forms.
class MasterDataListPage extends StatefulWidget {
  final MasterDataKind kind;

  /// Creates a paginated CRUD screen for the requested master-data category.
  const MasterDataListPage({super.key, required this.kind});

  /// Creates the state that manages the selected master-data list.
  @override
  State<MasterDataListPage> createState() => _MasterDataListPageState();
}

/// Manages master-data filtering, pagination, forms, and record mutations.
class _MasterDataListPageState extends State<MasterDataListPage> {
  final _searchController = TextEditingController();
  final _recordScrollController = ScrollController();
  final _customerRepository = FirestoreCustomerRepository();
  final _petTypeRepository = PetTypeFirestoreRepository();
  final _breedRepository = FirestoreBreedRepository();
  final _serviceTypeRepository = FirestoreServiceTypeRepository();
  late final FirestorePageController<CustomerModel> _customers;
  late final FirestorePageController<PetTypeModel> _petTypes;
  late final FirestorePageController<BreedModel> _breeds;
  late final FirestorePageController<ServiceTypeModel> _serviceTypes;
  String _search = '';
  String? _breedPetTypeFilter;

  /// Initializes master-data and More screens state and starts required subscriptions or listeners.
  @override
  void initState() {
    super.initState();
    _customers = FirestorePageController(
      fetchPage: _customerRepository.fetchCustomerPage,
    );
    _petTypes = FirestorePageController(
      fetchPage: _petTypeRepository.fetchPetTypePage,
    );
    _breeds = FirestorePageController(
      fetchPage: _breedRepository.fetchBreedPage,
    );
    _serviceTypes = FirestorePageController(
      fetchPage: _serviceTypeRepository.fetchServiceTypePage,
    );
    _recordScrollController.addListener(_loadNextPageNearEnd);
    unawaited(_activePageController.refresh());
  }

  /// Returns the pagination controller for the currently selected data type.
  FirestorePageControllerState get _activePageController {
    switch (widget.kind) {
      case MasterDataKind.customers:
        return _customers;
      case MasterDataKind.petTypes:
        return _petTypes;
      case MasterDataKind.breeds:
        return _breeds;
      case MasterDataKind.serviceTypes:
        return _serviceTypes;
    }
  }

  /// Loads next page near end data and updates the associated screen state.
  void _loadNextPageNearEnd() {
    if (!_recordScrollController.hasClients) return;
    if (_recordScrollController.position.extentAfter < 320 &&
        _activePageController.hasMore &&
        !_activePageController.isLoading) {
      unawaited(_activePageController.loadMore());
    }
  }

  /// Returns the app-bar title for the selected master-data category.
  String get _title {
    switch (widget.kind) {
      case MasterDataKind.customers:
        return 'Customers';
      case MasterDataKind.petTypes:
        return 'Pet Types';
      case MasterDataKind.breeds:
        return 'Breeds';
      case MasterDataKind.serviceTypes:
        return 'Service Types';
    }
  }

  /// Releases resources owned by master-data and More screens, including controllers and subscriptions.
  @override
  void dispose() {
    _searchController.dispose();
    _recordScrollController
      ..removeListener(_loadNextPageNearEnd)
      ..dispose();
    _customers.dispose();
    _petTypes.dispose();
    _breeds.dispose();
    _serviceTypes.dispose();
    super.dispose();
  }

  /// Tests whether a record value satisfies the current search filter.
  bool _matches(String value) =>
      value.toLowerCase().contains(_search.toLowerCase().trim());

  /// Combines the record code and title for display in a list.
  String _codedTitle(String code, String title) =>
      code.isEmpty ? title : '$code • $title';

  /// Opens the customer create/edit form and saves the validated customer record.
  Future<void> _showCustomerDialog({CustomerModel? record}) async {
    final firstNameController = TextEditingController(
      text: record?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: record?.lastName ?? '',
    );
    final mobileController = TextEditingController(text: record?.mobile ?? '');
    final addressController = TextEditingController(
      text: record?.address ?? '',
    );
    var isActive = record?.isActive ?? true;
    final saved = await _showForm(
      title: record == null ? 'Add Customer' : 'Edit Customer',
      fields: [
        TextField(
          controller: firstNameController,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: lastNameController,
          decoration: const InputDecoration(labelText: 'Last name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: mobileController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: addressController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Address'),
        ),
      ],
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
    );
    if (saved != true) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final mobile = mobileController.text.trim();
    final address = addressController.text.trim();
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        mobile.isEmpty ||
        address.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'First name, last name, mobile, and address are required.',
          ),
        ),
      );
      return;
    }

    try {
      if (record == null) {
        await _customerRepository.addCustomer(
          firstName: firstName,
          lastName: lastName,
          mobile: mobile,
          address: address,
          isActive: isActive,
        );
      } else {
        await _customerRepository.updateCustomer(
          id: record.id,
          firstName: firstName,
          lastName: lastName,
          mobile: mobile,
          address: address,
          isActive: isActive,
        );
      }
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save customer: $error')),
      );
    }
  }

  /// Confirms customer deletion and reports repository errors.
  Future<void> _deleteCustomer(CustomerModel customer) async {
    final name = '${customer.firstName} ${customer.lastName}'.trim();
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete customer?',
      message: 'Delete $name? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _customerRepository.deleteCustomer(customer.id);
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete customer: $error')),
      );
    }
  }

  /// Opens the pet-type create/edit form and saves the validated record.
  Future<void> _showPetTypeDialog({PetTypeModel? record}) async {
    final nameController = TextEditingController(text: record?.name ?? '');
    var isActive = record?.isActive ?? true;
    final saved = await _showForm(
      title: record == null ? 'Add Pet Type' : 'Edit Pet Type',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ],
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    try {
      if (record == null) {
        await _petTypeRepository.addPetType(
          name: nameController.text.trim(),
          isActive: isActive,
        );
      } else {
        await _petTypeRepository.updatePetType(
          id: record.id,
          name: nameController.text.trim(),
          isActive: isActive,
        );
      }
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save pet type: $error')),
      );
    }
  }

  /// Confirms pet-type deletion and reports repository errors.
  Future<void> _deletePetType(PetTypeModel petType) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete pet type?',
      message: 'Delete "${petType.name}"? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _petTypeRepository.deletePetType(petType.id);
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete pet type: $error')),
      );
    }
  }

  /// Opens the breed create/edit form and saves the validated record.
  Future<void> _showBreedDialog({
    BreedModel? record,
    List<PetTypeModel> petTypes = const [],
  }) async {
    final nameController = TextEditingController(text: record?.name ?? '');
    var selectedPetTypeId = record?.petTypeId.isNotEmpty == true
        ? record!.petTypeId
        : (petTypes.isNotEmpty ? petTypes.first.id : null);
    var isActive = record?.isActive ?? true;
    final saved = await _showForm(
      title: record == null ? 'Add Breed' : 'Edit Breed',
      fields: [
        DropdownButtonFormField<String>(
          initialValue: selectedPetTypeId,
          decoration: const InputDecoration(labelText: 'Pet Type'),
          items: petTypes
              .map(
                (type) =>
                    DropdownMenuItem(value: type.id, child: Text(type.name)),
              )
              .toList(),
          onChanged: (value) => selectedPetTypeId = value,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Breed Name'),
        ),
      ],
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
    );
    if (saved != true ||
        nameController.text.trim().isEmpty ||
        selectedPetTypeId == null) {
      return;
    }
    try {
      if (record == null) {
        await _breedRepository.addBreed(
          name: nameController.text.trim(),
          isActive: isActive,
          petTypeId: selectedPetTypeId!,
        );
      } else {
        await _breedRepository.updateBreed(
          id: record.id,
          name: nameController.text.trim(),
          isActive: isActive,
          petTypeId: selectedPetTypeId!,
        );
      }
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save breed: $error')));
    }
  }

  /// Confirms breed deletion and reports repository errors.
  Future<void> _deleteBreed(BreedModel breed) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete breed?',
      message: 'Delete "${breed.name}"? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _breedRepository.deleteBreed(breed.id);
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete breed: $error')));
    }
  }

  /// Opens the service-type create/edit form and saves the validated record.
  Future<void> _showServiceTypeDialog({ServiceTypeModel? record}) async {
    final nameController = TextEditingController(text: record?.name ?? '');
    final amountController = TextEditingController(
      text: record?.defaultAmount.toString() ?? '',
    );
    var isActive = record?.isActive ?? true;
    final saved = await _showForm(
      title: record == null ? 'Add Service Type' : 'Edit Service Type',
      fields: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Service Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Default Amount'),
        ),
      ],
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
    );
    final amount = num.tryParse(amountController.text.trim());
    if (saved != true || nameController.text.trim().isEmpty || amount == null) {
      return;
    }
    try {
      if (record == null) {
        await _serviceTypeRepository.addServiceType(
          name: nameController.text.trim(),
          defaultAmount: amount,
          isActive: isActive,
        );
      } else {
        await _serviceTypeRepository.updateServiceType(
          id: record.id,
          name: nameController.text.trim(),
          defaultAmount: amount,
          isActive: isActive,
        );
      }
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save service type: $error')),
      );
    }
  }

  /// Confirms service-type deletion and reports repository errors.
  Future<void> _deleteServiceType(ServiceTypeModel serviceType) async {
    final confirmed = await confirmDeleteRecord(
      context,
      title: 'Delete service type?',
      message: 'Delete "${serviceType.name}"? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await _serviceTypeRepository.deleteServiceType(serviceType.id);
      await _activePageController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete service type: $error')),
      );
    }
  }

  /// Displays a configurable record form and returns its validated field values.
  Future<bool?> _showForm({
    required String title,
    required List<Widget> fields,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
  }) {
    var currentIsActive = isActive;
    final colors = Theme.of(context).colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: fieldBorder,
              enabledBorder: fieldBorder,
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
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    title.contains('Service Type')
                        ? Icons.medical_services_outlined
                        : title.contains('Customer')
                        ? Icons.person_outline
                        : title.contains('Pet Type')
                        ? Icons.category_outlined
                        : title.contains('Breed')
                        ? Icons.pets_outlined
                        : Icons.tune_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title.startsWith('Add')
                            ? 'Enter the details below to get started.'
                            : 'Update the details and save your changes.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Column(
                        children: [
                          ...fields,
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            tileColor: currentIsActive
                                ? colors.secondaryContainer.withValues(
                                    alpha: 0.55,
                                  )
                                : colors.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: const Text(
                              'Active',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              currentIsActive
                                  ? 'Available for use'
                                  : 'Hidden from active selections',
                            ),
                            value: currentIsActive,
                            onChanged: (value) {
                              currentIsActive = value;
                              onActiveChanged(value);
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays whether a record is active or inactive.
  Widget _statusChip(bool isActive) {
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Builds a master-data record card with its actions and status.
  Widget _recordCard({
    required String title,
    String? subtitle,
    bool isThreeLine = false,
    VoidCallback? onTap,
    required bool isActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final colors = Theme.of(context).colorScheme;
    final (icon, accent) = switch (widget.kind) {
      MasterDataKind.customers => (
        Icons.person_outline,
        const Color(0xFF167D82),
      ),
      MasterDataKind.petTypes => (
        Icons.category_outlined,
        const Color(0xFF6657B8),
      ),
      MasterDataKind.breeds => (Icons.pets_outlined, const Color(0xFFC2762B)),
      MasterDataKind.serviceTypes => (
        Icons.medical_services_outlined,
        const Color(0xFF3477A5),
      ),
    };
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: isThreeLine ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _statusChip(isActive),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Record actions',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the pet types UI section using current master-data and More screens data and state.
  Widget _buildPetTypes() {
    return _recordList(
      buildRecords: () => _petTypes.items
          .where((item) => _matches(item.code) || _matches(item.name))
          .map(
            (item) => _recordCard(
              title: _codedTitle(item.code, item.name),
              isActive: item.isActive,
              onEdit: () => _showPetTypeDialog(record: item),
              onDelete: () => _deletePetType(item),
            ),
          )
          .toList(),
      onAdd: () => _showPetTypeDialog(),
    );
  }

  /// Builds the customers UI section using current master-data and More screens data and state.
  Widget _buildCustomers() {
    return _recordList(
      buildRecords: () => _customers.items
          .where(
            (item) =>
                _matches(item.code) ||
                _matches(item.firstName) ||
                _matches(item.lastName) ||
                _matches(item.mobile) ||
                _matches(item.address),
          )
          .map(
            (item) => _recordCard(
              title: _codedTitle(
                item.code,
                '${item.firstName} ${item.lastName}'.trim(),
              ),
              subtitle: 'Mobile: ${item.mobile}\nAddress: ${item.address}',
              isThreeLine: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailsPage(customer: item),
                ),
              ),
              isActive: item.isActive,
              onEdit: () => _showCustomerDialog(record: item),
              onDelete: () => _deleteCustomer(item),
            ),
          )
          .toList(),
      onAdd: () => _showCustomerDialog(),
    );
  }

  /// Builds the breeds UI section using current master-data and More screens data and state.
  Widget _buildBreeds() {
    return StreamBuilder<List<PetTypeModel>>(
      stream: _petTypeRepository.watchPetTypes(),
      builder: (context, typeSnapshot) {
        if (typeSnapshot.hasError) {
          return Center(
            child: Text('Could not load pet types: ${typeSnapshot.error}'),
          );
        }
        final petTypes = typeSnapshot.data ?? [];
        final names = {for (final type in petTypes) type.id: type.name};
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _breedPetTypeFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Pet Type',
                prefixIcon: Icon(Icons.filter_list),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Pet Types'),
                ),
                ...petTypes.map(
                  (type) =>
                      DropdownMenuItem(value: type.id, child: Text(type.name)),
                ),
              ],
              onChanged: (value) => setState(() => _breedPetTypeFilter = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _recordList(
                buildRecords: () => _breeds.items
                    .where(
                      (item) =>
                          (_breedPetTypeFilter == null ||
                              item.petTypeId == _breedPetTypeFilter) &&
                          (_matches(item.code) ||
                              _matches(item.name) ||
                              _matches(names[item.petTypeId] ?? '')),
                    )
                    .map(
                      (item) => _recordCard(
                        title: _codedTitle(item.code, item.name),
                        subtitle: names[item.petTypeId] ?? 'Pet type not found',
                        isActive: item.isActive,
                        onEdit: () =>
                            _showBreedDialog(record: item, petTypes: petTypes),
                        onDelete: () => _deleteBreed(item),
                      ),
                    )
                    .toList(),
                onAdd: petTypes.isEmpty
                    ? null
                    : () => _showBreedDialog(petTypes: petTypes),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the service types UI section using current master-data and More screens data and state.
  Widget _buildServiceTypes() {
    return _recordList(
      buildRecords: () => _serviceTypes.items
          .where((item) => _matches(item.code) || _matches(item.name))
          .map(_serviceTypeCard)
          .toList(),
      onAdd: () => _showServiceTypeDialog(),
    );
  }

  /// Builds a service card with its default amount, active state, and actions.
  Widget _serviceTypeCard(ServiceTypeModel item) {
    final colors = Theme.of(context).colorScheme;
    const accent = Color(0xFF3477A5);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showServiceTypeDialog(record: item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.code.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.code,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _statusChip(item.isActive),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DEFAULT PRICE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.defaultAmount.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Service actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    _showServiceTypeDialog(record: item);
                  } else {
                    _deleteServiceType(item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a searchable, paginated list of master-data records.
  Widget _recordList({
    required List<Widget> Function() buildRecords,
    required VoidCallback? onAdd,
  }) {
    final pageController = _activePageController;
    return Stack(
      children: [
        Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search ${_title.toLowerCase()}',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: pageController,
                builder: (context, _) {
                  final records = buildRecords();
                  if (pageController.itemCount == 0 &&
                      pageController.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (pageController.itemCount == 0 &&
                      pageController.error != null) {
                    return _pageError(pageController);
                  }
                  return RefreshIndicator(
                    onRefresh: pageController.refresh,
                    child: ListView.separated(
                      controller: _recordScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 84),
                      itemCount: records.isEmpty
                          ? 1 +
                                (pageController.hasMore ||
                                        pageController.isLoading ||
                                        pageController.error != null
                                    ? 1
                                    : 0)
                          : records.length +
                                (pageController.hasMore ||
                                        pageController.isLoading ||
                                        pageController.error != null
                                    ? 1
                                    : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (records.isEmpty && index == 0) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                pageController.hasMore
                                    ? 'No matches on this page. Load more to continue searching.'
                                    : 'No records found',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        if (index < records.length) return records[index];
                        return _pageFooter(pageController);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (onAdd != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: FloatingActionButton.extended(
              heroTag: 'master-data-add-record',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('Add $_singularTitle'),
            ),
          ),
      ],
    );
  }

  /// Builds the pagination error message and retry action.
  Widget _pageError(FirestorePageControllerState controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load records.'),
          const SizedBox(height: 8),
          Text(
            controller.error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(controller.loadMore()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Builds the loading or end-of-list footer for a paginated list.
  Widget _pageFooter(FirestorePageControllerState controller) {
    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: () => unawaited(controller.loadMore()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Could not load more. Retry'),
        ),
      );
    }
    return Center(
      child: TextButton.icon(
        onPressed: () => unawaited(controller.loadMore()),
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Load more'),
      ),
    );
  }

  /// Returns the singular record name used in category-specific messages.
  String get _singularTitle => switch (widget.kind) {
    MasterDataKind.customers => 'customer',
    MasterDataKind.petTypes => 'pet type',
    MasterDataKind.breeds => 'breed',
    MasterDataKind.serviceTypes => 'service',
  };

  /// Builds the widget tree for master data list page state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: _buildContent(),
      ),
    );
  }

  /// Builds the content UI section using current master-data and More screens data and state.
  Widget _buildContent() {
    switch (widget.kind) {
      case MasterDataKind.customers:
        return _buildCustomers();
      case MasterDataKind.petTypes:
        return _buildPetTypes();
      case MasterDataKind.breeds:
        return _buildBreeds();
      case MasterDataKind.serviceTypes:
        return _buildServiceTypes();
    }
  }
}
