// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/pos_detector.dart';
// import 'package:yen_pos/Global/Screen/camera_qr_screen.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';

// class EmployeeSearch extends StatefulWidget {
//   final Function(String)? onEmployeeSelected;
//   const EmployeeSearch({Key? key, this.onEmployeeSelected}) : super(key: key);

//   @override
//   State<EmployeeSearch> createState() => _EmployeeSearchState();
// }

// class _EmployeeSearchState extends State<EmployeeSearch> {
//   // ---------- Hive employees ----------
//   Map<String, Map<String, dynamic>> _allEmployees = {};

//   // ---------- QR ----------
//   bool _isQrMode = false;
//   final FocusNode _qrFocusNode = FocusNode();
//   final TextEditingController _qrController = TextEditingController();
//   bool _isProcessingQr = false;

//   // ---------- Provider ----------
//   late final SalesInvoiceState _prov;

//   @override
//   void initState() {
//     super.initState();
//     _prov = Provider.of<SalesInvoiceState>(context, listen: false);
//     _loadEmployees();
//   }

//   @override
//   void dispose() {
//     _qrFocusNode.dispose();
//     _qrController.dispose();
//     super.dispose();
//   }

//   // -----------------------------------------------------------------
//   // 1. Load employees from Hive (exactly as you had)
//   // -----------------------------------------------------------------
//   Future<void> _loadEmployees() async {
//     final box = await Hive.openBox('employeeBox');
//     final List<dynamic> employees = box.get('employees', defaultValue: []);
//     _allEmployees = {
//       for (var emp in employees)
//         '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}': (emp as Map).cast<String, dynamic>(),
//     };
//     if (mounted) setState(() {});
//   }

//   // -----------------------------------------------------------------
//   // 2. Employee selection (used by Autocomplete & QR)
//   // -----------------------------------------------------------------
//   void _selectEmployee(String selection) {
//     final employee = _allEmployees[selection];
//     if (employee == null) return;

//     _prov.updateMultiple(
//       selectedEmployeeFirstName: employee['firstName'],
//       selectedEmployeeNumber: employee['employeeNumber'],
//     );
//     _prov.employee.text = selection;

//     // Notify parent if callback provided
//     widget.onEmployeeSelected?.call(selection);

//     debugPrint('Selected employee: $selection');
//   }

//   // -----------------------------------------------------------------
//   // 3. QR LOGIC ----------------------------------------------------
//   // -----------------------------------------------------------------
//   Future<void> _toggleQrMode() async {
//     final isPOS = await POSDetector.isPOSDevice;

//     if (isPOS) {
//       _startHardwareScanner();
//     } else {
//       _startCameraScan();
//     }
//   }

//   // ----- hardware scanner (POS) -----
//   void _startHardwareScanner() {
//     setState(() {
//       _isQrMode = true;
//       _qrFocusNode.requestFocus();
//     });
//   }

//   // ----- camera scanner -----
//   Future<void> _startCameraScan() async {
//     final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()));

//     if (result != null && result.isNotEmpty) {
//       _handleQrInput(result);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No QR code detected or scan cancelled.'), duration: Duration(seconds: 1)));
//     }
//   }

//   // ----- parse & apply QR data -----
//   void _handleQrInput(String raw) async {
//     if (_isProcessingQr || !_isQrMode) return;
//     setState(() => _isProcessingQr = true);

//     try {
//       final data = _parseQrData(raw);
//       final name = data['Name']?.toString().trim();
//       if (name == null) throw Exception('Name not found in QR');

//       // Find the employee that contains this name
//       final match = _allEmployees.entries.firstWhereOrNull((e) => e.key.contains(name));

//       if (match != null) {
//         _selectEmployee(match.key);
//         _prov.employee.selection = TextSelection.fromPosition(TextPosition(offset: match.key.length));
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee not found in list.')));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR error: $e')));
//     } finally {
//       _qrController.clear();
//       _qrFocusNode.unfocus();
//       setState(() {
//         _isProcessingQr = false;
//         _isQrMode = false;
//       });
//     }
//   }

//   Map<String, dynamic> _parseQrData(String raw) {
//     try {
//       return json.decode(raw) as Map<String, dynamic>;
//     } catch (_) {
//       // fallback key-value parsing
//       final map = <String, dynamic>{};
//       raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       });
//       if (map.isEmpty) throw Exception('Invalid format');
//       return map;
//     }
//   }

//   // -----------------------------------------------------------------
//   // 4. UI ---------------------------------------------------------
//   // -----------------------------------------------------------------
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<SalesInvoiceState>(
//       builder: (context, p, _) {
//         return Expanded(
//           flex: 2,
//           child: Stack(
//             children: [
//               // ---------- Autocomplete ----------
//               Autocomplete<String>(
//                 optionsMaxHeight: 120,
//                 optionsViewBuilder: (ctx, onSelected, options) => Material(
//                   color: Colors.white,
//                   shadowColor: Colors.black,
//                   elevation: 4,
//                   borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
//                   child: ListView.separated(
//                     separatorBuilder: (_, __) => const Divider(thickness: 1, color: Colors.black12),
//                     shrinkWrap: true,
//                     itemCount: options.length,
//                     itemBuilder: (_, i) {
//                       final opt = options.elementAt(i);
//                       return ListTile(title: Text(opt), onTap: () => onSelected(opt));
//                     },
//                   ),
//                 ),
//                 optionsBuilder: (tv) {
//                   if (tv.text.isEmpty) return const Iterable<String>.empty();
//                   final q = tv.text.toLowerCase();
//                   return _allEmployees.keys.where((k) => k.toLowerCase().contains(q));
//                 },
//                 onSelected: _selectEmployee,
//                 fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
//                   // IMPORTANT: DO NOT override controller.value
//                   return TextFormField(
//                     readOnly: false,
//                     showCursor: true,
//                     controller: controller,
//                     focusNode: focusNode,
//                     decoration: InputDecoration(
//                       labelText: "Sales Person",
//                       labelStyle: const TextStyle(fontFamily: "Poppins",color: Colors.black54),
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(0)),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(0),
//                         borderSide: const BorderSide(color: Colors.blue, width: 1),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(0),
//                         borderSide: const BorderSide(color: Colors.black26),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
//                       // QR ICON
//                       suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _toggleQrMode),
//                     ),
//                   );
//                 },
//               ),

//               // ---------- Hidden QR field (POS hardware scanner) ----------
//               if (_isQrMode)
//                 Offstage(
//                   offstage: true,
//                   child: TextField(
//                     focusNode: _qrFocusNode,
//                     controller: _qrController,
//                     keyboardType: TextInputType.none,
//                     onSubmitted: _handleQrInput,
//                     decoration: const InputDecoration(border: InputBorder.none),
//                     style: const TextStyle(fontFamily: "Poppins",fontSize: 0),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// // -----------------------------------------------------------------
// // Helper: firstWhereOrNull (Dart < 2.15)
// // -----------------------------------------------------------------
// extension IterableX<T> on Iterable<T> {
//   T? firstWhereOrNull(bool Function(T) test) {
//     for (final e in this) {
//       if (test(e)) return e;
//     }
//     return null;
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/custom_colors.dart';
import 'package:yen_pos/Global/pos_detector.dart';
import 'package:yen_pos/Global/Screen/camera_qr_screen.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';

// class EmployeeSearch extends StatefulWidget {
//   final Function(String)? onEmployeeSelected;
//   const EmployeeSearch({Key? key, this.onEmployeeSelected}) : super(key: key);

//   @override
//   State<EmployeeSearch> createState() => _EmployeeSearchState();
// }

// class _EmployeeSearchState extends State<EmployeeSearch> {
//   Map<String, Map<String, dynamic>> _allEmployees = {};

//   bool _isQrMode = false;
//   final FocusNode _qrFocusNode = FocusNode();
//   final TextEditingController _qrController = TextEditingController();
//   bool _isProcessingQr = false;

//   late final SalesInvoiceState _prov;

//   @override
//   void initState() {
//     super.initState();
//     _prov = Provider.of<SalesInvoiceState>(context, listen: false);
//     _loadEmployees();
//   }

//   @override
//   void dispose() {
//     _qrFocusNode.dispose();
//     _qrController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadEmployees() async {
//     final box = await Hive.openBox('employeeBox');
//     final List<dynamic> employees = box.get('employees', defaultValue: []);

//     _allEmployees = {
//       for (var emp in employees)
//         "${emp["employeeNumber"]} - ${emp["firstName"]}":
//             (emp as Map).cast<String, dynamic>(),
//     };

//     setState(() {});
//   }

//   /// SELECT EMPLOYEE
//   void _selectEmployee(String selection) {
//     final data = _allEmployees[selection];
//     if (data == null) return;

//     _prov.updateMultiple(
//       selectedEmployeeFirstName: data['firstName'],
//       selectedEmployeeNumber: data['employeeNumber'],
//     );

//     // Update provider’s stored field
//     _prov.employee.text = selection;

//     widget.onEmployeeSelected?.call(selection);

//     // Close keyboard
//     FocusScope.of(context).unfocus();
//   }

//   Future<void> _toggleQrMode() async {
//     final isPOS = await POSDetector.isPOSDevice;

//     if (isPOS) {
//       setState(() => _isQrMode = true);
//       _qrFocusNode.requestFocus();
//     } else {
//       final result = await Navigator.push<String>(
//         context,
//         MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
//       );

//       if (result != null && result.isNotEmpty) {
//         _handleQrInput(result);
//       }
//     }
//   }

//   void _handleQrInput(String raw) async {
//     if (_isProcessingQr || !_isQrMode) return;

//     setState(() => _isProcessingQr = true);

//     try {
//       final data = _parseQrData(raw);
//       final name = data["Name"]?.toString().trim().toLowerCase();

//       final match = _allEmployees.entries.firstWhereOrNull(
//         (e) => e.key.toLowerCase().contains(name ?? ""),
//       );

//       if (match != null) _selectEmployee(match.key);
//     } catch (_) {}

//     _qrController.clear();
//     _qrFocusNode.unfocus();

//     setState(() {
//       _isProcessingQr = false;
//       _isQrMode = false;
//     });
//   }

//   Map<String, dynamic> _parseQrData(String raw) {
//     try {
//       return json.decode(raw);
//     } catch (_) {
//       final map = <String, dynamic>{};
//       for (var part in raw.replaceAll("{", "").replaceAll("}", "").split(",")) {
//         final kv = part.split(":");
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       }
//       return map;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       flex: 2,
//       child: Autocomplete<String>(
//         optionsMaxHeight: 150,

//         optionsBuilder: (TextEditingValue value) {
//           final input = value.text.trim().toLowerCase();

//           if (input.isEmpty) return const Iterable<String>.empty();

//           return _allEmployees.entries
//               .where((entry) {
//                 final key = entry.key.toLowerCase();
//                 final empNo =
//                     entry.value['employeeNumber'].toString().toLowerCase();
//                 final name =
//                     entry.value['firstName'].toString().toLowerCase();

//                 return key.contains(input) ||
//                     empNo.contains(input) ||
//                     name.contains(input);
//               })
//               .map((e) => e.key);
//         },

//         onSelected: (val) => _selectEmployee(val),

//         fieldViewBuilder:
//             (context, textController, focusNode, onFieldSubmitted) {
//           // Always initialize controller with provider value ONCE
//           if (textController.text != _prov.employee.text) {
//             textController.text = _prov.employee.text;
//             textController.selection = TextSelection.fromPosition(
//               TextPosition(offset: textController.text.length),
//             );
//           }

//           // UI → Provider only
//           textController.addListener(() {
//             _prov.employee.value = textController.value;
//           });

//           return TextFormField(
//             cursorColor: Colors.blue,
//             controller: textController,
//             focusNode: focusNode,
//             decoration: InputDecoration(
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(7),
//                 borderSide: const BorderSide(color: Colors.blue, width: 2),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(7),
//                 borderSide: const BorderSide(color: Colors.black12),
//               ),
//               labelText: "Sales Person",
//               labelStyle:  TextStyle(color: Colors.black54,fontFamily: "Poppins"),
//               border: const OutlineInputBorder(),
//               contentPadding:
//                   const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
//               suffixIcon: IconButton(
//                 icon:  Icon(Icons.qr_code_scanner,color: CustomColors.black.withOpacity(0.7),),
//                 onPressed: _toggleQrMode,
//               ),
//             ),
//           );
//         },

//         optionsViewBuilder: (ctx, onSelected, options) {
//           return Material(
//             color: Colors.white,
//             elevation: 4,
//             child: ListView.separated(
//               separatorBuilder: (_, __) =>
//                    Divider(thickness: 1, color: Colors.black12.withOpacity(0.1)),
//               padding: EdgeInsets.zero,
//               itemCount: options.length,
//               itemBuilder: (_, i) {
//                 final opt = options.elementAt(i);
//                 return ListTile(
//                   title: Text(opt,style: TextStyle(fontFamily: "Poppins")),
//                   onTap: () => onSelected(opt),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// extension IterableX<T> on Iterable<T> {
//   T? firstWhereOrNull(bool Function(T) test) {
//     for (final e in this) {
//       if (test(e)) return e;
//     }
//     return null;
//   }
// }

class EmployeeSearch extends StatefulWidget {
  final Function(String)? onEmployeeSelected;
  final TextEditingController employeeController;
  final FocusNode employeeFocusNode;
  final bool readOnly;
  final VoidCallback? onEmpSelected;

  const EmployeeSearch({
    Key? key,
    required this.employeeController,
    required this.employeeFocusNode,
    this.onEmployeeSelected,
    required this.readOnly,
    this.onEmpSelected,
  }) : super(key: key);

  @override
  State<EmployeeSearch> createState() => _EmployeeSearchState();
}

class _EmployeeSearchState extends State<EmployeeSearch> {
  /// EMPLOYEE DATA
  Map<String, Map<String, dynamic>> _allEmployees = {};

  /// QR
  bool _isQrMode = false;
  bool _isProcessingQr = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();

  late final SalesInvoiceState _prov;

  @override
  void initState() {
    super.initState();
    _prov = Provider.of<SalesInvoiceState>(context, listen: false);

    /// Sync UI → Provider (ONCE)
    widget.employeeController.addListener(() {
      _prov.employee.value = widget.employeeController.value;
    });

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

    widget.employeeController.text = selection;

    widget.onEmployeeSelected?.call(selection);

    widget.employeeFocusNode.unfocus();
  }

  /// QR MODE
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

      if (match != null) {
        _selectEmployee(match.key);
      }
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
        if (kv.length == 2) {
          map[kv[0].trim()] = kv[1].trim();
        }
      }
      return map;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.employeeController,
      focusNode: widget.employeeFocusNode,

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

      //  onSelected:
      //   _selectEmployee,
      onSelected: (s) {
        _selectEmployee(s);
        widget.onEmpSelected?.call();
      },

      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: widget.readOnly,
          cursorColor: Colors.blue,
          decoration: InputDecoration(
            labelText: "Sales Person",
            labelStyle: const TextStyle(
              color: Colors.black54,
              fontFamily: "Poppins",
            ),
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Colors.black12),
            ),
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

      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 4,
          color: Colors.white,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: options.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.black12.withOpacity(0.1)),
            itemBuilder: (_, i) {
              final opt = options.elementAt(i);
              return ListTile(
                title: Text(opt, style: const TextStyle(fontFamily: "Poppins")),
                onTap: () => onSelected(opt),
              );
            },
          ),
        );
      },
    );
  }
}

/// EXTENSION
extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
