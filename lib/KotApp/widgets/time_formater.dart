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
      return 0;
    }

    // ✅ Calculate difference in seconds
    return now.difference(preInvoiceDateTime).inSeconds;
  } catch (e) {
    return 0; // Return 0 if parsing fails
  }
}

Color getCardColor(int elapsedSeconds) {
  int elapsedMinutes = elapsedSeconds ~/ 60; // Convert seconds to minutes
  if (elapsedMinutes > 6) {
    return const Color(0xFFFD563F); // 🟣 Purple (Furthest Past)
  } else if (elapsedMinutes > 2) {
    return const Color(0xFFFFB74D); // 🔵 Blue (More Recent Past)
  } else {
    return Color.fromARGB(255, 139, 209, 141); // 🟡 Yellow (Near Future)
  }
}
