// import 'package:flutter/material.dart';

// class SalesInvoiceState with ChangeNotifier {
//   String _selectedPaymentOption = '';
//   String _selectedPaymentOptionValue = '';
//   double _balanceAmount = 0.0;
//   double _cashAmount = 0.0;
//   double _cardAmount = 0.0;
//   double _upiAmount = 0.0;
//   String? _selectedEmployeeFirstName;
//   double _roundedDiscountAmount = 0.0;
//   String _invoiceNumber = '';
//   bool _isPrintButtonEnabled = false;
//   DateTime? _selectedBirthday;
//   bool _isUpiPaid = false;
//   bool _isCardPaid = false;

//   // Getters
//   String get selectedPaymentOption => _selectedPaymentOption;
//   String get selectedPaymentOptionValue => _selectedPaymentOptionValue;
//   double get balanceAmount => _balanceAmount;
//   double get cashAmount => _cashAmount;
//   double get cardAmount => _cardAmount;
//   double get upiAmount => _upiAmount;
//   String? get selectedEmployeeFirstName => _selectedEmployeeFirstName;
//   double get roundedDiscountAmount => _roundedDiscountAmount;
//   String get invoiceNumber => _invoiceNumber;
//   bool get isPrintButtonEnabled => _isPrintButtonEnabled;
//   DateTime? get selectedBirthday => _selectedBirthday;
//   bool get isUpiPaid => _isUpiPaid;
//   bool get isCardPaid => _isCardPaid;

//   // Setters
//   void updateSelectedPaymentOption(String value) {
//     _selectedPaymentOption = value;
//     notifyListeners();
//   }

//   void updateSelectedPaymentOptionValue(String value) {
//     _selectedPaymentOptionValue = value;
//     notifyListeners();
//   }

//   void updateBalanceAmount(double value) {
//     _balanceAmount = value;
//     notifyListeners();
//   }

//   void updateCashAmount(double value) {
//     _cashAmount = value;
//     notifyListeners();
//   }

//   void updateCardAmount(double value) {
//     _cardAmount = value;
//     notifyListeners();
//   }

//   void updateUpiAmount(double value) {
//     _upiAmount = value;
//     notifyListeners();
//   }

//   void updateSelectedEmployeeFirstName(String? value) {
//     _selectedEmployeeFirstName = value;
//     notifyListeners();
//   }

//   void updateRoundedDiscountAmount(double value) {
//     _roundedDiscountAmount = value;
//     notifyListeners();
//   }

//   void updateInvoiceNumber(String value) {
//     _invoiceNumber = value;
//     notifyListeners();
//   }

//   void updateIsPrintButtonEnabled(bool value) {
//     _isPrintButtonEnabled = value;
//     notifyListeners();
//   }

//   void updateSelectedBirthday(DateTime? value) {
//     _selectedBirthday = value;
//     notifyListeners();
//   }

//   void updateIsUpiPaid(bool value) {
//     _isUpiPaid = value;
//     notifyListeners();
//   }

//   void updateIsCardPaid(bool value) {
//     _isCardPaid = value;
//     notifyListeners();
//   }

//   // Method to update multiple state variables at once
//   void updateMultiple({
//     String? selectedPaymentOption,
//     String? selectedPaymentOptionValue,
//     double? balanceAmount,
//     double? cashAmount,
//     double? cardAmount,
//     double? upiAmount,
//     String? selectedEmployeeFirstName,
//     double? roundedDiscountAmount,
//     String? invoiceNumber,
//     bool? isPrintButtonEnabled,
//     DateTime? selectedBirthday,
//     bool? isUpiPaid,
//     bool? isCardPaid,
//   }) {
//     if (selectedPaymentOption != null) _selectedPaymentOption = selectedPaymentOption;
//     if (selectedPaymentOptionValue != null) _selectedPaymentOptionValue = selectedPaymentOptionValue;
//     if (balanceAmount != null) _balanceAmount = balanceAmount;
//     if (cashAmount != null) _cashAmount = cashAmount;
//     if (cardAmount != null) _cardAmount = cardAmount;
//     if (upiAmount != null) _upiAmount = upiAmount;
//     if (selectedEmployeeFirstName != null) _selectedEmployeeFirstName = selectedEmployeeFirstName;
//     if (roundedDiscountAmount != null) _roundedDiscountAmount = roundedDiscountAmount;
//     if (invoiceNumber != null) _invoiceNumber = invoiceNumber;
//     if (isPrintButtonEnabled != null) _isPrintButtonEnabled = isPrintButtonEnabled;
//     if (selectedBirthday != null) _selectedBirthday = selectedBirthday;
//     if (isUpiPaid != null) _isUpiPaid = isUpiPaid;
//     if (isCardPaid != null) _isCardPaid = isCardPaid;
//     notifyListeners();
//   }
// }

import 'package:flutter/material.dart';

// class SalesInvoiceState with ChangeNotifier {
//   String _selectedPaymentOption = '';
//   String _selectedPaymentOptionValue = '';
//   double _balanceAmount = 0.0;
//   double _cashAmount = 0.0;
//   double _cardAmount = 0.0;
//   double _upiAmount = 0.0;
//   String? _selectedEmployeeFirstName;
//   double _roundedDiscountAmount = 0.0;
//   String _invoiceNumber = '';
//   bool _isPrintButtonEnabled = false;
//   DateTime? _selectedBirthday;
//   bool _isUpiPaid = false;
//   bool _isCardPaid = false;
//   bool _isAddingCustomer = false; // Added
//   bool _isSubmitting = false; // Added

//   // Getters
//   String get selectedPaymentOption => _selectedPaymentOption;
//   String get selectedPaymentOptionValue => _selectedPaymentOptionValue;
//   double get balanceAmount => _balanceAmount;
//   double get cashAmount => _cashAmount;
//   double get cardAmount => _cardAmount;
//   double get upiAmount => _upiAmount;
//   String? get selectedEmployeeFirstName => _selectedEmployeeFirstName;
//   double get roundedDiscountAmount => _roundedDiscountAmount;
//   String get invoiceNumber => _invoiceNumber;
//   bool get isPrintButtonEnabled => _isPrintButtonEnabled;
//   DateTime? get selectedBirthday => _selectedBirthday;
//   bool get isUpiPaid => _isUpiPaid;
//   bool get isCardPaid => _isCardPaid;
//   bool get isAddingCustomer => _isAddingCustomer; // Added
//   bool get isSubmitting => _isSubmitting; // Added

//   // Setters
//   void updateSelectedPaymentOption(String value) {
//     _selectedPaymentOption = value;
//     notifyListeners();
//   }

//   void updateSelectedPaymentOptionValue(String value) {
//     _selectedPaymentOptionValue = value;
//     notifyListeners();
//   }

//   void updateBalanceAmount(double value) {
//     _balanceAmount = value;
//     notifyListeners();
//   }

//   void updateCashAmount(double value) {
//     _cashAmount = value;
//     notifyListeners();
//   }

//   void updateCardAmount(double value) {
//     _cardAmount = value;
//     notifyListeners();
//   }

//   void updateUpiAmount(double value) {
//     _upiAmount = value;
//     notifyListeners();
//   }

//   void updateSelectedEmployeeFirstName(String? value) {
//     _selectedEmployeeFirstName = value;
//     notifyListeners();
//   }

//   void updateRoundedDiscountAmount(double value) {
//     _roundedDiscountAmount = value;
//     notifyListeners();
//   }

//   void updateInvoiceNumber(String value) {
//     _invoiceNumber = value;
//     notifyListeners();
//   }

//   void updateIsPrintButtonEnabled(bool value) {
//     _isPrintButtonEnabled = value;
//     notifyListeners();
//   }

//   void updateSelectedBirthday(DateTime? value) {
//     _selectedBirthday = value;
//     notifyListeners();
//   }

//   void updateIsUpiPaid(bool value) {
//     _isUpiPaid = value;
//     notifyListeners();
//   }

//   void updateIsCardPaid(bool value) {
//     _isCardPaid = value;
//     notifyListeners();
//   }

//   void updateIsAddingCustomer(bool value) {
//     _isAddingCustomer = value;
//     notifyListeners();
//   }

//   void updateIsSubmitting(bool value) {
//     _isSubmitting = value;
//     notifyListeners();
//   }

//   // Method to update multiple state variables at once
//   void updateMultiple({
//     String? selectedPaymentOption,
//     String? selectedPaymentOptionValue,
//     double? balanceAmount,
//     double? cashAmount,
//     double? cardAmount,
//     double? upiAmount,
//     String? selectedEmployeeFirstName,
//     double? roundedDiscountAmount,
//     String? invoiceNumber,
//     bool? isPrintButtonEnabled,
//     DateTime? selectedBirthday,
//     bool? isUpiPaid,
//     bool? isCardPaid,
//     bool? isAddingCustomer,
//     bool? isSubmitting,
//   }) {
//     if (selectedPaymentOption != null) _selectedPaymentOption = selectedPaymentOption;
//     if (selectedPaymentOptionValue != null) _selectedPaymentOptionValue = selectedPaymentOptionValue;
//     if (balanceAmount != null) _balanceAmount = balanceAmount;
//     if (cashAmount != null) _cashAmount = cashAmount;
//     if (cardAmount != null) _cardAmount = cardAmount;
//     if (upiAmount != null) _upiAmount = upiAmount;
//     if (selectedEmployeeFirstName != null) _selectedEmployeeFirstName = selectedEmployeeFirstName;
//     if (roundedDiscountAmount != null) _roundedDiscountAmount = roundedDiscountAmount;
//     if (invoiceNumber != null) _invoiceNumber = invoiceNumber;
//     if (isPrintButtonEnabled != null) _isPrintButtonEnabled = isPrintButtonEnabled;
//     if (selectedBirthday != null) _selectedBirthday = selectedBirthday;
//     if (isUpiPaid != null) _isUpiPaid = isUpiPaid;
//     if (isCardPaid != null) _isCardPaid = isCardPaid;
//     if (isAddingCustomer != null) _isAddingCustomer = isAddingCustomer;
//     if (isSubmitting != null) _isSubmitting = isSubmitting;
//     notifyListeners();
//   }

// void reset() {
//   _selectedPaymentOption = '';
//   _selectedPaymentOptionValue = '';
//   _balanceAmount = 0.0;
//   _cashAmount = 0.0;
//   _cardAmount = 0.0;
//   _upiAmount = 0.0;
//   _selectedEmployeeFirstName = null;
//   _roundedDiscountAmount = 0.0;
//   _invoiceNumber = '';
//   _isPrintButtonEnabled = false;
//   _selectedBirthday = null;
//   _isUpiPaid = false;
//   _isCardPaid = false;
//   _isAddingCustomer = false;
//   _isSubmitting = false;

//   notifyListeners();
// }

// }

import 'package:flutter/foundation.dart';

class SalesInvoiceState with ChangeNotifier {
  TextEditingController employee = TextEditingController();
    final TextEditingController customerNumberController = TextEditingController();
String? _selectedEmployeeNumber;          // <-- NEW
  String? get selectedEmployeeNumber => _selectedEmployeeNumber;
  String _selectedPaymentOption = '';
  String _selectedPaymentOptionValue = '';
  double _balanceAmount = 0.0;
  double _cashAmount = 0.0;
  double _cardAmount = 0.0;
  double _upiAmount = 0.0;
  String? _selectedEmployeeFirstName;
  double _roundedDiscountAmount = 0.0;
  String _invoiceNumber = '';
  bool _isPrintButtonEnabled = false;
  DateTime? _selectedBirthday;
  bool _isUpiPaid = false;
  bool _isCardPaid = false;
  bool _isAddingCustomer = false;
  bool _isSubmitting = false;

  // ────────────────────── GETTERS ──────────────────────
  int get roundedBalance => _balanceAmount.round();
  String get selectedPaymentOption => _selectedPaymentOption;
  String get selectedPaymentOptionValue => _selectedPaymentOptionValue;
  double get balanceAmount => _balanceAmount;
  double get cashAmount => _cashAmount;
  double get cardAmount => _cardAmount;
  double get upiAmount => _upiAmount;
  String? get selectedEmployeeFirstName => _selectedEmployeeFirstName;
  double get roundedDiscountAmount => _roundedDiscountAmount;
  String get invoiceNumber => _invoiceNumber;
  bool get isPrintButtonEnabled => _isPrintButtonEnabled;
  DateTime? get selectedBirthday => _selectedBirthday;
  bool get isUpiPaid => _isUpiPaid;
  bool get isCardPaid => _isCardPaid;
  bool get isAddingCustomer => _isAddingCustomer;
  bool get isSubmitting => _isSubmitting;

  // ────────────────────── SETTERS ──────────────────────
  void updateSelectedPaymentOption(String value) {
    _selectedPaymentOption = value;
    notifyListeners();
  }

  void updateSelectedPaymentOptionValue(String value) {
    _selectedPaymentOptionValue = value;
    notifyListeners();
  }

  void updateBalanceAmount(double value) {
    _balanceAmount = value;
    notifyListeners();
  }

  void updateCashAmount(double value) {
    _cashAmount = value;
    notifyListeners();
  }

  void updateCardAmount(double value) {
    _cardAmount = value;
    notifyListeners();
  }

  void updateUpiAmount(double value) {
    _upiAmount = value;
    notifyListeners();
  }

  void updateSelectedEmployeeFirstName(String? value) {
    _selectedEmployeeFirstName = value;
    notifyListeners();
  }

  void updateRoundedDiscountAmount(double value) {
    _roundedDiscountAmount = value;
    notifyListeners();
  }

  void updateInvoiceNumber(String value) {
    _invoiceNumber = value;
    notifyListeners();
  }

  void updateIsPrintButtonEnabled(bool value) {
    _isPrintButtonEnabled = value;
    notifyListeners();
  }

  void updateSelectedBirthday(DateTime? value) {
    _selectedBirthday = value;
    notifyListeners();
  }

  void updateIsUpiPaid(bool value) {
    _isUpiPaid = value;
    notifyListeners();
  }

  void updateIsCardPaid(bool value) {
    _isCardPaid = value;
    notifyListeners();
  }

  void updateIsAddingCustomer(bool value) {
    _isAddingCustomer = value;
    notifyListeners();
  }

  void updateIsSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  // ────────────────────── MULTI-UPDATE ──────────────────────
  void updateMultiple({
    String? selectedPaymentOption,
    String? selectedPaymentOptionValue,
    double? balanceAmount,
    double? cashAmount,
    double? cardAmount,
    double? upiAmount,
    String? selectedEmployeeFirstName,
    double? roundedDiscountAmount,
    String? invoiceNumber,
    String? selectedEmployeeNumber,
    bool? isPrintButtonEnabled,
    DateTime? selectedBirthday,
    bool? isUpiPaid,
    bool? isCardPaid,
    bool? isAddingCustomer,
    bool? isSubmitting,
  }) {
    if (selectedEmployeeFirstName != null) _selectedEmployeeFirstName = selectedEmployeeFirstName;
    if (selectedEmployeeNumber != null) _selectedEmployeeNumber = selectedEmployeeNumber;
    if (selectedPaymentOption != null) _selectedPaymentOption = selectedPaymentOption;
    if (selectedPaymentOptionValue != null) _selectedPaymentOptionValue = selectedPaymentOptionValue;
    if (balanceAmount != null) _balanceAmount = balanceAmount;
    if (cashAmount != null) _cashAmount = cashAmount;
    if (cardAmount != null) _cardAmount = cardAmount;
    if (upiAmount != null) _upiAmount = upiAmount;
    if (selectedEmployeeFirstName != null) _selectedEmployeeFirstName = selectedEmployeeFirstName;
    if (roundedDiscountAmount != null) _roundedDiscountAmount = roundedDiscountAmount;
    if (invoiceNumber != null) _invoiceNumber = invoiceNumber;
    if (isPrintButtonEnabled != null) _isPrintButtonEnabled = isPrintButtonEnabled;
    if (selectedBirthday != null) _selectedBirthday = selectedBirthday;
    if (isUpiPaid != null) _isUpiPaid = isUpiPaid;
    if (isCardPaid != null) _isCardPaid = isCardPaid;
    if (isAddingCustomer != null) _isAddingCustomer = isAddingCustomer;
    if (isSubmitting != null) _isSubmitting = isSubmitting;
    notifyListeners();
  }

  // ────────────────────── PAYMENT-FLAG RESET ──────────────────────
  void resetPaymentFlags() {
    _isUpiPaid = false;
    _isCardPaid = false;
    // (no notifyListeners() here – reset() will call it)
  }

  // ────────────────────── FULL RESET ──────────────────────
  void reset() {
  _selectedPaymentOption = '';
  _selectedPaymentOptionValue = '';
  _balanceAmount = 0.0;
  _cashAmount = 0.0;
  _cardAmount = 0.0;
  _upiAmount = 0.0;
  _selectedEmployeeFirstName = null;
  _selectedEmployeeNumber = null; // Add this
  _roundedDiscountAmount = 0.0;
  _invoiceNumber = '';
  _isPrintButtonEnabled = false;
  _selectedBirthday = null;
  _isAddingCustomer = false;
  _isSubmitting = false;
  
  // Clear employee data
  employee.clear();
  
  // Reset payment flags
  resetPaymentFlags();

  notifyListeners();
}
}
