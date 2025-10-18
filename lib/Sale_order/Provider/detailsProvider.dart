import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;


class DetailsProvider extends ChangeNotifier {
  DetailsProvider() {
    fetchVariances();
    fetchEmployeeNames();
  }
  String? _selectedVariance;

  String _others = '';

  String? address;
  String? landmark;
  String _searchQuery = '';

  String? selectedFirstName;

  List<Map<String, dynamic>> _variances = [];
  final List<String> _employeeFirstNames = []; // Declare this in your class
  // Getters

  String? get selectedVariance => _selectedVariance;

  String get others => _others;

  List<String> get employeeFirstNames => _employeeFirstNames;
  List<String> get employeeNames => _employeeNames;

  List<Map<String, dynamic>> get variances => _variances;

  String _searchText = "";

  String get searchText => _searchText;

  void updateSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  void clearSearchText() {
    _searchText = "";
    notifyListeners();
  }

  // List<String> filteredItems = [];
  Future<void> fetchVariances() async {
    final url = 'https://yenerp.com/fastapi/branchwiseitems/';
    print("Fetching variances from $url");
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        // Ensure responseBody is a valid Map
        if (responseBody != null && responseBody is Map<String, dynamic>) {
          List<Map<String, dynamic>> fetchedVariances = [];

          // Parse each item in data
          (responseBody['data'] as Map<String, dynamic>)
              .forEach((itemKey, itemValue) {
            final item = itemValue['item'] ?? {};
            final variances = itemValue['variance'] ?? {};

            final itemTax = item['tax'] ?? 0;
            final category = item['category'] ?? '';

            // Parse each variance under the item
            (variances as Map<String, dynamic>)
                .forEach((varianceKey, varianceValue) {
              final branches = varianceValue['branchwise'] ?? {};

              fetchedVariances.add({
                'itemName': item['itemName'] ?? 'Unknown Item',
                'category': category,
                'variancetax': itemTax,
                'varianceName':
                    varianceValue['varianceName'] ?? 'Unknown Variance',
                'variancePrice': varianceValue['variance_Defaultprice'] ?? 0,
                'varianceUom': varianceValue['variance_Uom'] ?? '',
                'varianceitemCode': varianceValue['varianceitemCode'] ?? '',
                'branches': branches
              });
            });
          });

          // Assign fetched variances to the state
          _variances = fetchedVariances;

          notifyListeners();
        } else {
          debugPrint(
              "Error: Response body is null or not a valid JSON object.");
        }
      } else {
        debugPrint(
            'Failed to load variances. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching variances: $e');
    }
  }

  List<Map<String, dynamic>> get filteredItems1 => _filteredItems;

  // List<Map<String, dynamic>> _allItems = []; // Full list of items
  List<Map<String, dynamic>> _filteredItems = [];

  // void filterItemsByQuery(String query) {
  //   if (query.isEmpty) {
  //     _filteredItems = _variances; // Show all items if the query is empty
  //   } else {
  //     _filteredItems = _variances
  //         .where((item) => (item['varianceName'] ?? '')
  //             .toLowerCase()
  //             .contains(query.toLowerCase()))
  //         .toList();
  //   }
  //   notifyListeners(); // Notify listeners about the update
  // }

  void filterItemsByQuery(String query) {
    if (query.isEmpty) {
      _filteredItems = _variances; // Show all items if the query is empty
    } else {
      final exactMatches = _variances.where((item) =>
          (item['varianceName'] ?? '').toLowerCase() == query.toLowerCase());
      final partialMatches = _variances.where((item) =>
          (item['varianceName'] ?? '')
              .toLowerCase()
              .contains(query.toLowerCase()) &&
          (item['varianceName'] ?? '').toLowerCase() != query.toLowerCase());

      // Combine exact matches first, followed by partial matches
      _filteredItems = [
        ...exactMatches,
        ...partialMatches,
      ];
    }
    notifyListeners(); // Notify listeners about the update
  }

  List<String> _employeeNames = [];
  List<String> _filteredEmployeeFirstNames = []; // To hold filtered names
  bool _isLoading = false;

  List<String> get filteredEmployeeFirstNames => _filteredEmployeeFirstNames;
  bool get isLoading => _isLoading;

  Future<void> fetchEmployeeNames() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = await Hive.openBox('employeeBox'); // Open the employeeBox
      final cachedData = box.get('employees'); // Get the cached data
      // Check the data type

      if (cachedData != null && cachedData is List<dynamic>) {
        _employeeNames = cachedData
            .map((employee) => employee['firstName']?.toString() ?? 'Unknown')
            .toList();
        _filteredEmployeeFirstNames =
            List<String>.from(_employeeNames); // Cloning the list
      } else {
        throw Exception('No employee names found in Hive');
      }
    } catch (e) {
      throw Exception('Error loading employee names from Hive: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update the search query and filter employee names
  set searchQuery(String value) {
    _searchQuery = value;
    _filteredEmployeeFirstNames = _employeeNames
        .where(
            (name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    notifyListeners();
  }

  String get searchQuery => _searchQuery;

  void setAddress(String? value) {
    address = value;
    notifyListeners();
  }

  void setLandmark(String? value) {
    landmark = value;
    notifyListeners();
  }

  // Select a variance
  void selectVariance(String variance) {
    _selectedVariance = variance;
    notifyListeners();
  }

  void setOthers(String value) {
    _others = value;
    notifyListeners();
  }

  // Save the current bill details (Location, Driver, Vehicle, Employee, Variance)
  void saveBillDetails() {
    // Logic to save the selected details

    // Add your custom save logic here
  }
}
