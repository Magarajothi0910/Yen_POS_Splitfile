// // services/hive_service.dart
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';

// class HiveService {
//   static final HiveService _instance = HiveService._internal();
//   factory HiveService() => _instance;
//   HiveService._internal();

//   late Box<PendingPrintInvoice> pendingPrintBox;
//   bool _isInitialized = false;

//   Future<void> init() async {
//     if (_isInitialized) return;

//     await Hive.initFlutter();

//     // Register adapter with correct typeId 11
//     if (!Hive.isAdapterRegistered(11)) {
//       Hive.registerAdapter(PendingPrintInvoiceAdapter());
//     }

//     pendingPrintBox = await Hive.openBox<PendingPrintInvoice>('pending_prints');
//     _isInitialized = true;
//   }

//   // Easy access
//   Box<PendingPrintInvoice> get pendingBox => pendingPrintBox;
// }
