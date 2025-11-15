import 'package:hive/hive.dart';
import 'dart:async';

import 'package:synchronized/synchronized.dart';

class PatchHandler {
  static Box<String>? messageBox;
  static const String _boxName = 'processedMessages';
  static const Duration _messageExpiry = Duration(minutes: 30);
  static final lock = Lock(); // Synchronization lock

  // Initialize Hive box for processed messages
  static Future<void> init() async {
    messageBox = await Hive.openBox<String>(_boxName);
  }

  // Check if messageId has been processed
  static bool containsMessage(String messageId) {
    return messageBox?.containsKey(messageId) ?? false;
  }

  // Mark messageId as processed with timestamp
  static void addProcessedMessage(String messageId) {
    messageBox?.put(messageId, DateTime.now().toIso8601String());
  }

  // Remove processed message
  static void removeMessage(String messageId) {
    messageBox?.delete(messageId);
  }

  // Clear expired messages
  static void clearExpiredMessages() {
    final now = DateTime.now();
    messageBox?.toMap().forEach((key, value) {
      try {
        final timestamp = DateTime.parse(value);
        if (now.difference(timestamp) > _messageExpiry) {
          messageBox?.delete(key);
        }
      } catch (e) {}
    });
  }
}
