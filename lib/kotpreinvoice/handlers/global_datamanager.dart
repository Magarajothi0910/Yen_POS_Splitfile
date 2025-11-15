class GlobalDataManager {
  static final GlobalDataManager _instance = GlobalDataManager._internal();

  factory GlobalDataManager() {
    return _instance;
  }

  GlobalDataManager._internal();

  dynamic _branchwiseItems;
  dynamic _branches;

  // Getter and setter for branchwiseItems
  dynamic get branchwiseItems => _branchwiseItems;

  set branchwiseItems(dynamic value) {
    _branchwiseItems = value;
  } // Getter and setter for branches

  dynamic get branches => _branches;

  set branches(dynamic value) {
    _branches = value;
  }
}
