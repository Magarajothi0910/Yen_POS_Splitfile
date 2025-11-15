import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';


class CustomerSearchDropdown extends StatefulWidget {
  final TextEditingController customerNumberController;
  final FocusNode focusNode;

  const CustomerSearchDropdown({
    Key? key,
    required this.customerNumberController,
    required this.focusNode,
  }) : super(key: key);

  @override
  _CustomerSearchDropdownState createState() => _CustomerSearchDropdownState();
}

class _CustomerSearchDropdownState extends State<CustomerSearchDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final customerProvider = Provider.of<CustomerScreenProvider>(context, listen: false);
    // Sync initial state
    customerProvider.mobileNoController.text =
        widget.customerNumberController.text.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), '');
    developer.log('Initial customerNumberController text: ${widget.customerNumberController.text}', name: 'CustomerSearch');
    // Fetch initial suggestions if any
    if (widget.customerNumberController.text.isNotEmpty) {
      _onMobileNumberChanged(widget.customerNumberController.text.split(' - ').first);
    }
    // Add listener to customerNumberController
    widget.customerNumberController.addListener(_combinedControllerListener);
    // Clear name part when focus gained
    widget.focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final salesInvoiceState = context.read<SalesInvoiceState>();
    if (widget.focusNode.hasFocus && !salesInvoiceState.isAddingCustomer && mounted) {
      widget.customerNumberController.text =
          widget.customerNumberController.text.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), '');
      developer.log('Focus gained, cleared name part', name: 'CustomerSearch');
    }
  }

  void _combinedControllerListener() {
    if (mounted) {
      developer.log('Controller changed: ${widget.customerNumberController.text}', name: 'CustomerSearch');
      _onMobileNumberChanged(widget.customerNumberController.text.split(' - ').first);
    }
  }

  void _onMobileNumberChanged(String value) async {
    final salesInvoiceState = context.read<SalesInvoiceState>();
    if (salesInvoiceState.isAddingCustomer || !mounted) {
      developer.log('Skipping _onMobileNumberChanged: _isAddingCustomer=${salesInvoiceState.isAddingCustomer}, mounted=$mounted',
          name: 'CustomerSearch');
      return;
    }

    final customerProvider = Provider.of<CustomerScreenProvider>(context, listen: false);
    final mobile = value.replaceAll(RegExp(r'[^0-9]'), '');

    developer.log('Mobile number extracted: $mobile', name: 'CustomerSearch');

    // Sync provider's mobileNoController
    customerProvider.mobileNoController.text = mobile;

    // Fetch suggestions as soon as there's input
    if (mobile.isNotEmpty) {
      final provider = context.read<CustomerSearchProvider>();
      await provider.fetchSuggestions(mobile);
      if (!mounted) return;
      developer.log('Suggestions fetched: ${provider.suggestions.length}', name: 'CustomerSearch');
      provider.suggestions.forEach((s) => developer.log('Suggestion: $s', name: 'CustomerSearch'));

      if (provider.suggestions.isNotEmpty) {
        // Filter out invalid suggestions
        final validSuggestions =
            provider.suggestions.where((s) => s['mobile']?.isNotEmpty == true && s['name']?.isNotEmpty == true).toList();
        if (validSuggestions.isNotEmpty && mounted) {
          _showSuggestionsOverlay();
        } else {
          _removeSuggestionsOverlay();
        }
      } else {
        _removeSuggestionsOverlay();
      }

      // Check for exact match when 10 digits
      if (mobile.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(mobile) && mounted) {
        final existingCustomer = await _checkCustomerExists(mobile);
        if (!mounted) return;
        if (existingCustomer != null) {
          _onSuggestionSelected({
            'mobile': mobile,
            'name': existingCustomer['name']?.toString() ?? '',
          });
          developer.log('Auto-filled existing customer: $existingCustomer', name: 'CustomerSearch');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Customer "${existingCustomer['name'] ?? 'Unknown'}" selected.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
          return;
        }
        if (!salesInvoiceState.isAddingCustomer && mounted) {
          salesInvoiceState.updateIsAddingCustomer(true);
          developer.log('Showing add customer dialog for mobile: $mobile', name: 'CustomerSearch');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAddCustomerDialog(customerProvider);
          });
        }
      }
    } else {
      _removeSuggestionsOverlay();
    }
  }

  void _showSuggestionsOverlay() {
    if (!mounted) return;
    _removeSuggestionsOverlay();
    _overlayEntry = _createOverlayEntry();
    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    }
    developer.log('Suggestions overlay shown', name: 'CustomerSearch');
  }

  void _removeSuggestionsOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      developer.log('Suggestions overlay removed', name: 'CustomerSearch');
    }
  }

  OverlayEntry _createOverlayEntry() {
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
              final validSuggestions =
                  provider.suggestions.where((s) => s['mobile']?.isNotEmpty == true && s['name']?.isNotEmpty == true).toList();
              if (validSuggestions.isEmpty) {
                developer.log('No valid suggestions to display', name: 'CustomerSearch');
                return const SizedBox.shrink();
              }
              developer.log('Displaying ${validSuggestions.length} valid suggestions', name: 'CustomerSearch');
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
                        developer.log('Rendering suggestion: mobile=$mobile, name=$name', name: 'CustomerSearch');
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
                          final customerProvider = Provider.of<CustomerScreenProvider>(context, listen: false);
                          context.read<SalesInvoiceState>().updateIsAddingCustomer(true);
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

  void _onSuggestionSelected(Map<String, dynamic> suggestion) {
    if (!mounted) return;
    final customerProvider = Provider.of<CustomerScreenProvider>(context, listen: false);
    final searchProvider = context.read<CustomerSearchProvider>();
    final salesInvoiceState = context.read<SalesInvoiceState>();

    // Remove overlay and clear suggestions
    _removeSuggestionsOverlay();
    searchProvider.clearSuggestions();

    // Remove listener temporarily
    widget.customerNumberController.removeListener(_combinedControllerListener);

    // Update controllers with suggestion data
    final mobile = suggestion['mobile']?.toString() ?? '';
    final name = suggestion['name']?.toString() ?? '';
    widget.customerNumberController.text = '$mobile - $name';
    customerProvider.mobileNoController.text = mobile;
    customerProvider.customerNameController.text = name;

    developer.log('Suggestion selected: mobile=$mobile, name=$name, display=${widget.customerNumberController.text}',
        name: 'CustomerSearch');

    // Re-attach listener
    widget.customerNumberController.addListener(_combinedControllerListener);

    // Unfocus to hide keyboard
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    // Trigger validation in parent
    if (mounted) {
      final parentState = context.findAncestorStateOfType<SalesInvoicePayAndPrintState>();
      parentState?.validateForm();
    }

    // Replaced setState(() {});
    salesInvoiceState.notifyListeners();
  }

  Future<Map<String, dynamic>?> _checkCustomerExists(String mobile) async {
    if (!mounted) return null;
    developer.log('Checking if customer exists: mobile=$mobile', name: 'CustomerSearch');
    // Check Hive box
    try {
      final box = await Hive.openBox('customerBox');
      final customers = box.values.toList();
      developer.log('Hive customers: $customers', name: 'CustomerSearch');
      final customer = customers.firstWhere(
        (c) {
          final mobileNo = c['customerPhoneNumber']?.toString() ??
              c['mobileNo']?.toString() ??
              c['mobile']?.toString() ??
              c['phone']?.toString();
          developer.log('Hive customer: $c, mobileNo=$mobileNo', name: 'CustomerSearch');
          return mobileNo == mobile;
        },
        orElse: () => null,
      );
      if (customer != null) {
        final result = {
          'mobile': customer['customerPhoneNumber']?.toString() ??
              customer['mobileNo']?.toString() ??
              customer['mobile']?.toString() ??
              customer['phone']?.toString() ??
              mobile,
          'name': customer['customerName']?.toString() ?? customer['name']?.toString() ?? customer['fullName']?.toString() ?? '',
        };
        developer.log('Customer found in Hive: $result', name: 'CustomerSearch');
        return result;
      }
    } catch (e) {
      developer.log('Error checking Hive: $e', name: 'CustomerSearch');
    }

    // Check API
    try {
      final response = await http.get(
        Uri.parse("http://192.168.1.114:8888/fastapi/customers/by-customer?customerPhoneNumber=$mobile"),
      );
      developer.log('API response status: ${response.statusCode}, body: ${response.body}', name: 'CustomerSearch');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('API raw data: $data', name: 'CustomerSearch');
        if (data != null && data is Map && data.isNotEmpty) {
          final result = {
            'mobile': data['customerPhoneNumber']?.toString() ??
                data['mobileNo']?.toString() ??
                data['mobile']?.toString() ??
                data['phone']?.toString() ??
                mobile,
            'name': data['customerName']?.toString() ?? data['name']?.toString() ?? data['fullName']?.toString() ?? '',
          };
          if (result['mobile']!.isNotEmpty && result['name']!.isNotEmpty) {
            developer.log('Customer found in API: $result', name: 'CustomerSearch');
            return result;
          }
        } else if (data is List && data.isNotEmpty) {
          final item = data.first;
          final result = {
            'mobile': item['customerPhoneNumber']?.toString() ??
                item['mobileNo']?.toString() ??
                item['mobile']?.toString() ??
                item['phone']?.toString() ??
                mobile,
            'name': item['customerName']?.toString() ?? item['name']?.toString() ?? item['fullName']?.toString() ?? '',
          };
          if (result['mobile']!.isNotEmpty && result['name']!.isNotEmpty) {
            developer.log('Customer found in API list: $result', name: 'CustomerSearch');
            return result;
          }
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
      text: widget.customerNumberController.text.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final TextEditingController customerNameController = TextEditingController();

    // Pre-fill name if customer exists
    _checkCustomerExists(mobileController.text).then((existingCustomer) {
      if (existingCustomer != null && mounted) {
        customerNameController.text = existingCustomer['name']?.toString() ?? '';
        developer.log('Pre-filled customer name: ${customerNameController.text}', name: 'CustomerSearch');
      }
    });

    developer.log('Showing add customer dialog with initial mobile: ${mobileController.text}', name: 'CustomerSearch');

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<SalesInvoiceState>(
          builder: (context, salesInvoiceState, child) {
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
                    style: TextStyle(fontFamily: 'Poppins',fontWeight: FontWeight.bold, fontSize: 18),
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
                              prefixStyle: const TextStyle(fontFamily: 'Poppins',color: Colors.black),
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
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Customer name required';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: salesInvoiceState.isSubmitting
                      ? null
                      : () {
                          developer.log('Add customer dialog cancelled', name: 'CustomerSearch');
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            salesInvoiceState.updateIsAddingCustomer(false);
                            widget.customerNumberController.text = mobileController.text;
                            salesInvoiceState.notifyListeners(); // Replace setState(() {});
                            _validateForm();
                          }
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: 'Poppins',color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: salesInvoiceState.isSubmitting
                      ? null
                      : () async {
                          developer.log('Submit button pressed', name: 'CustomerSearch');
                          if (!_formKey.currentState!.validate()) {
                            developer.log('Form validation failed', name: 'CustomerSearch');
                            if (mounted) {
                              salesInvoiceState.updateIsSubmitting(false); // Replace setState(() => _isSubmitting = false);
                            }
                            return;
                          }
                          if (mounted) {
                            salesInvoiceState.updateIsSubmitting(true); // Replace setState(() => _isSubmitting = true);
                          }
                          final String mobile = mobileController.text.trim();
                          final String name = customerNameController.text.trim();

                          developer.log('Submitting customer: mobile=$mobile, name=$name', name: 'CustomerSearch');

                          if (mobile.length == 10 && RegExp(r'^\d+$').hasMatch(mobile) && name.isNotEmpty) {
                            final existingCustomer = await _checkCustomerExists(mobile);
                            if (!mounted) return;
                            if (existingCustomer != null) {
                              developer.log('Customer already exists', name: 'CustomerSearch');
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Customer "${existingCustomer['name'] ?? 'Unknown'}" already exists!'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              });
                              if (mounted) {
                                salesInvoiceState.updateMultiple(
                                  isSubmitting: false,
                                  isAddingCustomer: false,
                                ); // Replace setState(() { _isSubmitting = false; _isAddingCustomer = false; });
                                Navigator.pop(dialogContext);
                                _onSuggestionSelected(existingCustomer);
                              }
                              return;
                            }
                            try {
                              // Save new customer
                              await customerProvider.sendNewCustomer(mobile, name);
                              developer.log('Customer saved successfully', name: 'CustomerSearch');

                              // Update controllers
                              widget.customerNumberController.text = '$mobile - $name';
                              customerProvider.mobileNoController.text = mobile;
                              customerProvider.customerNameController.text = name;

                              // Trigger validation in parent
                              if (mounted) {
                                final parentState = context.findAncestorStateOfType<SalesInvoicePayAndPrintState>();
                                parentState?.validateForm();
                              }

                              Navigator.pop(dialogContext);
                              if (mounted) {
                                salesInvoiceState.updateIsAddingCustomer(false);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Customer "$name" added successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                });
                                salesInvoiceState.updateIsSubmitting(false); // Replace setState(() => _isSubmitting = false);
                                // Re-fetch suggestions to update for recent save
                                final provider = context.read<CustomerSearchProvider>();
                                await provider.fetchSuggestions(mobile);
                              }
                            } catch (e) {
                              developer.log('Error saving customer: $e', name: 'CustomerSearch');
                              if (mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add customer: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                });
                                salesInvoiceState.updateMultiple(
                                  isSubmitting: false,
                                  isAddingCustomer: false,
                                ); // Replace setState(() { _isSubmitting = false; _isAddingCustomer = false; });
                                Navigator.pop(dialogContext);
                              }
                            }
                          } else {
                            developer.log('Invalid input: mobile=$mobile, name=$name', name: 'CustomerSearch');
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a valid mobile number and name.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              });
                              salesInvoiceState.updateMultiple(
                                isSubmitting: false,
                                isAddingCustomer: false,
                              ); // Replace setState(() { _isSubmitting = false; _isAddingCustomer = false; });
                              Navigator.pop(dialogContext);
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
      final parentState = context.findAncestorStateOfType<SalesInvoicePayAndPrintState>();
      parentState?.validateForm();
    }
  }

  @override
  void dispose() {
    widget.customerNumberController.removeListener(_combinedControllerListener);
    widget.focusNode.removeListener(_handleFocusChange);
    _removeSuggestionsOverlay();
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
              readOnly: true,
              controller: widget.customerNumberController,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^[0-9\s\-a-zA-Z]*$')),
                LengthLimitingTextInputFormatter(50),
              ],
              decoration: InputDecoration(
                labelText: "Customer Mobile Numbers",
                labelStyle: TextStyle(fontFamily: 'Poppins',color: Colors.black54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.black12,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 10,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (!mounted) return;
                    final customerProvider = Provider.of<CustomerScreenProvider>(context, listen: false);
                    widget.customerNumberController.clear();
                    customerProvider.mobileNoController.clear();
                    customerProvider.customerNameController.clear();
                    _removeSuggestionsOverlay();
                    FocusScope.of(context).unfocus();
                    _validateForm();
                    developer.log('Clear button pressed', name: 'CustomerSearch');
                  },
                ),
              ),
              onChanged: _onMobileNumberChanged,
              onTap: () {
                if (mounted) {
                  final parentState = context.findAncestorStateOfType<SalesInvoicePayAndPrintState>();
                  parentState?.setCurrentFocusForController(widget.customerNumberController);
                  developer.log('TextField tapped, setting focus', name: 'CustomerSearch');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}