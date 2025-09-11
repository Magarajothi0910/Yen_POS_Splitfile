import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../sales_order_providers/customerScreen_provider.dart';
import '../../sales_order_providers/customer_search_provider.dart';

class CreditCustomerSearchDropdown extends StatefulWidget {
  const CreditCustomerSearchDropdown({Key? key}) : super(key: key);

  @override
  _CreditCustomerSearchDropdownState createState() =>
      _CreditCustomerSearchDropdownState();
}

class _CreditCustomerSearchDropdownState
    extends State<CreditCustomerSearchDropdown> {
  // final TextEditingController mobileNoController = TextEditingController();
  // final TextEditingController customerNameController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _onMobileNumberChanged(String value) {
    final provider = context.read<CustomerSearchProvider>();
    provider.fetchSuggestions(value);

    // Show overlay when typing
    if (value.isNotEmpty) {
      _showSuggestionsOverlay();
    } else {
      _removeSuggestionsOverlay();
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
                    itemCount: provider.suggestions.isNotEmpty
                        ? provider.suggestions.length
                        : 1, // Only show one item when no results
                    itemBuilder: (context, index) {
                      if (provider.suggestions.isNotEmpty) {
                        final suggestion = provider.suggestions[index];
                        return ListTile(
                          title:
                              Text(suggestion['mobileNo'] ?? 'Unknown Mobile'),
                          subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                          onTap: () {
                            _onSuggestionSelected(suggestion, customerProvider);
                            _removeSuggestionsOverlay();
                          },
                        );
                      } else {
                        return ListTile(
                          title: const Text('No match found',
                              textAlign: TextAlign.center),
                        );
                      }
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

  void _onSuggestionSelected(Map<String, dynamic> suggestion,
      CustomerScreenProvider customerProvider) {
    customerProvider.mobileNoController.text = suggestion['mobileNo'] ?? '';
    customerProvider.customerNameController.text = suggestion['name'] ?? '';
    FocusScope.of(context).unfocus();
  }


  @override
  void dispose() {
    // mobileNoController.dispose();
    // customerNameController.dispose();
    _mobileFocusNode.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
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
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Search Mobile Number',
                    labelStyle: TextStyle(fontSize: 14),
                    isDense: false,
                    // suffixIcon: IconButton(
                    //   icon: const Icon(Icons.clear),
                    //   onPressed: () {
                    //     mobileNoController.clear();
                    //     customerNameController.clear();
                    //     _removeSuggestionsOverlay();
                    //   },
                    // ),
                  ),
                  onChanged: _onMobileNumberChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: customerProvider.customerNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(fontSize: 14),
                  isDense: false,
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
}
