// Provides a searchable customer selector for record-entry forms.

import 'package:flutter/material.dart';

import '../../models/customer_model.dart';

/// Shows the selected customer and opens a name/mobile searchable picker.
class CustomerSearchField extends StatelessWidget {
  /// Customers that may be selected by the current form.
  final List<CustomerModel> customers;

  /// ID of the currently selected customer.
  final String selectedCustomerId;

  /// Called when the user selects a customer from the search results.
  final ValueChanged<String> onChanged;

  /// Label displayed above the selected customer.
  final String label;

  /// Creates a customer selector backed by the supplied filtered customer list.
  const CustomerSearchField({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.onChanged,
    this.label = 'Customer',
  });

  String _customerName(CustomerModel customer) =>
      '${customer.firstName} ${customer.lastName}'.trim();

  /// Opens the picker and returns the chosen customer's ID.
  Future<void> _selectCustomer(BuildContext context) async {
    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var searchText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final search = searchText.trim().toLowerCase();
            final filteredCustomers = customers
                .where((customer) {
                  return search.isEmpty ||
                      _customerName(customer).toLowerCase().contains(search) ||
                      customer.mobile.toLowerCase().contains(search);
                })
                .toList(growable: false);

            return AlertDialog(
              title: Text('Select $label'),
              content: SizedBox(
                width: 420,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Search name or mobile',
                        hintText: 'Enter a customer name or mobile number',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchText.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () =>
                                    setDialogState(() => searchText = ''),
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => searchText = value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? const Center(
                              child: Text('No customers match this search.'),
                            )
                          : ListView.separated(
                              itemCount: filteredCustomers.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = filteredCustomers[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_customerName(customer)),
                                  subtitle: customer.mobile.isEmpty
                                      ? null
                                      : Text(customer.mobile),
                                  trailing: customer.id == selectedCustomerId
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, customer.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selectedId != null) onChanged(selectedId);
  }

  /// Builds the selected-customer field that opens the searchable picker.
  @override
  Widget build(BuildContext context) {
    final selectedCustomers = customers.where(
      (customer) => customer.id == selectedCustomerId,
    );
    final selectedCustomer = selectedCustomers.isEmpty
        ? null
        : selectedCustomers.first;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: customers.isEmpty ? null : () => _selectCustomer(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person_outline),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          selectedCustomer == null
              ? 'Select a customer'
              : '${_customerName(selectedCustomer)}'
                    '${selectedCustomer.mobile.isEmpty ? '' : ' · ${selectedCustomer.mobile}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
