import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yenposapp/Global/global_data_manager.dart';

class PhotoProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> get photos => _photos;
  //String? currentId;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true; // Mark as disposed when the provider is disposed
    super.dispose();
  }

  Uint8List? _selectedPhoto;
  Uint8List? get selectedPhoto => _selectedPhoto;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Map<String, Uint8List> _photoCache = {}; // Cache for preloaded images
  Map<String, Uint8List> get photoCache => _photoCache;

  // Fetch photos based on the customId and preload images
  Future<void> fetchPhotos(String customId) async {
    // if (customId == currentId) {
    //   return;
    // }
    //currentId = customId;
    if (_disposed) return;
    _isLoading = true;
    notifyListeners();

    final response = await http.get(
      Uri.parse("http://$ipAddress/imageOrder/media/$customId/photos"),
    );
    if (_disposed) return;

    if (response.statusCode == 200) {
      _photos =
          List<Map<String, dynamic>>.from(jsonDecode(response.body)['photos']);

      // Preload images
      for (var photo in _photos) {
        final photoId = photo['photo_id'];
        if (!_photoCache.containsKey(photoId)) {
          _photoCache[photoId] = await _fetchPhotoBytes(photoId);
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearPhotos() {
    _photos.clear();
    _photoCache.clear();
    _isLoading = false;
    notifyListeners();
  }

  // Fetch the photo bytes by photo_id
  Future<Uint8List> _fetchPhotoBytes(String photoId) async {
    final response = await http.get(
      Uri.parse("http://$ipAddress/imageOrder/media/photo/$photoId"),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes; // Return the binary data
    }
    throw Exception("Failed to load photo");
  }

  // Get a photo (from cache if available, otherwise fetch)
  Future<Uint8List?> fetchPhotoById(String photoId) async {
    if (_photoCache.containsKey(photoId)) {
      return _photoCache[photoId]; // Return cached image
    }

    try {
      final photoBytes = await _fetchPhotoBytes(photoId);
      _photoCache[photoId] = photoBytes; // Cache the fetched image
      return photoBytes;
    } catch (e) {
      return null; // Handle errors gracefully
    }
  }

  Future<bool> arePhotosAvailableForCustomId(String customId) async {
    _isLoading = true;
    notifyListeners();

    // Fetch photos based on customId
    final response = await http.get(
      Uri.parse("http://$ipAddress/imageOrder/media/$customId/photos"),
    );

    if (response.statusCode == 200) {
      final List<Map<String, dynamic>> photos =
          List<Map<String, dynamic>>.from(jsonDecode(response.body)['photos']);

      // Check if there is at least one photo
      if (photos.isNotEmpty) {
        // Iterate through each photo and preload its bytes into the cache
        for (var photo in photos) {
          final photoId = photo['photo_id'];
          if (!_photoCache.containsKey(photoId)) {
            // Fetch the photo and cache it if it's not already cached
            try {
              final photoBytes = await _fetchPhotoBytes(photoId);
              _photoCache[photoId] = photoBytes;
            } catch (e) {
              // Handle the case where the photo fails to load

              return false; // Return false if any photo fails to load
            }
          }
        }

        _isLoading = false;
        notifyListeners();
        return true; // Photos are available and cached
      } else {
        _isLoading = false;
        notifyListeners();
        return false; // No photos found
      }
    } else {
      _isLoading = false;
      notifyListeners();
      return false; // API request failed
    }
  }
}
