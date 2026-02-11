import 'package:flutter/material.dart';

class FavoriteProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _favoriteItems = [];

  List<Map<String, dynamic>> get favoriteItems => _favoriteItems;

  bool isFavorite(Map<String, dynamic> item) {
    return _favoriteItems
        .any((favoriteItem) => favoriteItem['name'] == item['name']);
  }

  void toggleFavorite(Map<String, dynamic> item) {
    if (isFavorite(item)) {
      _favoriteItems
          .removeWhere((favoriteItem) => favoriteItem['name'] == item['name']);
    } else {
      _favoriteItems.add(item);
    }
    notifyListeners();
  }
}
