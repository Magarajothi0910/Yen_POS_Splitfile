import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({Key? key}) : super(key: key);

  @override
  _CustomerManagementPageState createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  List<Map<String, dynamic>> customers = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    const url = 'http://192.168.1.130:8888/fastapi/customers/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          customers =
              List<Map<String, dynamic>>.from(json.decode(response.body))
                  .reversed
                  .toList();
        });
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _addCustomer(BuildContext context) async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name or phone cannot be empty!')),
        );
      }
      return;
    }

    const url = 'http://192.168.1.130:8888/fastapi/customers/';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customerName': nameController.text,
          'customerPhoneNumber': phoneController.text,
          'status': '1', // Assuming status is required
        }),
      );
      if (response.statusCode == 200) {
        fetchCustomers(); // Refresh the list after adding
      } else {
        throw Exception('Failed to add customer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _editCustomer(
      BuildContext context, Map<String, dynamic> customer, int index) async {
    nameController.text = customer['customerName'];
    phoneController.text = customer['customerPhoneNumber'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _updateCustomer(context, customer['customerId']);
              Navigator.of(context).pop();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCustomer(BuildContext context, String customerId) async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name or phone number cannot be empty!')),
        );
      }
      return;
    }

    const String baseUrl = 'http://192.168.1.130:8888/fastapi/customers/';
    final String url = '$baseUrl$customerId'; // Append customer ID to URL

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customerName': nameController.text,
          'customerPhoneNumber': phoneController.text,
        }),
      );

      if (response.statusCode == 200) {
        fetchCustomers(); // Refresh the list after updating
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Customer updated successfully!')),
          );
        }
      } else {
        throw Exception('Failed to update customer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      nameController.clear();
      phoneController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Add New Customer"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Customer Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _addCustomer(context);
                          fetchCustomers();
                          nameController.clear();
                          phoneController.clear();
                          Navigator.of(context).pop();
                        },
                        child: Text('Save'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Add New Customer',
                  style: TextStyle(color: Colors.blue)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                foregroundColor: Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Expanded(
              child: customers.isNotEmpty
                  ? ListView(
                      children: [
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('S.No')),
                            DataColumn(label: Text('Customer Name')),
                            DataColumn(label: Text('Customer Phone Number')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: List<DataRow>.generate(
                            customers.length,
                            (index) => DataRow(cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(customers[index]['customerName'])),
                              DataCell(Text(
                                  customers[index]['customerPhoneNumber'])),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editCustomer(
                                      context, customers[index], index),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        "No data available",
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
