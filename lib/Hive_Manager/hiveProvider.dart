import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HiveProvider with ChangeNotifier {
  final Map<String, String> boxUrls;
  final Map<String, Box> boxes = {};
  final Map<String, Map<String, dynamic>?> data = {};
  final Map<String, bool> isLoading = {};
  final Map<String, String?> errorMessages = {};

  HiveProvider(this.boxUrls) {
    _initHive();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    for (var boxName in boxUrls.keys) {
      await _openBox(boxName); // ensures box is ready
    }
  }

  Future<void> _openBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      final openedBox = await Hive.openBox(boxName);
      boxes[boxName] = openedBox; // ✅ set first
      await fetchData(boxName); // ✅ fetch after it's really opened
    } else {
      boxes[boxName] = Hive.box(boxName); // ✅ make sure it's stored
      await fetchData(boxName);
    }
  }

  Future<void> fetchData(String boxName) async {

    isLoading[boxName] = true;
    notifyListeners();
    if (!boxes.containsKey(boxName)) {
      await _openBox(boxName);
    }

    final box = boxes[boxName];
    if (box == null) {
      errorMessages[boxName] = 'Box not found';
      isLoading[boxName] = false;
      notifyListeners();
      return;
    }


    final cachedData = box.get('data');
    if (cachedData != null) {
      data[boxName] = Map<String, dynamic>.from(cachedData);
      isLoading[boxName] = false;
      notifyListeners();
      return;
    }


    final url = boxUrls[boxName];
    if (url == null) {
      errorMessages[boxName] = 'URL not found';
      isLoading[boxName] = false;
      notifyListeners();
      return;
    }


    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        // 🧠 Custom decoding
        if (boxName == 'customerBox') {
          if (decodedResponse is List) {
            data[boxName] = {
              'items': decodedResponse.map((item) {
                return {
                  'customerId': item['customerId'],
                  'customerName': item['customerName'],
                  'customerPhoneNumber': item['customerPhoneNumber'],
                };
              }).toList()
            };
          }
        } else if (boxName == 'bankBox') {
          if (decodedResponse is Map<String, dynamic>) {
            data[boxName] = {
              'bankName': decodedResponse['bankName'],
              'accountNumber': decodedResponse['accountNumber'],
              'ifscCode': decodedResponse['ifscCode'],
            };
          } else if (decodedResponse is List) {
            data[boxName] = {
              'items': decodedResponse,
            };
          }
        } else {
          data[boxName] = decodedResponse is List
              ? {'items': decodedResponse}
              : Map<String, dynamic>.from(decodedResponse);
        }

        box.put('data', data[boxName]);

        errorMessages[boxName] = null;
      } else {
        errorMessages[boxName] = 'Failed to load data';
      }
    } catch (e) {
      errorMessages[boxName] = e.toString();
    } finally {
      isLoading[boxName] = false;
      notifyListeners();
    }
  }

  Future<void> clearData(String boxName) async {

    final box = boxes[boxName];
    if (box == null) {
      errorMessages[boxName] = 'Box not found';
      notifyListeners();
      return;
    }

    try {
      await box.clear();
      data[boxName] = null;
      errorMessages[boxName] = null;
      notifyListeners();
    } catch (e) {
      errorMessages[boxName] = 'Failed to clear data: $e';
      notifyListeners();
    }
  }

  Future<void> addData(String boxName, Map<String, dynamic> newData) async {
    final box = boxes[boxName];
    if (box == null) {
      errorMessages[boxName] = 'Box not found';
      return;
    }

    data[boxName] ??= {'items': []};

    if (data[boxName]!['items'] is List) {
      data[boxName]!['items'].add(newData);
    } else {
      data[boxName]!['items'] = [newData];
    }

    box.put('data', data[boxName]);
    notifyListeners();
  }
}

class ReusableBox extends StatelessWidget {
  final String boxName;

  const ReusableBox({Key? key, required this.boxName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<HiveProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading[boxName] ?? true) {
          return const CircularProgressIndicator();
        }

        if (provider.errorMessages[boxName] != null) {
          return Text('Error: ${provider.errorMessages[boxName]}');
        }


        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boxName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(provider.data[boxName]?.toString() ?? 'No Data Available'),
              ],
            ),
          ),
        );
      },
    );
  }
}
