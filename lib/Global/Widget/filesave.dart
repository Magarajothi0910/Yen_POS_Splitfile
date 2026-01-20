import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:yenpos/Global/Widget/file_save_local.dart';

class FileStorageManager {
  // Save audio and image files and return their paths
  static Future<Map<String, String?>> saveFiles({
    required String recordedFilePath,
    required File? pickedImage1,
    required File? pickedImage2,
  }) async {
    // 🔴 CRITICAL: Check and request permissions before saving
    await _checkAndRequestPermissions();

    String? savedAudioPath;
    String? savedImagePath1;
    String? savedImagePath2;

    // Save audio file
    if (recordedFilePath.isNotEmpty) {
      final audioFile = File(recordedFilePath);
      if (await audioFile.exists()) {
        final audioFileName =
            'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        final savedAudioFile = await FileStorage.saveFile(
          audioFile,
          audioFileName,
        );
        savedAudioPath = savedAudioFile.path;
      }
    }

    // Save image files
    if (pickedImage1 != null) {
      if (await pickedImage1.exists()) {
        final imageFileName1 =
            'image1_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImageFile1 = await FileStorage.saveFile(
          pickedImage1,
          imageFileName1,
        );
        savedImagePath1 = savedImageFile1.path;
      }
    }

    if (pickedImage2 != null) {
      if (await pickedImage2.exists()) {
        final imageFileName2 =
            'image2_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImageFile2 = await FileStorage.saveFile(
          pickedImage2,
          imageFileName2,
        );
        savedImagePath2 = savedImageFile2.path;
      }
    }

    // Return a map of saved file paths
    return {
      'audioPath': savedAudioPath,
      'imagePath1': savedImagePath1,
      'imagePath2': savedImagePath2,
    };
  }

  // 🔴 ADD THIS METHOD: Check and request necessary permissions
  static Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 10 and below
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        await Permission.storage.request();
      }

      // For Android 11 and above (API 30+)
      if (Platform.isAndroid &&
          await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // Also check for camera/microphone if needed
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }

      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        await Permission.microphone.request();
      }
    }

    if (Platform.isIOS) {
      var photosStatus = await Permission.photos.status;
      if (!photosStatus.isGranted) {
        await Permission.photos.request();
      }
    }
  }
}
