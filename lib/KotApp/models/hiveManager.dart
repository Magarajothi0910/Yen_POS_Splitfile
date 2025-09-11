// // ignore: file_names
// import 'package:hive/hive.dart';

// class HiveManager {
//   static final HiveManager _instance = HiveManager._internal();

//   factory HiveManager() => _instance;

//   HiveManager._internal();

//   Box<dynamic>? _invoices;
//   Box<dynamic>? _posInvoiceBox;
//   Box<dynamic>? _tableStatusBox;

//   Future<Box<dynamic>> get invoices async {
//     _invoices ??= await Hive.openBox('invoices').catchError((e) {
//       // Handle errors or log them
//       print('Error opening invoices box: $e');
//     });
//     return _invoices!;
//   }

//   Future<Box<dynamic>> get posInvoiceBox async {
//     _posInvoiceBox ??= await Hive.openBox('posInvoiceBox').catchError((e) {
//       // Handle errors or log them
//       print('Error opening posInvoice box: $e');
//     });
//     return _posInvoiceBox!;
//   }

//   Future<Box<dynamic>> get tableStatusBox async {
//     _tableStatusBox ??= await Hive.openBox('tableStatus').catchError((e) {
//       // Handle errors or log them
//       print('Error opening tableStatus box: $e');
//     });
//     return _tableStatusBox!;
//   }

//   Future<void> closeAllBoxes() async {
//     if (_invoices != null) {
//       await _invoices!
//           .close()
//           .catchError((e) => print('Error closing invoices box: $e'));
//     }
//     if (_posInvoiceBox != null) {
//       await _posInvoiceBox!
//           .close()
//           .catchError((e) => print('Error closing posInvoice box: $e'));
//     }
//     if (_tableStatusBox != null) {
//       await _tableStatusBox!
//           .close()
//           .catchError((e) => print('Error closing tableStatus box: $e'));
//     }
//   }
// }
