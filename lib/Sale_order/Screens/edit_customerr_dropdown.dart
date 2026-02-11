import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yen_pos/Sale_order/Provider/editcustomerscreenProvider.dart';

class EditCustomerSearchDropdown extends StatefulWidget {
  final bool isModifyMode;

  const EditCustomerSearchDropdown({Key? key, required this.isModifyMode})
    : super(key: key);

  @override
  _EditCustomerSearchDropdownState createState() =>
      _EditCustomerSearchDropdownState();
}

class _EditCustomerSearchDropdownState
    extends State<EditCustomerSearchDropdown> {
  final FocusNode _mobileFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _onMobileNumberChanged(String value) {
    if (!widget.isModifyMode) return; // Prevent input when not in modify mode

    final provider = context.read<CustomerSearchProvider>();
    provider.fetchSuggestions(value);

    if (value.isNotEmpty) {
      _showSuggestionsOverlay();
    } else {
      _removeSuggestionsOverlay();
    }
  }

  void _showSuggestionsOverlay() {
    if (!widget.isModifyMode)
      return; // Prevent showing overlay if not in modify mode

    _removeSuggestionsOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeSuggestionsOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final customerProvider = Provider.of<EditCustomerScreenProvider>(
      context,
      listen: false,
    );
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
                          title: Text(suggestion['mobile'] ?? 'Unknown Mobile'),
                          subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                          onTap: () {
                            _onSuggestionSelected(suggestion, customerProvider);
                            _removeSuggestionsOverlay();
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
    EditCustomerScreenProvider customerProvider,
  ) {
    customerProvider.mobileNoController.text = suggestion['mobile'] ?? '';
    customerProvider.customerNameController.text = suggestion['name'] ?? '';
    FocusScope.of(context).unfocus();
  }

  void _showAddCustomerDialog(EditCustomerScreenProvider customerProvider) {
    final TextEditingController mobileController = TextEditingController(
      text: customerProvider.mobileNoController.text,
    );
    final TextEditingController nameController = TextEditingController();

    showDialog(
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
          content: SingleChildScrollView(
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
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final String mobile = mobileController.text.trim();
                final String name = nameController.text.trim();

                if (mobile.length == 10 &&
                    RegExp(r'^\d+$').hasMatch(mobile) &&
                    name.isNotEmpty) {
                  final response = await customerProvider.addCustomer(
                    mobile,
                    name,
                  );
                  if (response) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Customer "$name" added successfully!',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await customerProvider.fetchSuggestions(mobile);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to add customer. Please try again.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid mobile number and name.',
                      ),
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
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<EditCustomerScreenProvider>(
      context,
      listen: false,
    );

    return Column(
      children: [
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: TextFormField(
                  controller: customerProvider.mobileNoController,
                  focusNode: _mobileFocusNode,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  keyboardType: TextInputType.phone,
                  enabled: widget
                      .isModifyMode, // Read-only unless modify mode is enabled
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Search Mobile Number',
                    isDense: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  style: TextStyle(fontSize: 14),
                  onChanged: _onMobileNumberChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: customerProvider.customerNameController,
                enabled: widget
                    .isModifyMode, // Read-only unless modify mode is enabled
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Customer Name',
                  isDense: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mobileFocusNode.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }
}
