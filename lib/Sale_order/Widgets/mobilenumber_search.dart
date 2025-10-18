import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenposapp/Sale_order/Provider/customer_search_provider.dart';

class CustomerSearchDropdown extends StatefulWidget {
  const CustomerSearchDropdown({Key? key}) : super(key: key);

  @override
  _CustomerSearchDropdownState createState() => _CustomerSearchDropdownState();
}

class _CustomerSearchDropdownState extends State<CustomerSearchDropdown> {
  final FocusNode _mobileFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final _formKey = GlobalKey<FormState>();
  bool _isAddingCustomer = false;

  @override
  void initState() {
    super.initState();
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);

    // Initial update
    _updateCombinedController(customerProvider);

    // Listener attach
    customerProvider.customerCombinedController
        .addListener(_combinedControllerListener);

    final customerSearchProvider =
        Provider.of<CustomerSearchProvider>(context, listen: false);
    customerSearchProvider
        .fetchSuggestions(customerProvider.customerCombinedController.text);

    customerSearchProvider.refreshCustomersFromHive();
  }

  /// Listener wrapper
  void _combinedControllerListener() {
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    _onMobileNumberChanged(customerProvider.customerCombinedController.text);
  }

  // Update combined controller with mobile number and name
  void _updateCombinedController(CustomerScreenProvider customerProvider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mobile = customerProvider.mobileNoController.text;
      final name = customerProvider.customerNameController.text;

      customerProvider.customerCombinedController.text =
          (mobile.isNotEmpty && name.isNotEmpty)
              ? '$mobile - $name'
              : mobile.isNotEmpty
                  ? mobile
                  : '';
    });
  }

  void _onMobileNumberChanged(String value) async {
    if (_isAddingCustomer) return;
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
        _isAddingCustomer = true;
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
    final customerSearchProvider =
        Provider.of<CustomerSearchProvider>(context, listen: false);
    customerSearchProvider
        .fetchSuggestions(customerProvider.mobileNoController.text);
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5.0),
          child: Material(
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
                itemCount: customerSearchProvider.suggestions.length + 1,
                itemBuilder: (context, index) {
                  if (index < customerSearchProvider.suggestions.length) {
                    final suggestion =
                        customerSearchProvider.suggestions[index];
                    return ListTile(
                      title: Text(suggestion['mobile'] ?? 'Unknown Mobile'),
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
          ),
        ),
      ),
    );
  }

  void _onSuggestionSelected(
    Map<String, dynamic> suggestion,
    CustomerScreenProvider customerProvider,
  ) {
    _removeSuggestionsOverlay();

    final searchProvider = context.read<CustomerSearchProvider>();
    searchProvider.clearSuggestions();

    // Temporarily remove listener to prevent unwanted triggers
    customerProvider.customerCombinedController
        .removeListener(_combinedControllerListener);

    // Update fields
    final mobile = suggestion['mobile'] ?? '';
    final name = suggestion['name'] ?? '';

    customerProvider.mobileNoController.text = mobile;
    customerProvider.customerNameController.text = name;

    // ✅ Correctly update combined controller text to include both mobile + name
    customerProvider.customerCombinedController.text =
        name.isNotEmpty ? '$mobile - $name' : mobile;

    // Re-attach listener
    customerProvider.customerCombinedController
        .addListener(_combinedControllerListener);

    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Future<bool> _checkCustomerExists(
      String mobile, CustomerScreenProvider provider) async {
    try {
      final box = await Hive.openBox('customerBox');
      final existsInHive =
          box.values.any((c) => c['mobile']?.toString() == mobile);
      if (existsInHive) return true;
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse(
            "https://yenerp.com/fastapi/customers/by-customer?customerPhoneNumber=$mobile"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
          return true;
        }
      }
    } catch (_) {}
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
              Text('Add Customer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
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

                  await customerProvider.sendNewCustomer(mobile, name);
                  customerProvider.mobileNoController.text = mobile;
                  customerProvider.customerNameController.text = name;
                  _updateCombinedController(customerProvider);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Customer “$name” added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(context);
                  final customerSearchProvider =
                      Provider.of<CustomerSearchProvider>(context,
                          listen: false);
                  await customerSearchProvider.refreshCustomersFromHive();
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
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    customerProvider.customerCombinedController
        .removeListener(_combinedControllerListener);
    _overlayEntry?.remove();
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
                controller: customerProvider.customerCombinedController,
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
                      customerProvider.customerCombinedController.clear();
                      _removeSuggestionsOverlay();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: _onMobileNumberChanged,
                onTap: () {
                  ActiveField.activate(
                    ctrl: customerProvider.customerCombinedController,
                    node: _mobileFocusNode,
                    numeric: true,
                    fieldType: "customer number",
                  );
                }),
          ),
        ],
      ),
    );
  }
}
