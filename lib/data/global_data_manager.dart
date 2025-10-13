class GlobalDataManager {
  static final GlobalDataManager _instance = GlobalDataManager._internal();

  factory GlobalDataManager() {
    return _instance;
  }

  GlobalDataManager._internal();

  dynamic _branchwiseItems;
  dynamic _salesorders;

  dynamic _branches;
  dynamic _billReceiptSettings;
  dynamic _mixboxData; // Add this field for mixbox data

  // Getter and setter for branchwiseItems
  dynamic get branchwiseItems => _branchwiseItems;

  set branchwiseItems(dynamic value) {
    _branchwiseItems = value;
  }

  // Getter and setter for branchwiseItems
  dynamic get salesorders => _salesorders;

  set salesorders(dynamic value) {
    _salesorders = value;
  }

  // Getter and setter for branches
  dynamic get branches => _branches;

  set branches(dynamic value) {
    _branches = value;
  }

  // Getter and setter for billReceiptSettings
  dynamic get billReceiptSettings => _billReceiptSettings;

  set billReceiptSettings(dynamic value) {
    _billReceiptSettings = value;
  }

  // Getter and setter for mixboxData
  dynamic get mixboxData => _mixboxData;

  set mixboxData(dynamic value) {
    _mixboxData = value;
  }
}

String ipAddress = '';
