import 'package:intl/intl.dart';

String convertToIso(String date, String time) {
  try {
    // Parse date (dd-MM-yyyy)
    final d = DateFormat("dd-MM-yyyy").parse(date);

    // Parse time (hh:mm a)
    final t = DateFormat("hh:mm a").parse(time);

    // Combine date + time into one DateTime
    final combined = DateTime(
      d.year,
      d.month,
      d.day,
      t.hour,
      t.minute,
      t.second,
    );

    // Return ISO format without milliseconds
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(combined);
  } catch (e) {
    return date; // fallback if parsing fails
  }
}
