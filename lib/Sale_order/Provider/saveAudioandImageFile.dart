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
  if (!Platform.isAndroid) return true; // desktop & iOS: nothing to do

  // Legacy READ / WRITE for API 32 and below
  final legacy = await Permission.storage.request();

  // Granular permissions for API 33+
  final photos = await Permission.photos.request(); // READ_MEDIA_IMAGES
  final audio = await Permission.audio.request(); // READ_MEDIA_AUDIO

  return legacy.isGranted || photos.isGranted || audio.isGranted;
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
  if (!skipPermissionCheck && !await ensureStoragePermission()) return null;

  final downloads = await getDownloadsDirectory();
  if (downloads == null) return null;

  final dir = Directory('${downloads.path}/YenPOS/salesOrders/$saleOrderId');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Copies [src] into [dir] with [fileName] and original extension.
/// Returns the saved file’s absolute path, or `null` if something failed.
Future<String?> saveFile(File src, Directory dir, String fileName) async {
  try {
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
  if (path == null) return null;

  final f = File(path);
  try {
    if (await f.exists()) await f.delete();
  } catch (_) {}

  return null; // always reset variable
}
