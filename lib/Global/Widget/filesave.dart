import 'dart:io';

import 'package:yenpos/Global/Widget/file_save_local.dart';



class FileStorageManager {
  // Save audio and image files and return their paths
  static Future<Map<String, String?>> saveFiles({
    required String recordedFilePath,
    required File? pickedImage1,
    required File? pickedImage2,
  }) async {
    String? savedAudioPath;
    String? savedImagePath1;
    String? savedImagePath2;

    // Save audio file
    if (recordedFilePath.isNotEmpty) {
      final audioFile = File(recordedFilePath);
      final audioFileName =
          'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      final savedAudioFile =
          await FileStorage.saveFile(audioFile, audioFileName);
      savedAudioPath = savedAudioFile.path;
      
    }

    // Save image files
    if (pickedImage1 != null) {
      final imageFileName1 =
          'image1_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImageFile1 =
          await FileStorage.saveFile(pickedImage1, imageFileName1);
      savedImagePath1 = savedImageFile1.path;
      
    }

    if (pickedImage2 != null) {
      final imageFileName2 =
          'image2_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImageFile2 =
          await FileStorage.saveFile(pickedImage2, imageFileName2);
      savedImagePath2 = savedImageFile2.path;
      
    }

    // Return a map of saved file paths
    return {
      'audioPath': savedAudioPath,
      'imagePath1': savedImagePath1,
      'imagePath2': savedImagePath2,
    };
  }
}
