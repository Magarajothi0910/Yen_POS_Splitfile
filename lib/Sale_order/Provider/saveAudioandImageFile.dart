import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────
// PERMISSION HELPER
// ──────────────────────────────────────────────────────────────

/// Asks for media / storage permission on Android.
/// Returns `true` if any requested permission is granted.
/// (iOS/macOS/Linux return `true` immediately – sandboxed.)
Future<bool> ensureStoragePermission() async {
  if (!Platform.isAndroid) {
    return true; // desktop & iOS: nothing to do
  }

  // Legacy READ / WRITE for API 32 and below
  final legacy = await Permission.storage.request();

  // Granular permissions for API 33+
  final photos = await Permission.photos.request(); // READ_MEDIA_IMAGES

  final audio = await Permission.audio.request(); // READ_MEDIA_AUDIO

  final isGranted = legacy.isGranted || photos.isGranted || audio.isGranted;

  return isGranted;
}

// ──────────────────────────────────────────────────────────────
// FILE HELPERS
// ──────────────────────────────────────────────────────────────

/// Creates <Downloads>/YenPOS/salesOrders/<SALE_ORDER_ID>.
/// Returns the Directory, or `null` if permission was denied / unavailable.
/// Set [skipPermissionCheck] to true if permission already granted.
Future<Directory?> createOrderDir(
  String saleOrderId, {
  bool skipPermissionCheck = false,
}) async {
  if (!skipPermissionCheck) {
    final hasPermission = await ensureStoragePermission();
    if (!hasPermission) {
      return null;
    }
  } else {}

  final downloads = await getDownloadsDirectory();
  if (downloads == null) {
    return null;
  }

  final dirPath = '${downloads.path}/YenPOS/salesOrders/$saleOrderId';

  final dir = Directory(dirPath);

  final exists = await dir.exists();

  if (!exists) {
    try {
      await dir.create(recursive: true);
    } catch (e) {
      return null;
    }
  } else {}

  return dir;
}

/// Copies [src] into [dir] with [fileName] and original extension.
/// Returns the saved file's absolute path, or `null` if something failed.
Future<String?> saveFile(File src, Directory dir, String fileName) async {
  try {
    // Check if source file exists
    final srcExists = await src.exists();

    if (!srcExists) {
      return null;
    }

    // Get file size
    final srcLength = await src.length();

    // Extract extension
    final srcPath = src.path;
    final ext = srcPath.split('.').last;

    // Create destination path
    final destPath = '${dir.path}/$fileName.$ext';

    // Copy file
    final bytes = await src.readAsBytes();

    final dest = File(destPath);
    await dest.writeAsBytes(bytes);

    // Verify copy
    final destExists = await dest.exists();
    final destLength = await dest.length();

    if (destExists && destLength > 0) {
      return dest.path;
    } else {
      return null;
    }
  } catch (e, stackTrace) {
    return null;
  }
}

/// Quick true/false check that the file exists and is non-empty.
Future<bool> verifyFile(String path) async {
  try {
    final exists = await File(path).exists();

    if (!exists) {
      return false;
    }

    final length = await File(path).length();

    final isValid = length > 0;
    return isValid;
  } catch (e) {
    return false;
  }
}

Future<String?> clearFile(String? path) async {
  if (path == null) {
    return null;
  }

  final f = File(path);

  try {
    final exists = await f.exists();

    if (exists) {
      final length = await f.length();

      await f.delete();

      // Verify deletion
      final stillExists = await f.exists();
      if (!stillExists) {
      } else {}
    } else {}
  } catch (e, stackTrace) {}

  return null; // always reset variable
}
