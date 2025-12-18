// ==================== OR ====================
// Better approach: Create a helper method

import 'package:intl/intl.dart';

class DateFormatHelper {
  /// Parse date string in 'dd-MM-yyyy' format
  static DateTime? parseCustomDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;

    try {
      return DateFormat('dd-MM-yyyy').parse(dateString);
    } catch (e) {
      print('Invalid date format: $dateString, Error: $e');
      return null;
    }
  }

  /// Convert DateTime to 'dd-MM-yyyy' string
  static String formatDateToString(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd-MM-yyyy').format(date);
  }

  /// Validate and convert date
  static String? validateAndConvert(String? dateString) {
    DateTime? parsed = parseCustomDate(dateString);
    return parsed != null ? formatDateToString(parsed) : null;
  }
}
