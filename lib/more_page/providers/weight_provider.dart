import 'package:flutter/material.dart';

import '../model/weight_model.dart';

class WeightProvider with ChangeNotifier {
  final List<Weight> _weights = [
    Weight(label: 'W1', value: 800),
    Weight(label: 'W2', value: 400),
  ];

  Weight? _selectedWeight;

  List<Weight> get weights => _weights;

  Weight? get selectedWeight => _selectedWeight;

  void setSelectedWeight(Weight weight) {
    _selectedWeight = weight;
    notifyListeners();
  }
}
