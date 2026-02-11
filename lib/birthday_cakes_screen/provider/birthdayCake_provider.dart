import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/birthday_cakes_screen/models/birthdayCake_model.dart';

class BirthdayCakesProvider with ChangeNotifier {
  List<BirthDayCake> cakes = [];
  bool _isLoading = false;
  bool _isQrMode = false;
  bool _isCameraMode = false; // Added for camera mode
  bool _isTextFieldFocused = false;
  Offset _keyboardPosition = const Offset(50, 200);

  bool _showExpiry = false; // <-- NEW
  bool get showExpiry => _showExpiry;
  void toggleDateView() {
    _showExpiry = !_showExpiry;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isQrMode => _isQrMode;
  bool get isCameraMode => _isCameraMode; // Getter for camera mode
  bool get isTextFieldFocused => _isTextFieldFocused;
  Offset get keyboardPosition => _keyboardPosition;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<void> fetchCakes() async {
    print('Fetching cakes...');
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get(
        "https://yenerp.com/fastapi/birthdaycakes/cakes/by-branch/?branchName=$branchName&status=Recieved",
      );
      debugPrint("branchName:$branchName");
      print(
        'API response status: ${response.statusCode}, data: ${response.data}',
      );

      if (response.statusCode == 200) {
        if (response.data is List) {
          cakes = (response.data as List)
              .map((item) => BirthDayCake.fromJson(item))
              .toList();
          print('Parsed ${cakes.length} cakes');
        } else {
          throw Exception(
            "Unexpected response type: ${response.data.runtimeType}",
          );
        }
      } else {
        throw Exception("Failed to fetch cakes: ${response.statusCode}");
      }
    } on DioException catch (e) {
      print('Dio error: ${e.message}, response: ${e.response?.data}');
      throw Exception("Dio error: ${e.message}");
    } catch (e) {
      print('Unknown error: $e');
      throw Exception("Unknown error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void removeCakeById(String cakeId) {
    print('Removing cake with ID: $cakeId');
    cakes.removeWhere((cake) => cake.cakeId.toString() == cakeId);
    notifyListeners();
  }

  BirthDayCake? getCakeById(String cakeId) {
    try {
      final cake = cakes.firstWhere((cake) => cake.cakeId.toString() == cakeId);
      print('Found cake with ID: $cakeId');
      return cake;
    } catch (e) {
      print('Cake with ID $cakeId not found');
      return null;
    }
  }

  void toggleQrMode() {
    _isQrMode = !_isQrMode;
    _isCameraMode = false; // Ensure camera mode is off when toggling QR
    print('Toggled QR mode: $_isQrMode');
    if (_isQrMode) {
      _isTextFieldFocused = false;
      print('Set _isTextFieldFocused to false in QR mode');
    }
    notifyListeners();
  }

  void toggleCameraMode() {
    _isCameraMode = !_isCameraMode;
    _isQrMode = false; // Ensure QR mode is off when toggling camera
    print('Toggled Camera mode: $_isCameraMode');
    if (_isCameraMode) {
      _isTextFieldFocused = false;
      print('Set _isTextFieldFocused to false in Camera mode');
    }
    notifyListeners();
  }

  void setQrMode(bool value) {
    _isQrMode = value;
    notifyListeners();
  }

  void setCameraMode(bool value) {
    _isCameraMode = value;
    notifyListeners();
  }

  void setTextFieldFocused(bool focused) {
    _isTextFieldFocused = focused;
    print('_isTextFieldFocused updated to: $_isTextFieldFocused');
    notifyListeners();
  }

  void updateKeyboardPosition(Offset newPosition, Size screenSize) {
    const keyboardWidth = 300.0;
    const keyboardHeight = 200.0;
    _keyboardPosition = Offset(
      newPosition.dx.clamp(0.0, screenSize.width - keyboardWidth),
      newPosition.dy.clamp(0.0, screenSize.height - keyboardHeight),
    );
    print('Keyboard position updated to: $_keyboardPosition');
    notifyListeners();
  }
}
