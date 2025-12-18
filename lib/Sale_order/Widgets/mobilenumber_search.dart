import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/customer_search_provider.dart';

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
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    // Initial update
    _updateCombinedController(customerProvider);

    // Listener attach
    customerProvider.customerCombinedController.addListener(
      _combinedControllerListener,
    );

    final customerSearchProvider = Provider.of<CustomerSearchProvider>(
      context,
      listen: false,
    );
    customerSearchProvider.fetchSuggestions(
      customerProvider.customerCombinedController.text,
    );

    customerSearchProvider.refreshCustomersFromHive();
  }

  /// Listener wrapper
  void _combinedControllerListener() {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    _onMobileNumberChanged(customerProvider.customerCombinedController.text);
  }

  // Update combined controller with mobile number and name
  void _updateCombinedController(CustomerScreenProvider customerProvider) {
    final mobile = customerProvider.mobileNoController.text;
    final name = customerProvider.customerNameController.text;
    customerProvider.customerCombinedController.text =
        (mobile.isNotEmpty && name.isNotEmpty)
        ? '$mobile - $name'
        : mobile.isNotEmpty
        ? mobile
        : '';
  }

  void _onMobileNumberChanged(String value) async {
    if (_isAddingCustomer) return;

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    final mobile = value.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), '');
    customerProvider.mobileNoController.text = mobile;

    // 🔹 Stop everything below 3 digits
    if (mobile.length < 3) {
      _removeSuggestionsOverlay();
      return;
    }

    final provider = context.read<CustomerSearchProvider>();
    await provider.fetchSuggestions(mobile);

    // 🔹 If suggestions found → show dropdown
    if (provider.suggestions.isNotEmpty) {
      _showSuggestionsOverlay();
      return;
    }

    // 🔹 If user hasn't typed 10 digits → DO NOT show add dialog
    if (mobile.length != 10) {
      _removeSuggestionsOverlay();
      return;
    }

    // 🔹 10 digits typed AND no suggestions → show Add Customer Dialog
    if (!_isAddingCustomer) {
      _isAddingCustomer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddCustomerDialog(customerProvider);
      });
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
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    final customerSearchProvider = Provider.of<CustomerSearchProvider>(
      context,
      listen: false,
    );
    customerSearchProvider.fetchSuggestions(
      customerProvider.mobileNoController.text,
    );
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
              constraints: const BoxConstraints(maxHeight: 180),
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
    customerProvider.customerCombinedController.removeListener(
      _combinedControllerListener,
    );

    // Update fields
    final mobile = suggestion['mobile'] ?? '';
    final name = suggestion['name'] ?? '';

    customerProvider.mobileNoController.text = mobile;
    customerProvider.customerNameController.text = name;

    // ✅ Correctly update combined controller text to include both mobile + name
    customerProvider.customerCombinedController.text = name.isNotEmpty
        ? '$mobile - $name'
        : mobile;

    // Re-attach listener
    customerProvider.customerCombinedController.addListener(
      _combinedControllerListener,
    );

    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Future<bool> _checkCustomerExists(
    String mobile,
    CustomerScreenProvider provider,
  ) async {
    // --- 1️⃣ Check Hive ---
    try {
      final box = HiveManager.customers;
      final existsInHive = box.values.any(
        (c) => c['mobile']?.toString() == mobile,
      );
      if (existsInHive) return true;
    } catch (e) {}

    // --- 2️⃣ Check API ---
    try {
      final uri = Uri.parse(
        "https://yenerp.com/fluttertestapi/customers/by-customer?customerPhoneNumber=$mobile",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both Map or List
        bool existsInApi = false;
        if (data is List) {
          existsInApi = data.isNotEmpty;
        } else if (data is Map) {
          existsInApi = data.isNotEmpty;
        }

        if (existsInApi) return true;
      }
    } catch (e) {}

    return false;
  }

  String generateCustId() {
    final random = Random();
    return "CUST${random.nextInt(999999).toString().padLeft(6, '0')}";
  }

  Future<void> _showAddCustomerDialog(
    CustomerScreenProvider customerProvider,
  ) async {
    // Controllers for this dialog instance
    final TextEditingController mobileController = TextEditingController(
      text: customerProvider.mobileNoController.text,
    );

    final TextEditingController customerNameController = TextEditingController(
      text: generateCustId(),
    );

    // Local form key for this dialog only
    final GlobalKey<FormState> _dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 500,
            vertical: 40,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  spreadRadius: 2,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                // Submit button enabled only if name is not empty
                bool isSubmitEnabled = customerNameController.text
                    .trim()
                    .isNotEmpty;

                // Listener to update button state dynamically
                customerNameController.addListener(() {
                  setState(() {});
                });

                return Form(
                  key: _dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.person_add_alt_1,
                            color: Colors.blue,
                            size: 26,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Add Customer",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Mobile number field
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
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Mobile number required';
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Customer name field
                      TextFormField(
                        controller: customerNameController,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(24),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z ]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _isAddingCustomer = false;
                            },
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSubmitEnabled
                                  ? Colors.blue
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isSubmitEnabled
                                ? () async {
                                    // Validate form
                                    if (!_dialogFormKey.currentState!
                                        .validate())
                                      return;

                                    final mobile = mobileController.text.trim();
                                    final name = customerNameController.text
                                        .trim();

                                    // Check if customer already exists
                                    final exists = await _checkCustomerExists(
                                      mobile,
                                      customerProvider,
                                    );
                                    if (exists) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'This number already exists!',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Add new customer
                                    await customerProvider.sendNewCustomer(
                                      mobile,
                                      name,
                                      context,
                                    );

                                    // Update provider controllers
                                    customerProvider.mobileNoController.text =
                                        mobile;
                                    customerProvider
                                            .customerNameController
                                            .text =
                                        name;

                                    _updateCombinedController(customerProvider);
                                    Navigator.of(context).pop();
                                    _isAddingCustomer = false;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Customer "$name" added successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                : null,
                            child: const Text(
                              "Submit",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mobileFocusNode.dispose();
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    customerProvider.customerCombinedController.removeListener(
      _combinedControllerListener,
    );
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
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
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: _onMobileNumberChanged,
              onTap: () {
                ActiveField.activate(
                  context: context,
                  ctrl: customerProvider.customerCombinedController,
                  node: _mobileFocusNode,
                  numeric: true,
                  fieldType: "customer number",
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
