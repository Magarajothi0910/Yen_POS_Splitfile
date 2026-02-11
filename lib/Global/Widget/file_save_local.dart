import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorage {
  static Future<String> getExternalDocumentPath() async {
    Directory _directory = Directory("");
    if (Platform.isAndroid) {
      _directory = Directory("/storage/emulated/0/Download");
    } else {
      _directory = await getApplicationDocumentsDirectory();
    }

    final exPath = _directory.path;

    await Directory(exPath).create(recursive: true);
    return exPath;
  }

  static Future<String> get _localPath async {
    final String directory = await getExternalDocumentPath();
    return directory;
  }

  // Save a string (not used for audio/images but keeping for completeness)
  static Future<File> writeCounter(String bytes, String name) async {
    final path = await _localPath;
    File file = File('$path/$name');

    return file.writeAsString(bytes);
  }

  // Save a binary file (for audio and images)
  static Future<File> saveFile(File sourceFile, String fileName) async {
    final path = await _localPath;
    File newFile = File('$path/$fileName');

    return sourceFile.copy(newFile.path); // Copy the file to the new location
  }
}
