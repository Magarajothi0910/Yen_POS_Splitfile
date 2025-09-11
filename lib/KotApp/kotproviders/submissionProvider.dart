import 'package:flutter/material.dart';

class SubmissionProvider extends ChangeNotifier {
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  void startSubmitting() {
    _isSubmitting = true;
    notifyListeners();
  }

  void stopSubmitting() {

    _isSubmitting = false;
    notifyListeners();
  }
}
