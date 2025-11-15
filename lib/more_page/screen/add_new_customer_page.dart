import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/more_page/providers/customer_provider.dart';
import 'package:yenpos/more_page/screen/customer_ledger_screen.dart';

class CustomerManagementPage extends StatelessWidget {
  const CustomerManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final searchController = TextEditingController();

    // Fetch customers after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.customers.isEmpty && !provider.isLoading) {
        provider.fetchCustomers();
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Customer Management",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 8,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo.shade700,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _showCustomerDialog(context, provider);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by Phone',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                suffixIcon: provider.isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              onChanged: (value) => provider.searchCustomer(value),
            ),
            const SizedBox(height: 16),
            // Customer list
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (provider.customers.isEmpty &&
                        searchController.text.isEmpty)
                  ? const Center(child: Text("No customers available"))
                  : ListView.builder(
                      itemCount: searchController.text.isNotEmpty
                          ? provider.searchResults.length
                          : provider.customers.length,
                      itemBuilder: (context, index) {
                        final customer = searchController.text.isNotEmpty
                            ? provider.searchResults[index]
                            : provider.customers[index];

                        return _buildCustomerCard(
                          context,
                          provider,
                          customer,
                          index,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    CustomerProvider provider,
    Map<String, dynamic> customer,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.white]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade200,
          child: Text(
            "${index + 1}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          customer['customerName'] ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          customer['customerPhoneNumber'] ?? 'N/A',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.receipt_long, color: Colors.green),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerLedgerScreen(
                      customerPhoneNumber: customer['customerPhoneNumber'],
                      customerName: customer['customerName'],
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.indigo),
              onPressed: () {
                _showCustomerDialog(context, provider, customer: customer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDialog(
    BuildContext context,
    CustomerProvider provider, {
    Map<String, dynamic>? customer,
  }) {
    final nameController = TextEditingController(
      text: customer?['customerName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: customer?['customerPhoneNumber'] ?? '',
    );
    final isEdit = customer != null;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? "Edit Customer" : "Add Customer",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (isEdit) {
                          provider.updateCustomer(
                            customer!['customerId'],
                            nameController.text,
                            phoneController.text,
                          );
                        } else {
                          provider.addCustomer(
                            nameController.text,
                            phoneController.text,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      child: Text(isEdit ? 'Update' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
