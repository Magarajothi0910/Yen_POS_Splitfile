import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/regular_mode_page/provider/image_service.dart';

// class RegularModeProvider with ChangeNotifier {
//   List<Map<String, dynamic>> items = [];
//   List<Map<String, dynamic>> originalItems = [];
//   List<Map<String, dynamic>> filteredItems = [];
//   List<String> filteredVarianceNames = [];
//   TextEditingController searchController = TextEditingController();

//   List<String> categories = ['Favorite', 'Mixed', 'Savouries'];
//   bool isLoading = true;
//   String searchQuery = '';
//   String selectedCategory = 'Savouries';
//   bool showCustomKeyboard = false;
//   final ScrollController _scrollController = ScrollController();

//   bool isFavoriteSelected = false;
//   bool isMixedSelected = false;
//   List<Map<String, dynamic>> favoriteItems = [];
//   bool showMoreButton = false;

//   String? selectedVariance;

//   RegularModeProvider() {
//     loadData();
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void setSelectedVariance(String? newValue) {
//     selectedVariance = newValue;
//     notifyListeners();
//   }

//   void setFavorite(bool value) {
//     isFavoriteSelected = value;
//     isMixedSelected = false;
//     if (value) {
//       favoriteItems = originalItems.take(25).toList();
//       showMoreButton = originalItems.length > 25;
//       items = favoriteItems;
//     } else {
//       items = List.from(originalItems);
//     }
//     notifyListeners();
//   }

//   void showMoreItems() {
//     if (isFavoriteSelected) {
//       favoriteItems = originalItems;
//       showMoreButton = false;
//       items = favoriteItems;
//       notifyListeners();
//     }
//   }

//   void setMixed(bool value) {
//     isMixedSelected = value;
//     isFavoriteSelected = false;
//     if (value) {
//       items = originalItems;
//     } else {
//       items = List.from(originalItems);
//     }
//     notifyListeners();
//   }

//   void clearVarianceSearch() {
//     filteredVarianceNames = [];
//     notifyListeners();
//   }

//   Map<String, dynamic>? _selectedEmployee;

//   Map<String, dynamic>? get selectedEmployee => _selectedEmployee;

//   void selectEmployee(Map<String, dynamic> employee) {
//     if (_selectedEmployee != employee) {
//       _selectedEmployee = employee;
//       notifyListeners();
//     }
//   }

//   void clear() {
//     _selectedEmployee = null;
//     notifyListeners();
//   }

//   String get displayName {
//     if (_selectedEmployee == null) return '';
//     final firstName = _selectedEmployee!['firstName'] ?? '';
//     final empNo = _selectedEmployee!['employeeNumber'] ?? '';
//     return '$empNo - $firstName';
//   }

//   Future<void> loadData() async {
//     final globalData = GlobalDataManager().branchwiseItems;
//     final data = globalData['data'];

//     if (data is Map) {
//       items = data.entries
//           .map((entry) {
//             final itemKey = entry.key;
//             final itemEntry = entry.value;

//             if (itemEntry is Map) {
//               final item = (itemEntry['item'] ?? {}) as Map;
//               final variances = (itemEntry['variance'] ?? {}) as Map;

//               List<Map<String, dynamic>> variancesList = variances.entries.map((
//                 v,
//               ) {
//                 final varianceKey = v.key;
//                 final variance = (v.value ?? {}) as Map;

//                 final branchwise = (variance['branchwise'] ?? {}) as Map;

//                 // Extract TakeAway price safely
//                 double takeawayPrice = 0.0;
//                 try {
//                   // Your data structure has orderType inside branchwise → branchCode
//                   if (branchwise.isNotEmpty) {
//                     final firstBranch = branchwise.values.firstWhere(
//                       (b) => b is Map && b.containsKey('orderType'),
//                       orElse: () => {},
//                     );

//                     if (firstBranch is Map) {
//                       final orderTypeMap =
//                           (firstBranch['orderType'] ?? {}) as Map;
//                       final rawPrice =
//                           orderTypeMap['orderType_${aliasname}_takeAway'];
//                       if (rawPrice is num) {
//                         takeawayPrice = rawPrice.toDouble();
//                       } else if (rawPrice is String &&
//                           rawPrice.trim().isNotEmpty) {
//                         takeawayPrice = double.tryParse(rawPrice) ?? 0.0;
//                       }
//                     }
//                   }
//                 } catch (e) {}

//                 return {
//                   'varianceName': (variance['varianceName'] ?? "").toString(),
//                   'varianceDefaultPrice': () {
//                     final rawPrice = variance['variance_Defaultprice'];
//                     if (rawPrice is num) {
//                       return rawPrice.toDouble();
//                     } else if (rawPrice is String &&
//                         rawPrice.trim().isNotEmpty) {
//                       return double.tryParse(rawPrice) ?? 0.0;
//                     }
//                     return 0.0;
//                   }(),
//                   'varianceUOM': (variance['variance_Uom'] ?? "").toString(),
//                   'takeawayPrice': takeawayPrice,
//                   'branchwise': branchwise,
//                 };
//               }).toList();

//               return {
//                 'name': (item['itemName'] ?? "").toString(),
//                 'category': (item['category'] ?? "").toString(),
//                 'imagePath': '',
//                 'variances': variancesList,
//               };
//             }
//             return null;
//           })
//           .where((item) => item != null)
//           .cast<Map<String, dynamic>>()
//           .toList();

//       originalItems = List.from(items);

//       // Avoid cast error by converting each to string manually
//       categories =
//           (globalData['categories'] as List?)
//               ?.map((c) => (c ?? "").toString())
//               .toList() ??
//           [];

//       isLoading = false;
//       notifyListeners();

//       if (categories.contains(selectedCategory)) {
//         filterItemsByCategory(selectedCategory);
//       }
//     } else {
//       items = [];
//       categories = [];
//       isLoading = false;
//       notifyListeners();
//     }
//   }

//   void filterItemsByCategory(String category) {
//     if (category == 'Favorite') {
//       setFavorite(true);
//     } else if (category == 'Mixed') {
//       setMixed(true);
//     } else {
//       isFavoriteSelected = false;
//       isMixedSelected = false;
//       selectedCategory = category;
//       items = originalItems
//           .where((item) => (item['category'] ?? "").toString() == category)
//           .toList();
//     }
//     notifyListeners();
//   }

//   void updateItemsForSelectedCategory() {
//     categories = ['Cake Making', 'Cake Icing'];
//     if (!categories.contains(selectedCategory)) {
//       selectedCategory = 'Cake Making';
//     }
//     isFavoriteSelected = false;
//     isMixedSelected = false;
//     items = originalItems
//         .where(
//           (item) => (item['category'] ?? "").toString() == selectedCategory,
//         )
//         .toList();
//     notifyListeners();
//   }

//   String getUOMForVariance(String varianceName) {
//     for (var item in originalItems) {
//       for (var variance in item['variances'] ?? []) {
//         if ((variance['varianceName'] ?? "").toString() == varianceName) {
//           String uom = (variance['varianceUOM'] ?? "N/A").toString();
//           return uom;
//         }
//       }
//     }
//     return 'N/A';
//   }

//   Map<String, dynamic> getItemDataForVariance(String varianceName) {
//     return originalItems.firstWhere(
//       (item) => (item['variances'] ?? []).any(
//         (variance) =>
//             (variance['varianceName'] ?? "").toString() == varianceName,
//       ),
//       orElse: () {
//         return {};
//       },
//     );
//   }

//   Map<String, dynamic> getVarianceDetails(String varianceName) {
//     return originalItems
//         .expand((item) => item['variances'] ?? [])
//         .firstWhere(
//           (variance) =>
//               (variance['varianceName'] ?? "").toString() == varianceName,
//           orElse: () {
//             return {};
//           },
//         );
//   }

//   void filterItemsBySearchQuery(String query) {
//     searchQuery = query;
//     if (query.isEmpty) {
//       if (selectedCategory.isNotEmpty) {
//         items = originalItems
//             .where(
//               (item) => (item['category'] ?? "").toString() == selectedCategory,
//             )
//             .toList();
//       } else {
//         items = List.from(originalItems);
//       }
//     } else {
//       items = originalItems
//           .where(
//             (item) => (item['name'] ?? "").toString().toLowerCase().contains(
//               query.toLowerCase(),
//             ),
//           )
//           .toList();
//     }
//     notifyListeners();
//   }

//   void changeCategory(int delta) {
//     int currentIndex = categories.indexOf(selectedCategory);
//     int newIndex = (currentIndex + delta) % categories.length;
//     if (newIndex < 0) {
//       newIndex = categories.length - 1;
//     }
//     selectedCategory = categories[newIndex];
//     filterItemsByCategory(selectedCategory);

//     _scrollController.animateTo(
//       (newIndex * 100.0),
//       duration: const Duration(milliseconds: 300),
//       curve: Curves.easeInOut,
//     );
//   }

//   void onTextInput(String input) {
//     searchQuery += input;
//     filterItemsBySearchQuery(searchQuery);
//   }

//   void onBackspace() {
//     if (searchQuery.isNotEmpty) {
//       searchQuery = searchQuery.substring(0, searchQuery.length - 1);
//       filterItemsBySearchQuery(searchQuery);
//     }
//   }

//   void setShowCustomKeyboard(bool value) {
//     showCustomKeyboard = value;
//     notifyListeners();
//   }

//   void filterItemsByVarianceName(String query) {
//     if (query.isEmpty) {
//       filteredItems = List.from(originalItems);
//     } else {
//       filteredItems = originalItems.where((item) {
//         return (item['variances'] ?? []).any(
//           (variance) => (variance['varianceName'] ?? "")
//               .toString()
//               .toLowerCase()
//               .contains(query.toLowerCase()),
//         );
//       }).toList();
//     }
//     notifyListeners();
//   }

//   void updateFilteredVarianceNames() {
//     Set<String> varianceNamesSet = {};
//     for (var item in originalItems) {
//       for (var variance in item['variances'] ?? []) {
//         varianceNamesSet.add((variance['varianceName'] ?? "").toString());
//       }
//     }
//     filteredVarianceNames = varianceNamesSet.toList();
//     notifyListeners();
//   }

//   void filterVarianceNamesBySearchQuery(String query) {
//     final cleanQuery = query.trim().replaceAll(' ', '').toLowerCase();

//     if (cleanQuery.isEmpty) {
//       updateFilteredVarianceNames();
//     } else {
//       filteredVarianceNames = originalItems
//           .expand((item) => item['variances'] ?? [])
//           .where((variance) {
//             final varianceName = (variance['varianceName'] ?? "")
//                 .toString()
//                 .trim()
//                 .replaceAll(' ', '')
//                 .toLowerCase();
//             return varianceName.contains(cleanQuery);
//           })
//           .map((variance) => (variance['varianceName'] ?? "").toString())
//           .toSet()
//           .toList();

//       notifyListeners();
//     }
//   }

//   ScrollController get scrollController => _scrollController;

//   void changeCategoryOrOption(int i) {}
// }

class RegularModeProvider with ChangeNotifier {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> originalItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  List<String> filteredVarianceNames = [];
  TextEditingController searchController = TextEditingController();

  //List<String> categories = ['Favorite', 'Mixed', 'Savouries'];
  List<String> categories = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedCategory = 'Savouries';
  bool showCustomKeyboard = false;
  final ScrollController _scrollController = ScrollController();

  bool isFavoriteSelected = false;
  bool isMixedSelected = false;
  List<Map<String, dynamic>> favoriteItems = [];
  bool showMoreButton = false;

  String? selectedVariance;

  RegularModeProvider() {
    loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void setSelectedVariance(String? newValue) {
    selectedVariance = newValue;
    notifyListeners();
  }

  void setFavorite(bool value) {
    isFavoriteSelected = value;
    isMixedSelected = false;
    if (value) {
      favoriteItems = originalItems.take(25).toList();
      items = favoriteItems;
    } else {
      items = List.from(originalItems);
    }
    notifyListeners();
  }

  void showMoreItems() {
    if (isFavoriteSelected) {
      favoriteItems = originalItems;
      items = favoriteItems;
      notifyListeners();
    }
  }

  void setMixed(bool value) {
    isMixedSelected = value;
    isFavoriteSelected = false;
    items = value ? originalItems : List.from(originalItems);
    notifyListeners();
  }

  void clearVarianceSearch() {
    filteredVarianceNames = [];
    notifyListeners();
  }

  Map<String, dynamic>? _selectedEmployee;

  Map<String, dynamic>? get selectedEmployee => _selectedEmployee;

  void selectEmployee(Map<String, dynamic> employee) {
    if (_selectedEmployee != employee) {
      _selectedEmployee = employee;
      notifyListeners();
    }
  }

  void clear() {
    _selectedEmployee = null;
    notifyListeners();
  }

  String get displayName {
    if (_selectedEmployee == null) return '';
    final firstName = _selectedEmployee!['firstName'] ?? '';
    final empNo = _selectedEmployee!['employeeNumber'] ?? '';
    return '$empNo - $firstName';
  }

  Future<void> loadData() async {
    // final globalData = GlobalDataManager().branchwiseItems;
    final lazyBox = await Hive.openBox('items');
    final globalData = await lazyBox.get('branchwiseItems_$aliasname');

    final data = globalData['data'];
    if (data is Map) {
      // Your original parsing logic (unchanged)
      items = data.entries
          .map((entry) {
            final itemEntry = entry.value;
            if (itemEntry is Map) {
              final item = (itemEntry['item'] ?? {}) as Map;
              final variances = (itemEntry['variance'] ?? {}) as Map;
              List<Map<String, dynamic>> variancesList = variances.entries.map((
                v,
              ) {
                final variance = (v.value ?? {}) as Map;
                final branchwise = (variance['branchwise'] ?? {}) as Map;
                double takeawayPrice = 0.0;
                try {
                  if (branchwise.isNotEmpty) {
                    final firstBranch = branchwise.values.firstWhere(
                      (b) => b is Map && b.containsKey('orderType'),
                      orElse: () => {},
                    );
                    if (firstBranch is Map) {
                      final orderTypeMap =
                          (firstBranch['orderType'] ?? {}) as Map;
                      final rawPrice =
                          orderTypeMap['orderType_${aliasname}_takeAway'];
                      if (rawPrice is num) {
                        takeawayPrice = rawPrice.toDouble();
                      } else if (rawPrice is String &&
                          rawPrice.trim().isNotEmpty) {
                        takeawayPrice = double.tryParse(rawPrice) ?? 0.0;
                      }
                    }
                  }
                } catch (e) {}
                return {
                  'varianceName': (variance['varianceName'] ?? "").toString(),
                  'varianceDefaultPrice': () {
                    final rawPrice = variance['variance_Defaultprice'];
                    if (rawPrice is num) return rawPrice.toDouble();
                    if (rawPrice is String && rawPrice.trim().isNotEmpty) {
                      return double.tryParse(rawPrice) ?? 0.0;
                    }
                    return 0.0;
                  }(),
                  'varianceUOM': (variance['variance_Uom'] ?? "").toString(),
                  'takeawayPrice': takeawayPrice,
                  'branchwise': branchwise,
                };
              }).toList();
              final imageUrl = (item['itemImage'] ?? "").toString();

              if (imageUrl.isNotEmpty) {
                ImageCacheService.cacheImage(imageUrl); // 🔥 cache image
              }

              return {
                'name': (item['itemName'] ?? "").toString(),
                'category': (item['category'] ?? "").toString(),
                'imagePath': imageUrl,
                'variances': variancesList,
              };
            }
            return null;
          })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();

      originalItems = List.from(items);

      // FIXED: Extract unique categories from actual items
      Set<String> uniqueCats = {};
      for (var item in originalItems) {
        String cat = (item['category'] ?? '').toString().trim();
        if (cat.isNotEmpty) uniqueCats.add(cat);
      }
      categories = uniqueCats.toList()..sort();

      isLoading = false;
      notifyListeners();

      if (categories.isNotEmpty && !categories.contains(selectedCategory)) {
        selectedCategory = categories.first;
      }
      filterItemsByCategory(selectedCategory);
    } else {
      items = [];
      categories = [];
      isLoading = false;
      notifyListeners();
    }
  }

  void filterItemsByCategory(String category) {
    if (category == 'Favorite') {
      setFavorite(true);
      return;
    }
    if (category == 'Mixed') {
      setMixed(true);
      return;
    }

    isFavoriteSelected = false;
    isMixedSelected = false;
    selectedCategory = category;

    items = originalItems
        .where((item) => (item['category'] ?? "").toString() == category)
        .toList();

    notifyListeners();
  }

  void updateItemsForSelectedCategory() {
    categories = ['Cake Making', 'Cake Icing'];
    if (!categories.contains(selectedCategory)) {
      selectedCategory = 'Cake Making';
    }
    isFavoriteSelected = false;
    isMixedSelected = false;
    items = originalItems
        .where(
          (item) => (item['category'] ?? "").toString() == selectedCategory,
        )
        .toList();
    notifyListeners();
  }

  String getUOMForVariance(String varianceName) {
    for (var item in originalItems) {
      for (var variance in item['variances'] ?? []) {
        if ((variance['varianceName'] ?? "").toString() == varianceName) {
          String uom = (variance['varianceUOM'] ?? "N/A").toString();
          return uom;
        }
      }
    }
    return 'N/A';
  }

  Map<String, dynamic> getItemDataForVariance(String varianceName) {
    return originalItems.firstWhere(
      (item) => (item['variances'] ?? []).any(
        (variance) =>
            (variance['varianceName'] ?? "").toString() == varianceName,
      ),
      orElse: () {
        return {};
      },
    );
  }

  Map<String, dynamic> getVarianceDetails(String varianceName) {
    return originalItems
        .expand((item) => item['variances'] ?? [])
        .firstWhere(
          (variance) =>
              (variance['varianceName'] ?? "").toString() == varianceName,
          orElse: () {
            return {};
          },
        );
  }

  void filterItemsBySearchQuery(String query) {
    searchQuery = query;
    if (query.isEmpty) {
      if (selectedCategory.isNotEmpty) {
        items = originalItems
            .where(
              (item) => (item['category'] ?? "").toString() == selectedCategory,
            )
            .toList();
      } else {
        items = List.from(originalItems);
      }
    } else {
      items = originalItems
          .where(
            (item) => (item['name'] ?? "").toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  void changeCategory(int delta) {
    int currentIndex = categories.indexOf(selectedCategory);
    int newIndex = (currentIndex + delta) % categories.length;
    if (newIndex < 0) {
      newIndex = categories.length - 1;
    }
    selectedCategory = categories[newIndex];
    filterItemsByCategory(selectedCategory);

    _scrollController.animateTo(
      (newIndex * 100.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void onTextInput(String input) {
    searchQuery += input;
    filterItemsBySearchQuery(searchQuery);
  }

  void onBackspace() {
    if (searchQuery.isNotEmpty) {
      searchQuery = searchQuery.substring(0, searchQuery.length - 1);
      filterItemsBySearchQuery(searchQuery);
    }
  }

  void setShowCustomKeyboard(bool value) {
    showCustomKeyboard = value;
    notifyListeners();
  }

  void filterItemsByVarianceName(String query) {
    if (query.isEmpty) {
      filteredItems = List.from(originalItems);
    } else {
      filteredItems = originalItems.where((item) {
        return (item['variances'] ?? []).any(
          (variance) => (variance['varianceName'] ?? "")
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()),
        );
      }).toList();
    }
    notifyListeners();
  }

  void updateFilteredVarianceNames() {
    Set<String> varianceNamesSet = {};
    for (var item in originalItems) {
      for (var variance in item['variances'] ?? []) {
        varianceNamesSet.add((variance['varianceName'] ?? "").toString());
      }
    }
    filteredVarianceNames = varianceNamesSet.toList();
    notifyListeners();
  }

  void filterVarianceNamesBySearchQuery(String query) {
    final cleanQuery = query.trim().replaceAll(' ', '').toLowerCase();

    if (cleanQuery.isEmpty) {
      updateFilteredVarianceNames();
    } else {
      filteredVarianceNames = originalItems
          .expand((item) => item['variances'] ?? [])
          .where((variance) {
            final varianceName = (variance['varianceName'] ?? "")
                .toString()
                .trim()
                .replaceAll(' ', '')
                .toLowerCase();
            return varianceName.contains(cleanQuery);
          })
          .map((variance) => (variance['varianceName'] ?? "").toString())
          .toSet()
          .toList();

      notifyListeners();
    }
  }

  ScrollController get scrollController => _scrollController;

  void changeCategoryOrOption(int i) {}
}
