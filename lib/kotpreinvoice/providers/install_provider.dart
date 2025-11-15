import 'package:flutter/material.dart';

class InstallProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isConfirming = false;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isConfirming => _isConfirming;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void setConfirming(bool value) {
    _isConfirming = value;
    notifyListeners();
  }

  void resetStates() {
    _isLoading = false;
    _isSubmitting = false;
    _isConfirming = false;
    notifyListeners();
  }
}
