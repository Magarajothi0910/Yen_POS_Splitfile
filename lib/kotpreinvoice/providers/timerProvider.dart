// // providers/timer_provider.dart
// import 'package:flutter/foundation.dart';
// import 'dart:async';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:flutter/material.dart';

// class TimerProvider extends ChangeNotifier {
//   final Map<String, DateTime> _preInvoiceTimers = {};
//   final Map<String, Timer> _activeTimers = {};

//   TimerProvider() {
//     _loadTimersFromStorage();
//   }

//   // Load timers from Hive storage
//   void _loadTimersFromStorage() async {
//     try {
//       final box = await Hive.openBox('pre_invoice_timers');
//       final storedTimers = box.toMap();

//       storedTimers.forEach((key, value) {
//         if (value is String) {
//           _preInvoiceTimers[key] = DateTime.parse(value);
//         }
//       });

//       // Start timers for existing pre-invoices
//       _preInvoiceTimers.forEach((key, _) {
//         _startTimerForKey(key);
//       });

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error loading timers: $e');
//     }
//   }

//   // Start timer for a table-seat combination
//   void startTimer(String tableNumber, String seat) {
//     final key = '$tableNumber-$seat';

//     // Cancel existing timer if any
//     _activeTimers[key]?.cancel();

//     // Start new timer
//     _preInvoiceTimers[key] = DateTime.now();
//     _startTimerForKey(key);

//     // Save to storage
//     _saveTimerToStorage(key, _preInvoiceTimers[key]!);

//     notifyListeners();
//   }

//   void _startTimerForKey(String key) {
//     _activeTimers[key] = Timer.periodic(const Duration(seconds: 1), (timer) {
//       notifyListeners();
//     });
//   }

//   // Stop timer for a table-seat combination
//   void stopTimer(String tableNumber, String seat) {
//     final key = '$tableNumber-$seat';
//     _activeTimers[key]?.cancel();
//     _activeTimers.remove(key);
//     _preInvoiceTimers.remove(key);

//     // Remove from storage
//     _removeTimerFromStorage(key);

//     notifyListeners();
//   }

//   // Get elapsed time for a table-seat
//   Duration getElapsedTime(String tableNumber, String seat) {
//     final key = '$tableNumber-$seat';
//     final startTime = _preInvoiceTimers[key];
//     if (startTime == null) return Duration.zero;

//     return DateTime.now().difference(startTime);
//   }

//   // Get formatted time string
//   String getFormattedTime(String tableNumber, String seat) {
//     final duration = getElapsedTime(tableNumber, seat);
//     final minutes = duration.inMinutes;
//     final seconds = duration.inSeconds % 60;

//     return '${minutes}m ${seconds}s';
//   }

//   // Get color based on time (0-2min green, 2+min red)
//   Color getPreinvoiceTimeColor(String tableNumber, String seat) {
//     final duration = getElapsedTime(tableNumber, seat);
//     final minutes = duration.inMinutes;
//     return minutes < 2
//         ? Colors.red.withOpacity(.2)
//         : minutes < 5
//         ? Colors.red.withOpacity(.3)
//         : minutes < 10
//         ? Colors.red.withOpacity(.6)
//         : Colors.red.withOpacity(.6);
//   }

//   Color getOrderTimeColor(String tableNumber, String seat) {
//     final duration = getElapsedTime(tableNumber, seat);
//     final minutes = duration.inMinutes;
//     return Colors.teal.withOpacity(.05);
//   }

//   // Check if timer exists for table-seat
//   bool hasTimer(String tableNumber, String seat) {
//     final key = '$tableNumber-$seat';
//     return _preInvoiceTimers.containsKey(key);
//   }

//   // Save timer to Hive
//   void _saveTimerToStorage(String key, DateTime startTime) async {
//     try {
//       final box = await Hive.openBox('pre_invoice_timers');
//       await box.put(key, startTime.toIso8601String());
//     } catch (e) {
//       debugPrint('Error saving timer: $e');
//     }
//   }

//   // Remove timer from Hive
//   void _removeTimerFromStorage(String key) async {
//     try {
//       final box = await Hive.openBox('pre_invoice_timers');
//       await box.delete(key);
//     } catch (e) {
//       debugPrint('Error removing timer: $e');
//     }
//   }

//   @override
//   void dispose() {
//     // Cancel all active timers
//     _activeTimers.forEach((key, timer) {
//       timer.cancel();
//     });
//     _activeTimers.clear();
//     super.dispose();
//   }
// }
