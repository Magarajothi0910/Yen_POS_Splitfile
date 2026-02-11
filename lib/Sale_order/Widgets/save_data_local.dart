import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

Future<void> saveJsonToFile(Map<String, dynamic> data) async {
  // Convert data to JSON string
  final String jsonData = jsonEncode(data);

  // Get the internal storage directory.
  final Directory directory = await getApplicationDocumentsDirectory();

  // Format the current date to use as a folder name
  final DateFormat formatter = DateFormat('dd-MM-yyyy');
  final String formattedDate = formatter.format(DateTime.now());

  // Create a new directory for the current date inside the internal storage directory.
  final Directory path = Directory('${directory.path}/Invoices/$formattedDate');
  if (!await path.exists()) {
    await path.create(
        recursive: true); // Create the directory if it doesn't exist
  }

  // Define the file path
  final File file = File('${path.path}/invoice.json');

  // Write JSON data to the file
  await file.writeAsString(jsonData);
}
