import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  static final Box<Uint8List> _box = Hive.box<Uint8List>('itemImages');

  static String imageKey(String url) => url.hashCode.toString();

  static Future<void> cacheImage(String imageUrl) async {
    if (_box.containsKey(imageKey(imageUrl))) return;

    try {
      final res = await http.get(Uri.parse(imageUrl));
      if (res.statusCode == 200) {
        await _box.put(imageKey(imageUrl), res.bodyBytes);
      }
    } catch (_) {}
  }

  static Uint8List? getImage(String imageUrl) {
    return _box.get(imageKey(imageUrl));
  }
}
