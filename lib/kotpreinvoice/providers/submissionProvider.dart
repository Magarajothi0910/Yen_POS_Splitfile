import 'package:flutter/material.dart';

class SubmissionProviderDine extends ChangeNotifier {
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  void startSubmitting() {
    print("startSubmitting....");
    _isSubmitting = true;
    notifyListeners();
  }

  void stopSubmitting() {
    print("stopSubmitting....");

    _isSubmitting = false;
    notifyListeners();
  }
}
