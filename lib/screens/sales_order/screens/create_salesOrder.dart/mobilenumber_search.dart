import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../globals.dart';
import '../../sales_order_providers/customerScreen_provider.dart';
import '../../sales_order_providers/customer_search_provider.dart';

class CustomerSearchDropdown extends StatefulWidget {
  const CustomerSearchDropdown({Key? key}) : super(key: key);

  @override
  _CustomerSearchDropdownState createState() => _CustomerSearchDropdownState();
}

class _CustomerSearchDropdownState extends State<CustomerSearchDropdown> {
  final FocusNode _mobileFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late TextEditingController _combinedController;
  final _formKey = GlobalKey<FormState>();
  bool _isAddingCustomer = false;

  @override
  void initState() {
    super.initState();
    _combinedController = TextEditingController();
    _updateCombinedController();
    _combinedController.addListener(_combinedControllerListener);
  }

  /// Listener wrapper so we can safely add/remove
  void _combinedControllerListener() {
    _onMobileNumberChanged(_combinedController.text);
  }

  // Update combined controller with mobile number and name
  void _updateCombinedController() {
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    final mobile = customerProvider.mobileNoController.text;
    final name = customerProvider.customerNameController.text;
    _combinedController.text = (mobile.isNotEmpty && name.isNotEmpty)
        ? '$mobile - $name'
        : mobile.isNotEmpty
            ? mobile
            : '';
  }

  void _onMobileNumberChanged(String value) async {
    if (_isAddingCustomer) return; // Prevent re-trigger during add

    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    final mobile = value.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), '');

    customerProvider.mobileNoController.text = mobile;

    if (mobile.length < 10) {
      _removeSuggestionsOverlay();
      return;
    }

    final provider = context.read<CustomerSearchProvider>();
    await provider.fetchSuggestions(mobile);

    if (provider.suggestions.isEmpty) {
      _removeSuggestionsOverlay();
      if (!_isAddingCustomer) {
        _isAddingCustomer = true; // Set before showing dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAddCustomerDialog(customerProvider);
        });
      }
    } else {
      _showSuggestionsOverlay();
    }
  }

  void _showSuggestionsOverlay() {
    _removeSuggestionsOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeSuggestionsOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5.0),
          child: Consumer<CustomerSearchProvider>(
            builder: (context, provider, child) {
              return Material(
                elevation: 8.0,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: provider.suggestions.length + 1,
                    itemBuilder: (context, index) {
                      if (index < provider.suggestions.length) {
                        final suggestion = provider.suggestions[index];
                        return ListTile(
                          title:
                              Text(suggestion['mobileNo'] ?? 'Unknown Mobile'),
                          subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                          onTap: () {
                            _onSuggestionSelected(suggestion, customerProvider);
                          },
                        );
                      }
                      return ListTile(
                        leading: const Icon(Icons.add, color: Colors.green),
                        title: const Text('Add Customer Details'),
                        onTap: () {
                          _showAddCustomerDialog(customerProvider);
                          _removeSuggestionsOverlay();
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onSuggestionSelected(
    Map<String, dynamic> suggestion,
    CustomerScreenProvider customerProvider,
  ) {
    // Remove overlay immediately
    _removeSuggestionsOverlay();

    // Clear provider suggestions to prevent rebuild
    final searchProvider = context.read<CustomerSearchProvider>();
    searchProvider.clearSuggestions();

    // Temporarily disable listener
    _combinedController.removeListener(_combinedControllerListener);

    // Update provider controllers
    customerProvider.mobileNoController.text = suggestion['mobileNo'] ?? '';
    customerProvider.customerNameController.text = suggestion['name'] ?? '';

    // Update combined controller safely
    _combinedController.text =
        "${customerProvider.mobileNoController.text} - ${customerProvider.customerNameController.text}";

    // Re-attach listener
    _combinedController.addListener(_combinedControllerListener);

    // Close keyboard
    FocusScope.of(context).unfocus();

    // Force UI refresh
    setState(() {});
  }

  Future<bool> _checkCustomerExists(
      String mobile, CustomerScreenProvider provider) async {
    // 1. Check Hive box
    try {
      final box = await Hive.openBox('customers');
      final existsInHive =
          box.values.any((c) => c['mobileNo']?.toString() == mobile);
      if (existsInHive) {
        return true;
      }
    } catch (e) {}

    // 2. Check API
    try {
      final response = await http.get(
        Uri.parse(
            "http://192.168.1.130:8888/fastapi/customers/by-customer?customerPhoneNumber=$mobile"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
          return true;
        }
      } else {}
    } catch (e) {}

    return false;
  }

  void _showAddCustomerDialog(CustomerScreenProvider customerProvider) {
    final TextEditingController mobileController =
        TextEditingController(text: customerProvider.mobileNoController.text);
    final TextEditingController customerNameController =
        TextEditingController();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Add Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(color: Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Mobile number required';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                      return 'Enter a valid 10-digit Indian number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: customerNameController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(24),
                    FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z ]*$')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _isAddingCustomer = false;
              },
              child: const Text(
                'Cancel',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final String mobile = mobileController.text.trim();
                final String name = customerNameController.text.trim();

                if (mobile.length == 10 &&
                    RegExp(r'^\d+$').hasMatch(mobile) &&
                    name.isNotEmpty) {
                  final exists =
                      await _checkCustomerExists(mobile, customerProvider);
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This mobile number already exists!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Save new customer
                  await customerProvider.sendNewCustomer(mobile, name);

                  // Update controllers
                  customerProvider.mobileNoController.text = mobile;
                  customerProvider.customerNameController.text = name;
                  _updateCombinedController();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Customer “$name” added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(context);
                  _isAddingCustomer = false;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please enter a valid mobile number and name.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _mobileFocusNode.dispose();
    _combinedController.removeListener(_combinedControllerListener);
    _combinedController.dispose();
    _overlayEntry?.remove();
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    customerProvider.removeListener(_updateCombinedController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _removeSuggestionsOverlay();
      },
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              readOnly: true,
              showCursor: true,
              controller: _combinedController,
              focusNode: _mobileFocusNode,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^[0-9\s\-a-zA-Z]*$')),
                LengthLimitingTextInputFormatter(50),
              ],
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Customer Mobile & Name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    customerProvider.mobileNoController.clear();
                    customerProvider.customerNameController.clear();
                    _combinedController.clear();
                    _removeSuggestionsOverlay();
                    FocusScope.of(context).unfocus();
                  },
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isDense: false,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: _onMobileNumberChanged,
              onTap: () {
                ActiveField.activate(
                  ctrl: _combinedController,
                  node: _mobileFocusNode,
                  numeric: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
