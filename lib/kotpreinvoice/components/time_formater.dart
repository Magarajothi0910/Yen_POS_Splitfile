import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatElapsedTime(int totalSeconds) {
  if (totalSeconds < 60) {
    return "($totalSeconds s)"; // Example: "5s"
  }

  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  String formattedMinutes = minutes.toString().padLeft(2, '0');
  String formattedSeconds = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return "($hours:$formattedMinutes:${formattedSeconds}min)"; // Example: (1:10:22 min)
  } else {
    return "($minutes:${formattedSeconds}min)"; // Example: (12:22 min)
  }
}

int calculateElapsedTime(String? preinvoiceTime) {
  try {
    if (preinvoiceTime == null || preinvoiceTime.isEmpty) {
      print("Error: preinvoiceTime is null or empty");
      return 0; // Return 0 if time is missing
    }

    // Get current time
    DateTime now = DateTime.now();

    // ✅ Parse only if format is correct
    DateTime preInvoiceDateTime =
        DateFormat("hh:mm:ss a").parse(preinvoiceTime);

    // Attach today's date to preInvoiceDateTime
    preInvoiceDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      preInvoiceDateTime.hour,
      preInvoiceDateTime.minute,
      preInvoiceDateTime.second,
    );

    // ✅ Prevents negative time if preInvoiceTime is ahead of now
    if (preInvoiceDateTime.isAfter(now)) {
      print("Error: preinvoiceTime is in the future");
      return 0;
    }

    // ✅ Calculate difference in seconds
    return now.difference(preInvoiceDateTime).inSeconds;
  } catch (e) {
    print("Error parsing time: $e");
    return 0; // Return 0 if parsing fails
  }
}

Color getCardColor(int elapsedSeconds) {
  int elapsedMinutes = elapsedSeconds ~/ 60;

  if (elapsedMinutes > 6) {
    // Pastel Red for very old
    return const Color(0xFFFFC1C1);
  } else if (elapsedMinutes > 2) {
    // Pastel Yellow-Orange for medium wait
    return const Color(0xFFFFE0B2);
  } else {
    // Pastel Green for fresh/recent
    return const Color(0xFFC8E6C9);
  }
}
