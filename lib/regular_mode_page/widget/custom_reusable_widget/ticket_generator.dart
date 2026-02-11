import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart';

class TicketSequenceGenerator {
  static const String _boxName = 'ticketSequenceBox';
  static const String _key = 'nextTicketNumber';

  /// Returns the next unique ticket title: "Ticket - N"
  static Future<String> generate() async {
    ticketName = ticketName!.trim();
    if (ticketName == null || ticketName.isEmpty) ticketName = 'Ticket';

    final box = await Hive.openBox(_boxName);
    final key = 'seq_$ticketName';
    int next = (box.get(key) as int?) ?? 1;

    final title = '$ticketName - $next';
    await box.put(key, next + 1);
    await box.close();

    return title;
  }

  /// Get current sequence number without incrementing
  static Future<int> getCurrentSequence() async {
    final box = await Hive.openBox(_boxName);
    int currentNumber = (box.get(_key) as int?) ?? 1;
    await box.close();
    return currentNumber;
  }

  /// Optional: Reset sequence (only for testing)
  static Future<void> reset() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_key);
    await box.close();
  }
}
