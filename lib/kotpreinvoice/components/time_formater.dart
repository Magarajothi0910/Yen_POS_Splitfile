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
    return "(${hours}h:${formattedMinutes}m:${formattedSeconds}s)"; // Example: (1:10:22 min)
  } else {
    return "(${minutes}m:${formattedSeconds}s)"; // Example: (12:22 min)
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
    DateTime preInvoiceDateTime = DateFormat(
      "hh:mm:ss a",
    ).parse(preinvoiceTime);

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

  if (elapsedMinutes <= 2) {
    return const Color(0xFFFFEBEE); // Very Light Red (pastel)
  } else if (elapsedMinutes <= 4) {
    return const Color.fromARGB(255, 238, 174, 181); // Light Red
  } else if (elapsedMinutes <= 6) {
    return const Color.fromARGB(255, 246, 148, 148); // Medium Light Red
  } else {
    return const Color.fromARGB(255, 247, 120, 120); // Strong but still Light Red
  }
}
