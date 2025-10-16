import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// ──────────────────────────────────────────────────────────────
///  PERMISSION HELPER
/// ──────────────────────────────────────────────────────────────

/// Asks for media / storage permission on Android.
/// Returns `true` if **any** requested permission is granted.
/// (iOS/macOS/Linux return `true` immediately – sandboxed.)
Future<bool> ensureStoragePermission() async {
  if (!Platform.isAndroid) return true; // desktop & iOS: nothing to do

  // Legacy READ / WRITE for API 32 and below
  final legacy = await Permission.storage.request();

  // Granular permissions for API 33 +
  final photos = await Permission.photos.request(); // READ_MEDIA_IMAGES
  final audio = await Permission.audio.request(); // READ_MEDIA_AUDIO

  return legacy.isGranted || photos.isGranted || audio.isGranted;
}

/// ──────────────────────────────────────────────────────────────
///  FILE HELPERS
/// ──────────────────────────────────────────────────────────────

/// Creates <Downloads>/YenPOS/salesOrders/<SALE_ORDER_ID>.
/// Returns the Directory, or `null` if permission was denied / unavailable.
Future<Directory?> createOrderDir(String saleOrderId) async {
  if (!await ensureStoragePermission()) return null;

  final downloads =
      await getDownloadsDirectory(); // /storage/emulated/0/Download
  if (downloads == null) return null; // should never be null on Android

  final dir = Directory('${downloads.path}/YenPOS/salesOrders/$saleOrderId');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Copies [src] into [dir] with [fileName] and original extension.
/// Returns the saved file’s absolute path, or `null` if something failed.
Future<String?> saveFile(File src, Directory dir, String fileName) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final ext = src.path.split('.').last;
    final dest = File('${dir.path}/$fileName.$ext');
    await dest.writeAsBytes(await src.readAsBytes());
    return dest.path;
  } catch (_) {
    return null;
  }
}

/// Quick true/false check that the file exists and is non‑empty.
Future<bool> verifyFile(String path) async =>
    await File(path).exists() && (await File(path).length()) > 0;

Future<String?> clearFile(String? path) async {
  if (path == null) {
    print("[CLEAR FILE] Path is null, nothing to delete.");
    return null;
  }

  final f = File(path);
  print("file path to delete: $f");
  try {
    final exists = await f.exists();
    if (exists) {
      print("[CLEAR FILE] File exists at path: $path. Deleting now...");
      await f.delete();
      print("[CLEAR FILE] File deleted successfully.");
    } else {
      print(
          "[CLEAR FILE] File does not exist at path: $path. Nothing to delete.");
    }
  } catch (e, st) {
    print("[CLEAR FILE] Error deleting file at path: $path");
    print("Exception: $e");
    print("StackTrace: $st");
  }

  // 🔑 Always return null so caller can reset the variable
  return null;
}

/// Helper to clear a file and reset the variable
