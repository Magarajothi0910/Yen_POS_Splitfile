import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/pos_detector.dart';
import 'package:yenpos/Global/Screen/camera_qr_screen.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';

class EmployeeSearch extends StatefulWidget {
  final Function(String)? onEmployeeSelected;
  const EmployeeSearch({Key? key, this.onEmployeeSelected}) : super(key: key);

  @override
  State<EmployeeSearch> createState() => _EmployeeSearchState();
}

class _EmployeeSearchState extends State<EmployeeSearch> {
  // ---------- Hive employees ----------
  Map<String, Map<String, dynamic>> _allEmployees = {};

  // ---------- QR ----------
  bool _isQrMode = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessingQr = false;

  // ---------- Provider ----------
  late final SalesInvoiceState _prov;

  @override
  void initState() {
    super.initState();
    _prov = Provider.of<SalesInvoiceState>(context, listen: false);
    _loadEmployees();
  }

  @override
  void dispose() {
    _qrFocusNode.dispose();
    _qrController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // 1. Load employees from Hive (exactly as you had)
  // -----------------------------------------------------------------
  Future<void> _loadEmployees() async {
    final box = await Hive.openBox('employeeBox');
    final List<dynamic> employees = box.get('employees', defaultValue: []);
    _allEmployees = {
      for (var emp in employees)
        '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}': (emp as Map).cast<String, dynamic>(),
    };
    if (mounted) setState(() {});
  }

  // -----------------------------------------------------------------
  // 2. Employee selection (used by Autocomplete & QR)
  // -----------------------------------------------------------------
  void _selectEmployee(String selection) {
    final employee = _allEmployees[selection];
    if (employee == null) return;

    _prov.updateMultiple(
      selectedEmployeeFirstName: employee['firstName'],
      selectedEmployeeNumber: employee['employeeNumber'],
    );
    _prov.employee.text = selection;
    
    // Notify parent if callback provided
    widget.onEmployeeSelected?.call(selection);
    
    debugPrint('Selected employee: $selection');
  }

  // -----------------------------------------------------------------
  // 3. QR LOGIC ----------------------------------------------------
  // -----------------------------------------------------------------
  Future<void> _toggleQrMode() async {
    final isPOS = await POSDetector.isPOSDevice;

    if (isPOS) {
      _startHardwareScanner();
    } else {
      _startCameraScan();
    }
  }

  // ----- hardware scanner (POS) -----
  void _startHardwareScanner() {
    setState(() {
      _isQrMode = true;
      _qrFocusNode.requestFocus();
    });
  }

  // ----- camera scanner -----
  Future<void> _startCameraScan() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()));

    if (result != null && result.isNotEmpty) {
      _handleQrInput(result);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No QR code detected or scan cancelled.'), duration: Duration(seconds: 1)));
    }
  }

  // ----- parse & apply QR data -----
  void _handleQrInput(String raw) async {
    if (_isProcessingQr || !_isQrMode) return;
    setState(() => _isProcessingQr = true);

    try {
      final data = _parseQrData(raw);
      final name = data['Name']?.toString().trim();
      if (name == null) throw Exception('Name not found in QR');

      // Find the employee that contains this name
      final match = _allEmployees.entries.firstWhereOrNull((e) => e.key.contains(name));

      if (match != null) {
        _selectEmployee(match.key);
        _prov.employee.selection = TextSelection.fromPosition(TextPosition(offset: match.key.length));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee not found in list.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR error: $e')));
    } finally {
      _qrController.clear();
      _qrFocusNode.unfocus();
      setState(() {
        _isProcessingQr = false;
        _isQrMode = false;
      });
    }
  }

  Map<String, dynamic> _parseQrData(String raw) {
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      // fallback key-value parsing
      final map = <String, dynamic>{};
      raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final kv = pair.split(':');
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      });
      if (map.isEmpty) throw Exception('Invalid format');
      return map;
    }
  }

  // -----------------------------------------------------------------
  // 4. UI ---------------------------------------------------------
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<SalesInvoiceState>(
      builder: (context, p, _) {
        return Expanded(
          flex: 2,
          child: Stack(
            children: [
              // ---------- Autocomplete ----------
              Autocomplete<String>(
                optionsMaxHeight: 120,
                optionsViewBuilder: (ctx, onSelected, options) => Material(
                  color: Colors.white,
                  shadowColor: Colors.black,
                  elevation: 4,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                  child: ListView.separated(
                    separatorBuilder: (_, __) => const Divider(thickness: 1, color: Colors.black12),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options.elementAt(i);
                      return ListTile(title: Text(opt), onTap: () => onSelected(opt));
                    },
                  ),
                ),
                optionsBuilder: (tv) {
                  if (tv.text.isEmpty) return const Iterable<String>.empty();
                  final q = tv.text.toLowerCase();
                  return _allEmployees.keys.where((k) => k.toLowerCase().contains(q));
                },
                onSelected: _selectEmployee,
                fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                  // IMPORTANT: DO NOT override controller.value
                  return TextFormField(
                    readOnly: false,
                    showCursor: true,
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "Sales Person",
                      labelStyle: const TextStyle(fontFamily: "Poppins",color: Colors.black54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(0)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide: const BorderSide(color: Colors.blue, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide: const BorderSide(color: Colors.black26),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                      // QR ICON
                      suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _toggleQrMode),
                    ),
                  );
                },
              ),

              // ---------- Hidden QR field (POS hardware scanner) ----------
              if (_isQrMode)
                Offstage(
                  offstage: true,
                  child: TextField(
                    focusNode: _qrFocusNode,
                    controller: _qrController,
                    keyboardType: TextInputType.none,
                    onSubmitted: _handleQrInput,
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: const TextStyle(fontFamily: "Poppins",fontSize: 0),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------
// Helper: firstWhereOrNull (Dart < 2.15)
// -----------------------------------------------------------------
extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
