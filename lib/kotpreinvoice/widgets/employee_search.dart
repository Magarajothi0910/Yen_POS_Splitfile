import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/custom_colors.dart';
import 'package:yen_pos/Global/pos_detector.dart';
import 'package:yen_pos/Global/Screen/camera_qr_screen.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';

class EmployeeSearchKOT extends StatefulWidget {
  final Function(String)? onEmployeeSelected;
  final bool isEnabled;

  const EmployeeSearchKOT({
    Key? key,
    this.onEmployeeSelected,
    required this.isEnabled,
  }) : super(key: key);

  @override
  State<EmployeeSearchKOT> createState() => _EmployeeSearchKOTState();
}

class _EmployeeSearchKOTState extends State<EmployeeSearchKOT> {
  Map<String, Map<String, dynamic>> _allEmployees = {};

  bool _isQrMode = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessingQr = false;

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

  Future<void> _loadEmployees() async {
    final box = await Hive.openBox('employeeBox');
    final List<dynamic> employees = box.get('employees', defaultValue: []);

    _allEmployees = {
      for (var emp in employees)
        "${emp["employeeNumber"]} - ${emp["firstName"]}": (emp as Map)
            .cast<String, dynamic>(),
    };

    setState(() {});
  }

  /// SELECT EMPLOYEE
  void _selectEmployee(String selection) {
    final data = _allEmployees[selection];
    if (data == null) return;

    _prov.updateMultiple(
      selectedEmployeeFirstName: data['firstName'],
      selectedEmployeeNumber: data['employeeNumber'],
    );

    // Update provider’s stored field
    _prov.employee.text = selection;

    widget.onEmployeeSelected?.call(selection);

    // Close keyboard
    FocusScope.of(context).unfocus();
  }

  Future<void> _toggleQrMode() async {
    final isPOS = await POSDetector.isPOSDevice;

    if (isPOS) {
      setState(() => _isQrMode = true);
      _qrFocusNode.requestFocus();
    } else {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
      );

      if (result != null && result.isNotEmpty) {
        _handleQrInput(result);
      }
    }
  }

  void _handleQrInput(String raw) async {
    if (_isProcessingQr || !_isQrMode) return;

    setState(() => _isProcessingQr = true);

    try {
      final data = _parseQrData(raw);
      final name = data["Name"]?.toString().trim().toLowerCase();

      final match = _allEmployees.entries.firstWhereOrNull(
        (e) => e.key.toLowerCase().contains(name ?? ""),
      );

      if (match != null) _selectEmployee(match.key);
    } catch (_) {}

    _qrController.clear();
    _qrFocusNode.unfocus();

    setState(() {
      _isProcessingQr = false;
      _isQrMode = false;
    });
  }

  Map<String, dynamic> _parseQrData(String raw) {
    try {
      return json.decode(raw);
    } catch (_) {
      final map = <String, dynamic>{};
      for (var part in raw.replaceAll("{", "").replaceAll("}", "").split(",")) {
        final kv = part.split(":");
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      }
      return map;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Autocomplete<String>(
        optionsMaxHeight: 150,

        optionsBuilder: (TextEditingValue value) {
          final input = value.text.trim().toLowerCase();

          if (input.isEmpty) return const Iterable<String>.empty();

          return _allEmployees.entries
              .where((entry) {
                final key = entry.key.toLowerCase();
                final empNo = entry.value['employeeNumber']
                    .toString()
                    .toLowerCase();
                final name = entry.value['firstName'].toString().toLowerCase();

                return key.contains(input) ||
                    empNo.contains(input) ||
                    name.contains(input);
              })
              .map((e) => e.key);
        },

        onSelected: (val) => _selectEmployee(val),

        fieldViewBuilder:
            (context, textController, focusNode, onFieldSubmitted) {
              // Always initialize controller with provider value ONCE
              if (textController.text != _prov.employee.text) {
                textController.text = _prov.employee.text;
                textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: textController.text.length),
                );
              }

              // UI → Provider only
              textController.addListener(() {
                _prov.employee.value = textController.value;
              });

              return TextFormField(
                cursorColor: Colors.blue,
                controller: textController,
                focusNode: focusNode,
                readOnly: widget.isEnabled,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  labelText: "Sales Person",
                  labelStyle: TextStyle(
                    color: Colors.black54,
                    fontFamily: "Poppins",
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 10,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: CustomColors.black.withOpacity(0.7),
                    ),
                    onPressed: _toggleQrMode,
                  ),
                ),
              );
            },

        optionsViewBuilder: (ctx, onSelected, options) {
          return Material(
            color: Colors.white,
            elevation: 4,
            child: ListView.separated(
              separatorBuilder: (_, __) =>
                  Divider(thickness: 1, color: Colors.black12.withOpacity(0.1)),
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final opt = options.elementAt(i);
                return ListTile(
                  title: Text(opt, style: TextStyle(fontFamily: "Poppins")),
                  onTap: () => onSelected(opt),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
