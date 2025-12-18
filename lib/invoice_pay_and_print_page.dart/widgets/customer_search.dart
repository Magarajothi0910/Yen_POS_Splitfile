import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/CustomerTopProductsProvider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yenpos/regular_mode_page/widget/current_sale_section.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/quantity_dialog.dart';
import 'package:yenpos/regular_mode_page/widget/variance_dialog.dart';

/// Debouncer used to avoid rapid repeated calls
class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({this.milliseconds = 400});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// InputFormatter that limits digits to [maxDigits] for the "mobile" prefix.
/// It allows additional chars (like " - name") but ensures the numeric part
/// doesn't exceed maxDigits.
class MobilePrefixDigitLimiter extends TextInputFormatter {
  final int maxDigits;

  MobilePrefixDigitLimiter({this.maxDigits = 10});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    // Extract digits only (mobile part) from new text up to the first non-digit occurrence
    // We will allow non-digit characters after the mobile prefix (so "123 - John" is ok).
    String digits = '';
    for (int i = 0; i < newText.length; i++) {
      final ch = newText[i];
      if (RegExp(r'\d').hasMatch(ch) && digits.length < maxDigits) {
        digits += ch;
      } else if (!RegExp(r'\d').hasMatch(ch)) {
        // stop reading digits on first non-digit after digits started
        // but still allow insertion of non-digit if digits <= maxDigits
        // build final by combining digits and remainder of newText after current i
        final remainder = newText.substring(i);
        final combined = digits + remainder;
        return TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(
            offset: (digits + remainder).length,
          ),
        );
      } else if (RegExp(r'\d').hasMatch(ch) && digits.length >= maxDigits) {
        // skip this digit (prevent exceeding maxDigits)
        continue;
      }
    }

    // If everything is digits only and within limit, accept
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class CustomerSearchDropdown extends StatefulWidget {
  final TextEditingController customerNumberController;
  final FocusNode focusNode;
  final bool readOnly;
  final bool showTopProducts;

  const CustomerSearchDropdown({
    Key? key,
    required this.customerNumberController,
    required this.focusNode,
    required this.readOnly,
    required this.showTopProducts,
  }) : super(key: key);

  @override
  _CustomerSearchDropdownState createState() => _CustomerSearchDropdownState();
}

class _CustomerSearchDropdownState extends State<CustomerSearchDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final _formKey = GlobalKey<FormState>();
  final _debouncer = _Debouncer(milliseconds: 400);
  final _mobileDigitLimiter = MobilePrefixDigitLimiter(maxDigits: 10);

  bool _manuallySettingController =
      false; // prevents reacting to programmatic changes

  @override
  void initState() {
    super.initState();

    // initialize provider's mobile controller from incoming controller
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerProvider.mobileNoController.text = _extractMobileFromCombined(
      widget.customerNumberController.text,
    );

    developer.log(
      'Initial customerNumberController text: ${widget.customerNumberController.text}',
      name: 'CustomerSearch',
    );

    // If there's existing mobile, fetch suggestions once (debounced)
    final initialMobile = _extractMobileFromCombined(
      widget.customerNumberController.text,
    );
    if (initialMobile.isNotEmpty) {
      // use debouncer to avoid immediate repeated calls on hot reload etc.
      _debouncer.call(() => _onMobileNumberChanged(initialMobile));
    }

    widget.customerNumberController.addListener(_combinedControllerListener);
    widget.focusNode.addListener(_handleFocusChange);
  }

  String _extractMobileFromCombined(String combined) {
    final left = combined.split(' - ').first;
    return left.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _combinedControllerListener() {
    if (!mounted) return;
    if (_manuallySettingController) return; // ignore programmatic updates

    final raw = widget.customerNumberController.text;
    developer.log('Controller changed: $raw', name: 'CustomerSearch');

    final mobile = _extractMobileFromCombined(raw);

    // run the on-change via debouncer
    _debouncer.call(() => _onMobileNumberChanged(mobile));
  }

  // void _handleFocusChange() {
  //   final salesInvoiceState = context.read<SalesInvoiceState>();
  //   if (widget.focusNode.hasFocus &&
  //       !salesInvoiceState.isAddingCustomer &&
  //       mounted) {
  //     // keep only numeric mobile part when focus gained
  //     widget.customerNumberController.text = _extractMobileFromCombined(
  //       widget.customerNumberController.text,
  //     );
  //     developer.log('Focus gained, cleared name part', name: 'CustomerSearch');
  //   }
  // }

  void _handleFocusChange() {
    if (!mounted) return;
    if (!widget.focusNode.hasFocus) return;

    final currentText = widget.customerNumberController.text.trim();

    // Only strip to mobile number if NO name exists
    final hasName =
        currentText.contains(' - ') &&
        currentText.split(' - ').length > 1 &&
        currentText.split(' - ')[1].trim().isNotEmpty;

    if (!hasName) {
      final mobileOnly = _extractMobileFromCombined(currentText);
      widget.customerNumberController.text = mobileOnly;
      widget.customerNumberController.selection = TextSelection.collapsed(
        offset: mobileOnly.length,
      );
    }
    // If hasName == true → do NOTHING → preserve "9876543210 - John"
  }

  Future<void> _onMobileNumberChanged(String value) async {
    if (!mounted) return;
    final currentText = widget.customerNumberController.text.trim();
    final hasName =
        currentText.contains(' - ') &&
        currentText.split(' - ').length > 1 &&
        currentText.split(' - ')[1].trim().isNotEmpty;

    if (hasName) {
      _removeSuggestionsOverlay();
      return; // ← Stops everything if customer already selected
    }
    final salesInvoiceState = context.read<SalesInvoiceState>();
    if (salesInvoiceState.isAddingCustomer) {
      developer.log(
        'Skipping _onMobileNumberChanged because isAddingCustomer=true',
        name: 'CustomerSearch',
      );
      return;
    }

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final mobile = value.replaceAll(RegExp(r'[^0-9]'), '');

    developer.log('Mobile number extracted: $mobile', name: 'CustomerSearch');

    // Update provider mobile field (keeps UI in sync)
    customerProvider.mobileNoController.text = mobile;

    if (mobile.isEmpty) {
      _removeSuggestionsOverlay();
      return;
    }

    // fetch suggestions
    final provider = context.read<CustomerSearchProvider>();
    await provider.fetchSuggestions(mobile);
    if (!mounted) return;
    developer.log(
      'Suggestions fetched: ${provider.suggestions.length}',
      name: 'CustomerSearch',
    );

    if (provider.suggestions.isNotEmpty) {
      final validSuggestions = provider.suggestions
          .where(
            (s) =>
                s['mobile']?.toString().isNotEmpty == true &&
                s['name']?.toString().isNotEmpty == true,
          )
          .toList();
      if (validSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _removeSuggestionsOverlay();
      }
    } else {
      _removeSuggestionsOverlay();
    }

    // When user typed 10 digits exactly, check exact match and either auto-fill or show add dialog
    if (mobile.length == 10 &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(mobile) &&
        mounted) {
      // Prevent race: check provider state before attempting to open dialog
      final existingCustomer = await _checkCustomerExists(mobile);
      if (!mounted) return;
      if (existingCustomer != null) {
        // auto-fill selection
        developer.log(
          'Auto-fill found existing customer: $existingCustomer',
          name: 'CustomerSearch',
        );
        _onSuggestionSelected({
          'mobile': mobile,
          'name': existingCustomer['name'] ?? '',
        });
        // small UX toast
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(
          //       'Customer "${existingCustomer['name'] ?? 'Unknown'}" selected.',
          //     ),
          //     backgroundColor: Colors.blue,
          //   ),
          // );
        }
        return;
      }

      // If no existing, show add dialog only if not already adding
      if (!salesInvoiceState.isAddingCustomer) {
        salesInvoiceState.updateIsAddingCustomer(true);
        // schedule dialog on next frame to avoid context issues; also re-check mounted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showAddCustomerDialog(customerProvider);
        });
      } else {
        developer.log(
          'Skipping add dialog because isAddingCustomer=true',
          name: 'CustomerSearch',
        );
      }
    }
  }

  void _showSuggestionsOverlay() {
    if (!mounted) return;
    _removeSuggestionsOverlay();
    _overlayEntry = _createOverlayEntry();
    final overlay = Overlay.of(context);
    if (overlay != null) overlay.insert(_overlayEntry!);
    developer.log('Suggestions overlay shown', name: 'CustomerSearch');
  }

  void _removeSuggestionsOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      developer.log('Suggestions overlay removed', name: 'CustomerSearch');
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5.0),
          child: Consumer<CustomerSearchProvider>(
            builder: (context, provider, child) {
              final validSuggestions = provider.suggestions
                  .where(
                    (s) =>
                        s['mobile']?.toString().isNotEmpty == true &&
                        s['name']?.toString().isNotEmpty == true,
                  )
                  .toList();

              if (validSuggestions.isEmpty) {
                developer.log(
                  'No valid suggestions to display',
                  name: 'CustomerSearch',
                );
                return const SizedBox.shrink();
              }

              developer.log(
                'Displaying ${validSuggestions.length} valid suggestions',
                name: 'CustomerSearch',
              );

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
                    itemCount: validSuggestions.length + 1,
                    itemBuilder: (context, index) {
                      if (index < validSuggestions.length) {
                        final suggestion = validSuggestions[index];
                        final mobile = suggestion['mobile']!.toString();
                        final name = suggestion['name']!.toString();
                        developer.log(
                          'Rendering suggestion: mobile=$mobile, name=$name',
                          name: 'CustomerSearch',
                        );
                        return ListTile(
                          title: Text(mobile),
                          subtitle: Text(name),
                          onTap: () {
                            _onSuggestionSelected(suggestion);
                          },
                        );
                      }
                      return ListTile(
                        leading: const Icon(Icons.add, color: Colors.green),
                        title: const Text('Add Customer Details'),
                        onTap: () {
                          final customerProvider =
                              Provider.of<CustomerScreenProvider>(
                                context,
                                listen: false,
                              );
                          final salesInvoiceState = context
                              .read<SalesInvoiceState>();
                          if (!salesInvoiceState.isAddingCustomer) {
                            salesInvoiceState.updateIsAddingCustomer(true);
                            _removeSuggestionsOverlay();
                            _showAddCustomerDialog(customerProvider);
                          } else {
                            developer.log(
                              'Add dialog already open, ignoring add-tap',
                              name: 'CustomerSearch',
                            );
                          }
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

  void _onSuggestionSelected(Map<String, dynamic> suggestion) {
    final mobile = suggestion['mobile']?.toString() ?? '';
    final name = suggestion['name']?.toString() ?? '';
    _onCustomerSelected(mobile, name);
  }

  void _onCustomerSelected(String mobile, String name) {
    if (!mounted) return;

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final searchProvider = context.read<CustomerSearchProvider>();
    final salesInvoiceState = context.read<SalesInvoiceState>();

    // remove overlay & suggestions
    _removeSuggestionsOverlay();
    searchProvider.clearSuggestions();

    // Temporarily prevent reacting to text changes
    _manuallySettingController = true;

    widget.customerNumberController.text = '$mobile - $name';
    customerProvider.mobileNoController.text = mobile;
    customerProvider.customerNameController.text = name;

    developer.log(
      'Customer selected: mobile=$mobile, name=$name',
      name: 'CustomerSearch',
    );

    // restore listener reaction
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _manuallySettingController = false;
    });

    // unfocus keyboard
    FocusScope.of(context).unfocus();

    // validate parent form if needed
    final parentState = context
        .findAncestorStateOfType<SalesInvoicePayAndPrintState>();
    parentState?.validateForm();

    // show top products if required
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTopProducts(mobile);
    });

    // ensure salesInvoiceState updated
    salesInvoiceState.updateIsAddingCustomer(false);
    salesInvoiceState.notifyListeners();
  }

  void _checkAndShowTopProducts(String mobile) {
    if (widget.showTopProducts) {
      developer.log(
        'Showing top products (flag enabled)',
        name: 'CustomerSearch',
      );
      showTopProductsDialog(mobile);
    } else {
      developer.log(
        'Skipping top products (flag disabled)',
        name: 'CustomerSearch',
      );
    }
  }

  void showTopProductsDialog(String customerPhone) {
    if (!mounted) return;

    developer.log(
      '🎯 Showing top products dialog for: $customerPhone',
      name: 'CustomerSearch',
    );

    final topProductsProvider = Provider.of<CustomerTopProductsProvider>(
      context,
      listen: false,
    );

    // Fetch top products
    topProductsProvider.fetchTopProducts(customerPhone);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        developer.log('🎯 Dialog builder called', name: 'CustomerSearch');
        return Consumer<CustomerTopProductsProvider>(
          builder: (context, provider, child) {
            developer.log(
              '🎯 Consumer builder called, isLoading: ${provider.isLoading}',
              name: 'CustomerSearch',
            );
            return AlertDialog(
              backgroundColor: Colors.white,
              alignment: Alignment.centerLeft,
              title: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text(
                    'Top Products',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      developer.log('🎯 Dialog closed', name: 'CustomerSearch');
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Poppins'),
                          ),
                        ],
                      )
                    : provider.topProducts.isEmpty
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'No top products found for this customer',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.maxFinite,
                        height: 400,
                        child: ListView.builder(
                          itemCount: provider.topProducts.length,
                          itemBuilder: (context, index) {
                            final product = provider.topProducts[index];
                            return _buildTopProductItem(product, context);
                          },
                        ),
                      ),
              ),
            );
          },
        );
      },
    ).then((value) {
      developer.log(
        '🎯 Dialog closed with value: $value',
        name: 'CustomerSearch',
      );
    });
  }

  Future<Map<String, dynamic>?> _checkCustomerExists(String mobile) async {
    if (!mounted) return null;
    developer.log(
      'Checking if customer exists: mobile=$mobile',
      name: 'CustomerSearch',
    );

    // Check Hive box first
    try {
      final box = await Hive.openBox('customerBox');
      final customers = box.values.toList();
      final customer = customers.firstWhere((c) {
        final mobileNo =
            c['customerPhoneNumber']?.toString() ??
            c['mobileNo']?.toString() ??
            c['mobile']?.toString() ??
            c['phone']?.toString();
        return mobileNo == mobile;
      }, orElse: () => null);
      if (customer != null) {
        final result = {
          'mobile':
              customer['customerPhoneNumber']?.toString() ??
              customer['mobileNo']?.toString() ??
              customer['mobile']?.toString() ??
              customer['phone']?.toString() ??
              mobile,
          'name':
              customer['customerName']?.toString() ??
              customer['name']?.toString() ??
              customer['fullName']?.toString() ??
              '',
        };
        developer.log(
          'Customer found in Hive: $result',
          name: 'CustomerSearch',
        );
        return result;
      }
    } catch (e) {
      developer.log('Error checking Hive: $e', name: 'CustomerSearch');
    }

    // Check remote API
    try {
      final response = await http.get(
        Uri.parse("/fastapi/customers/by-customer?customerPhoneNumber=$mobile"),
      );
      developer.log(
        'API response status: ${response.statusCode}, body: ${response.body}',
        name: 'CustomerSearch',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map && data.isNotEmpty) {
          final result = {
            'mobile':
                data['customerPhoneNumber']?.toString() ??
                data['mobileNo']?.toString() ??
                mobile,
            'name':
                data['customerName']?.toString() ??
                data['name']?.toString() ??
                '',
          };
          if (result['mobile']!.isNotEmpty && result['name']!.isNotEmpty)
            return result;
        } else if (data is List && data.isNotEmpty) {
          final item = data.first;
          final result = {
            'mobile':
                item['customerPhoneNumber']?.toString() ??
                item['mobileNo']?.toString() ??
                mobile,
            'name':
                item['customerName']?.toString() ??
                item['name']?.toString() ??
                '',
          };
          if (result['mobile']!.isNotEmpty && result['name']!.isNotEmpty)
            return result;
        }
      }
    } catch (e) {
      developer.log('Error checking API: $e', name: 'CustomerSearch');
    }

    developer.log('Customer does not exist', name: 'CustomerSearch');
    return null;
  }

  void _showAddCustomerDialog(CustomerScreenProvider customerProvider) {
    if (!mounted) return;
    final salesInvoiceState = context.read<SalesInvoiceState>();

    final TextEditingController mobileController = TextEditingController(
      text: _extractMobileFromCombined(widget.customerNumberController.text),
    );
    final TextEditingController customerNameController =
        TextEditingController();

    // Pre-fill name if exists
    _checkCustomerExists(mobileController.text).then((existingCustomer) {
      if (existingCustomer != null && mounted) {
        customerNameController.text =
            existingCustomer['name']?.toString() ?? '';
        developer.log(
          'Pre-filled customer name: ${customerNameController.text}',
          name: 'CustomerSearch',
        );
      }
    });

    developer.log(
      'Showing add customer dialog with initial mobile: ${mobileController.text}',
      name: 'CustomerSearch',
    );

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<SalesInvoiceState>(
          builder: (context, salesInvoiceState, child) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Add Customer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: salesInvoiceState.isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
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
                              prefixStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.black,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty)
                                return 'Mobile number required';
                              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value))
                                return 'Enter a valid 10-digit Indian number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: customerNameController,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(24),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z ]*$'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Customer Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty)
                                return 'Customer name required';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  // onPressed: salesInvoiceState.isSubmitting
                  //     ? null
                  //     : () {
                  //         developer.log(
                  //           'Add customer dialog cancelled',
                  //           name: 'CustomerSearch',
                  //         );
                  //         Navigator.pop(dialogContext);
                  //         if (mounted) {
                  //           salesInvoiceState.updateIsAddingCustomer(false);
                  //           widget.customerNumberController.text =
                  //               mobileController.text;
                  //           _validateForm();
                  //         }
                  //       },
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: salesInvoiceState.isSubmitting
                      ? null
                      : () async {
                          developer.log(
                            'Submit button pressed',
                            name: 'CustomerSearch',
                          );
                          if (!_formKey.currentState!.validate()) {
                            developer.log(
                              'Form validation failed',
                              name: 'CustomerSearch',
                            );
                            return;
                          }
                          salesInvoiceState.updateIsSubmitting(true);

                          final String mobile = mobileController.text.trim();
                          final String name = customerNameController.text
                              .trim();

                          developer.log(
                            'Submitting customer: mobile=$mobile, name=$name',
                            name: 'CustomerSearch',
                          );

                          if (mobile.length == 10 &&
                              RegExp(r'^\d+$').hasMatch(mobile) &&
                              name.isNotEmpty) {
                            final existingCustomer = await _checkCustomerExists(
                              mobile,
                            );
                            if (!mounted) return;
                            if (existingCustomer != null) {
                              // Existing -> auto select & close
                              developer.log(
                                'Customer already exists',
                                name: 'CustomerSearch',
                              );
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                salesInvoiceState.updateIsAddingCustomer(false);
                                salesInvoiceState.updateIsSubmitting(false);
                                _onSuggestionSelected(existingCustomer);
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     content: Text(
                                //       'Customer "${existingCustomer['name'] ?? 'Unknown'}" already exists!',
                                //     ),
                                //     backgroundColor: Colors.red,
                                //   ),
                                // );
                              }
                              return;
                            }

                            try {
                              // Save new customer via provider
                              await customerProvider.sendNewCustomer(
                                mobile,
                                name,
                                context,
                              );
                              developer.log(
                                'Customer saved successfully',
                                name: 'CustomerSearch',
                              );

                              // After save: select the customer (updates controllers, closes dialogs)
                              if (mounted) {
                                Navigator.pop(
                                  dialogContext,
                                ); // close add dialog
                                salesInvoiceState.updateIsAddingCustomer(false);
                                salesInvoiceState.updateIsSubmitting(false);

                                // Re-fetch suggestions and select
                                final provider = context
                                    .read<CustomerSearchProvider>();
                                await provider.fetchSuggestions(mobile);

                                // Programmatically set selection via the same flow so all UI updates are consistent
                                _onCustomerSelected(mobile, name);

                                // small toast
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     content: Text(
                                //       'Customer "$name" added successfully!',
                                //     ),
                                //     backgroundColor: Colors.green,
                                //   ),
                                // );
                              }
                            } catch (e) {
                              developer.log(
                                'Error saving customer: $e',
                                name: 'CustomerSearch',
                              );
                              if (mounted) {
                                salesInvoiceState.updateIsSubmitting(false);
                                salesInvoiceState.updateIsAddingCustomer(false);
                                Navigator.pop(dialogContext);
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(
                                //     content: Text('Failed to add customer: $e'),
                                //     backgroundColor: Colors.red,
                                //   ),
                                // );
                              }
                            }
                          } else {
                            developer.log(
                              'Invalid input: mobile=$mobile, name=$name',
                              name: 'CustomerSearch',
                            );
                            if (mounted) {
                              salesInvoiceState.updateIsSubmitting(false);
                              salesInvoiceState.updateIsAddingCustomer(false);
                              Navigator.pop(dialogContext);
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   const SnackBar(
                              //     content: Text(
                              //       'Please enter a valid mobile number and name.',
                              //     ),
                              //     backgroundColor: Colors.orange,
                              //   ),
                              // );
                            }
                          }
                        },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _validateForm() {
    if (mounted) {
      final parentState = context
          .findAncestorStateOfType<SalesInvoicePayAndPrintState>();
      parentState?.validateForm();
    }
  }

  @override
  void dispose() {
    widget.customerNumberController.removeListener(_combinedControllerListener);
    widget.focusNode.removeListener(_handleFocusChange);
    _removeSuggestionsOverlay();
    _debouncer.dispose();
    developer.log('CustomerSearchDropdown disposed', name: 'CustomerSearch');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (mounted) {
          FocusScope.of(context).unfocus();
          _removeSuggestionsOverlay();
          developer.log('TextField tapped, unfocused', name: 'CustomerSearch');
        }
      },
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              showCursor: true,
              cursorColor: Colors.blue,
              readOnly: widget.readOnly,
              controller: widget.customerNumberController,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.text,
              inputFormatters: [
                // Limit digits in the mobile prefix to 10. This formatter will
                // allow typing name after a separator too.
                _mobileDigitLimiter,
                // overall length limit to avoid huge values
                LengthLimitingTextInputFormatter(50),
                FilteringTextInputFormatter.allow(
                  RegExp(r'^[0-9\s\-a-zA-Z]*$'),
                ),
              ],
              decoration: InputDecoration(
                labelText: "Customer Mobile Numbers",
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 10,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (!mounted) return;
                    final customerProvider =
                        Provider.of<CustomerScreenProvider>(
                          context,
                          listen: false,
                        );
                    widget.customerNumberController.clear();
                    customerProvider.mobileNoController.clear();
                    customerProvider.customerNameController.clear();
                    _removeSuggestionsOverlay();
                    FocusScope.of(context).unfocus();
                    _validateForm();
                    developer.log(
                      'Clear button pressed',
                      name: 'CustomerSearch',
                    );
                  },
                ),
              ),
              onChanged: (s) {
                // onChanged must call the listener already attached; but keeping this
                // ensures immediate visual behaviour when readOnly is false.
                if (!widget.readOnly) {
                  _combinedControllerListener();
                }
              },
              onTap: () {
                final salesInvoiceState = Provider.of<SalesInvoiceState>(
                  context,
                  listen: false,
                );
                if (mounted) {
                  final parentState = context
                      .findAncestorStateOfType<SalesInvoicePayAndPrintState>();
                  parentState?.setCurrentFocusForController(
                    widget.customerNumberController,
                  );
                  developer.log(
                    'TextField tapped, setting focus',
                    name: 'CustomerSearch',
                  );
                }
                salesInvoiceState.updateIsAddingCustomer(false);
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildTopProductItem(
  Map<String, dynamic> product,
  BuildContext context,
) {
  final itemName = product['itemName']?.toString() ?? 'Unknown Item';
  final varianceName =
      product['varianceName']?.toString() ?? 'Unknown Variance';
  final price = (product['price'] as num?)?.toDouble() ?? 0.0;
  final purchaseCount = product['purchaseCount']?.toString() ?? '0';

  return Card(
    color: Colors.white,
    elevation: 4,
    shadowColor: Colors.black,
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
    child: ListTile(
      leading: const Icon(Icons.shopping_basket, color: Colors.blue),
      title: Text(
        itemName,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(varianceName, style: const TextStyle(fontFamily: 'Poppins')),
          Text(
            'Purchased $purchaseCount times',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: Text(
        '₹${price.toStringAsFixed(2)}',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
      onTap: () {
        _addTopProductToCart(product, context);
        Navigator.of(context).pop(); // Close the dialog
      },
    ),
  );
}

Future<void> _addTopProductToCart(
  Map<String, dynamic> product,
  BuildContext context,
) async {
  try {
    final itemName = product['itemName']?.toString();
    final varianceName = product['varianceName']?.toString();
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;

    if (itemName == null || varianceName == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Invalid product data'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    // Get item data from GlobalDataManager and properly convert types
    //final branchwiseData = GlobalDataManager().branchwiseItems['data'];
    final lazyBox = await Hive.openBox('items');
    final branchData = await lazyBox.get('branchwiseItems_$aliasname');
    final branchwiseData = branchData?['data'];
    if (branchwiseData == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Inventory data not available'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    // Convert to String key map
    final Map<String, dynamic> branchwiseItems = _convertMapToStringKey(
      branchwiseData,
    );
    final itemData = branchwiseItems[itemName];

    if (itemData == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Item "$itemName" not found in inventory'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    // Find the specific variance - convert variance map to String key map
    final varianceMap = _convertMapToStringKey(itemData['variance'] ?? {});
    final varianceData = varianceMap[varianceName];

    if (varianceData == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Variance "$varianceName" not found for "$itemName"'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    // Convert varianceData to String key map
    final Map<String, dynamic> safeVarianceData = _convertMapToStringKey(
      varianceData,
    );
    final Map<String, dynamic> safeItemData = _convertMapToStringKey(
      itemData['item'] ?? {},
    );

    // Check UOM to determine if it's weight-based
    final varianceUOM =
        safeVarianceData['variance_Uom']?.toString().toLowerCase() ?? 'pcs';

    if (varianceUOM == 'kg' || varianceUOM == 'kgs') {
      // Show weight dialog for weight-based items
      showWeightDialog(
        context,
        itemName,
        varianceName,
        price,
        onWeightSelected: (weight) async {
          // Add the weight-based item to cart
          await _addWeightItemToCartDirectly(
            context,
            itemName,
            varianceName,
            price,
            weight,
            safeVarianceData,
            safeItemData,
          );
        },
      );
    } else {
      // For non-weight items, add directly with quantity 1
      await _addRegularItemToCartDirectly(
        context,
        itemName,
        varianceName,
        price,
        safeVarianceData,
        safeItemData,
      );
    }
  } catch (e) {
    developer.log('Error in _addTopProductToCart: $e', name: 'CustomerSearch');
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Error adding product to cart: $e'),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }
}

// Helper function to convert Map<dynamic, dynamic> to Map<String, dynamic>
Map<String, dynamic> _convertMapToStringKey(dynamic map) {
  if (map is Map<String, dynamic>) {
    return map;
  } else if (map is Map<dynamic, dynamic>) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map<dynamic, dynamic>) {
        result[stringKey] = _convertMapToStringKey(value);
      } else if (value is List) {
        result[stringKey] = value.map((item) {
          if (item is Map<dynamic, dynamic>) {
            return _convertMapToStringKey(item);
          }
          return item;
        }).toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }
  return {};
}

// Helper function to add regular items directly
Future<void> _addRegularItemToCartDirectly(
  BuildContext context,
  String itemName,
  String varianceName,
  double price,
  Map<String, dynamic> varianceData,
  Map<String, dynamic> itemData,
) async {
  try {
    final String itemId =
        "${itemName}_${varianceName}_${DateTime.now().millisecondsSinceEpoch}";

    // Create the item in the exact format expected by CurrentSaleProvider
    Map<String, dynamic> newItem = {
      'itemData': {
        ...itemData,
        'itemId':
            itemData['itemId']?.toString() ??
            itemData['hsnCode']?.toString() ??
            '',
        'itemName': itemName,
        'item_Uom': varianceData['variance_Uom']?.toString() ?? 'Pcs',
        'tax': _safeParseDouble(itemData['tax']) ?? 0.0,
      },
      'varianceData': {
        ...varianceData,
        'varianceName': varianceName,
        'variance_Defaultprice': price,
        'variance_Uom': varianceData['variance_Uom']?.toString() ?? 'Pcs',
        'varianceitemCode': varianceData['varianceitemCode']?.toString() ?? '',
      },
      'itemName': itemName,
      'quantity': 1.0,
      'weight': 0.0,
      'totalPrice': price * 1.0,
      'id': itemId,
      'uom': varianceData['variance_Uom']?.toString() ?? 'Pcs',
      'itemWiseDiscountAmount': 0.0,
      'itemWiseDiscount': 0.0,
      'isBoxItem': 'no',
    };

    // Process the item to ensure proper types
    final processedItem = _processCartItem(newItem);

    // Add to cart
    await Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    ).addItemToCart(processedItem);

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Added $varianceName to cart'),
    //     backgroundColor: Colors.green,
    //   ),
    // );

    developer.log(
      '✅ Successfully added $varianceName to cart',
      name: 'CustomerSearch',
    );
  } catch (e) {
    developer.log(
      '❌ Error adding regular item to cart: $e',
      name: 'CustomerSearch',
    );
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Failed to add $varianceName to cart: $e'),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }
}

// Helper function to add weight items directly
Future<void> _addWeightItemToCartDirectly(
  BuildContext context,
  String itemName,
  String varianceName,
  double price,
  double weight,
  Map<String, dynamic> varianceData,
  Map<String, dynamic> itemData,
) async {
  try {
    final String itemId =
        "${itemName}_${varianceName}_${DateTime.now().millisecondsSinceEpoch}";
    double totalPrice = price * weight;

    // Create the weight-based item in the exact format expected by CurrentSaleProvider
    Map<String, dynamic> newItem = {
      'itemData': {
        ...itemData,
        'itemId':
            itemData['itemId']?.toString() ??
            itemData['hsnCode']?.toString() ??
            '',
        'itemName': itemName,
        'item_Uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
        'tax': _safeParseDouble(itemData['tax']) ?? 0.0,
      },
      'varianceData': {
        ...varianceData,
        'varianceName': varianceName,
        'variance_Defaultprice': price,
        'variance_Uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
        'varianceitemCode': varianceData['varianceitemCode']?.toString() ?? '',
      },
      'itemName': itemName,
      'quantity': weight,
      'weight': weight,
      'totalPrice': totalPrice,
      'id': itemId,
      'uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
      'itemWiseDiscountAmount': 0.0,
      'itemWiseDiscount': 0.0,
      'isBoxItem': 'no',
    };

    // Process the item to ensure proper types
    final processedItem = _processCartItem(newItem);

    // Add to cart
    await Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    ).addItemToCart(processedItem);

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(
    //       'Added $varianceName (${weight.toStringAsFixed(3)} kg) to cart',
    //     ),
    //     backgroundColor: Colors.green,
    //   ),
    // );

    developer.log(
      '✅ Successfully added $varianceName (${weight.toStringAsFixed(3)} kg) to cart',
      name: 'CustomerSearch',
    );
  } catch (e) {
    developer.log(
      '❌ Error adding weight item to cart: $e',
      name: 'CustomerSearch',
    );
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Failed to add $varianceName to cart: $e'),
    //     backgroundColor: Colors.red,
    //   ),
    // );
  }
}

// Safe double parsing helper
double? _safeParseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Map<String, dynamic> _processCartItem(Map<String, dynamic> item) {
  // Ensure quantity and totalPrice are doubles
  if (item['quantity'] is String) {
    item['quantity'] = double.tryParse(item['quantity']) ?? 1.0;
  }

  if (item['totalPrice'] is String) {
    item['totalPrice'] = double.tryParse(item['totalPrice']) ?? 0.0;
  }

  // Ensure all numeric fields in itemData are proper types
  if (item['itemData'] is Map) {
    final itemData = Map<String, dynamic>.from(item['itemData']);
    _convertNumericFields(itemData);
    item['itemData'] = itemData;
  }

  // Ensure all numeric fields in varianceData are proper types
  if (item['varianceData'] is Map) {
    final varianceData = Map<String, dynamic>.from(item['varianceData']);
    _convertNumericFields(varianceData);
    item['varianceData'] = varianceData;
  }

  return item;
}

void _convertNumericFields(Map<String, dynamic> data) {
  data.forEach((key, value) {
    if (value is String) {
      // Try to convert string to double if it's numeric
      final numericValue = double.tryParse(value);
      if (numericValue != null) {
        data[key] = numericValue;
      }
    } else if (value is Map) {
      _convertNumericFields(Map<String, dynamic>.from(value));
    }
  });
}
