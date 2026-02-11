// class SaleCalculator {
//   double _discountPercentage = 0.0;
//   double _customCharge = 0.0;
//   List<Map<String, dynamic>> _currentSaleItems = [];
//   double sgst = 0.0;
//   double cgst = 0.0;

//   SaleCalculator(List<Map<String, dynamic>> currentSaleItems) {
//     _currentSaleItems = currentSaleItems;
//   }

//   set discountPercentage(double value) {
//     _discountPercentage = value;
//   }

//   set customCharge(double value) {
//     _customCharge = value;
//   }

//   double calculateTotal() {
//     double total = 0.0;
//     sgst = 0.0;
//     cgst = 0.0;

//     for (var item in _currentSaleItems) {
//       double itemTotal = calculateItemTotal(item);
//       total += itemTotal;

//       double taxPercentage = (item['itemData']['tax'] as num?)?.toDouble() ?? 0.0;
//       double itemTax = itemTotal * (taxPercentage / 100);
//       double itemSGST = itemTax / 2;
//       double itemCGST = itemTax / 2;

//       sgst += itemSGST;
//       cgst += itemCGST;
//     }

//     if (_discountPercentage > 0) {
//       double discountAmount = total * (_discountPercentage / 100);
//       total -= discountAmount;
//       sgst -= sgst * (_discountPercentage / 100);
//       cgst -= cgst * (_discountPercentage / 100);
//     }

//     if (_customCharge > 0) {
//       total += _customCharge;
//     }

//     print('DEBUG: SaleCalculator - calculateTotal - Total: $total, SGST: $sgst, CGST: $cgst');
//     return total;
//   }

//   double calculateItemTotal(Map<String, dynamic> item) {
//     final String uom = item['varianceData']['variance_Uom']?.toLowerCase() ?? 'pcs';
//     final double price = (item['varianceData']['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
//     final double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
//     final double weight = (item['weight'] as num?)?.toDouble() ?? 0.0;

//     double total = (uom == 'kg' || uom == 'kgs') ? price * weight : price * quantity;
//     print('DEBUG: SaleCalculator - calculateItemTotal - UOM: $uom, Price: $price, Quantity: $quantity, Weight: $weight, Total: $total');
//     return total;
//   }

//   double calculateDiscountAmount() {
//     double total = calculateTotal();
//     return total * (_discountPercentage / 100);
//   }

//   String buildQuantityPriceDisplay(Map<String, dynamic> item) {
//     // Extract values safely
//     final String uom = (item['varianceData']['variance_Uom']?.toString().toLowerCase() ??
//                        item['uom']?.toString().toLowerCase() ??
//                        'pcs');

//     final double price = (item['varianceData']['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
//     final double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
//     final double weight = (item['weight'] as num?)?.toDouble() ?? 0.0;

//     print('DEBUG: SaleCalculator - buildQuantityPriceDisplay - UOM: $uom, Price: $price, Quantity: $quantity, Weight: $weight');

//     String display;
//     if (uom == 'kg' || uom == 'kgs') {
//       // For weight items, use the weight value for display
//       display = '${weight.toStringAsFixed(2)} kg x ₹${price.toStringAsFixed(2)} per kg';
//     } else {
//       // For quantity items, use the quantity value
//       display = '${quantity.toInt()} x ₹${price.toStringAsFixed(2)}';
//     }

//     print('DEBUG: SaleCalculator - buildQuantityPriceDisplay - Final Display: $display');
//     return display;
//   }
// }

class SaleCalculator {
  List<Map<String, dynamic>> _currentSaleItems = [];
  double _discountPercentage = 0.0;
  double _customCharge = 0.0;
  double sgst = 0.0;
  double cgst = 0.0;
  final bool debug;

  SaleCalculator(List<Map<String, dynamic>> currentSaleItems, {this.debug = false}) {
    _currentSaleItems = currentSaleItems;
  }

  /// Setters for discount and custom charges
  set discountPercentage(double value) => _discountPercentage = value;
  set customCharge(double value) => _customCharge = value;

  /// Calculate the total price of the sale including taxes, discount, and custom charges
  double calculateTotal() {
    double total = 0.0;
    sgst = 0.0;
    cgst = 0.0;

    for (var item in _currentSaleItems) {
      double itemTotal = calculateItemTotal(item);
      total += itemTotal;

      double taxPercentage = (item['itemData']?['tax'] as num?)?.toDouble() ?? 0.0;
      double itemTax = itemTotal * (taxPercentage / 100);
      sgst += itemTax / 2;
      cgst += itemTax / 2;
    }

    // Apply discount
    if (_discountPercentage > 0) {
      double discountAmount = total * (_discountPercentage / 100);
      total -= discountAmount;
      sgst -= sgst * (_discountPercentage / 100);
      cgst -= cgst * (_discountPercentage / 100);
    }

    // Apply custom charge
    if (_customCharge > 0) {
      total += _customCharge;
    }

    if (debug) {
      print('DEBUG: SaleCalculator - calculateTotal - Total: $total, SGST: $sgst, CGST: $cgst');
    }

    return total;
  }

  /// Calculate total for a single item based on UOM (kg or pcs)
  double calculateItemTotal(Map<String, dynamic> item) {
    final String uom = (item['varianceData']?['variance_Uom']?.toString().trim().toLowerCase() ??
        item['uom']?.toString().trim().toLowerCase() ??
        'pcs');
    final double price = (item['varianceData']?['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
    final double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
    final double weight = (item['weight'] as num?)?.toDouble() ?? 0.0;

    double total = (uom == 'kg' || uom == 'kgs') ? price * weight : price * quantity;

    if (debug) {
      print(
          'DEBUG: SaleCalculator - calculateItemTotal - UOM: $uom, Price: $price, Quantity: $quantity, Weight: $weight, Total: $total');
    }

    return total;
  }

  /// Calculate only discount amount
  double calculateDiscountAmount() {
    double totalBeforeDiscount = 0.0;
    for (var item in _currentSaleItems) {
      totalBeforeDiscount += calculateItemTotal(item);
    }
    return totalBeforeDiscount * (_discountPercentage / 100);
  }

  /// Build quantity x price display string
  String buildQuantityPriceDisplay(Map<String, dynamic> item) {
    final String uom = (item['varianceData']?['variance_Uom']?.toString().trim().toLowerCase() ??
        item['uom']?.toString().trim().toLowerCase() ??
        'pcs');
    final double price = (item['varianceData']?['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
    final double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
    final double weight = (item['weight'] as num?)?.toDouble() ?? 0.0;

    String display;
    if (uom == 'kg' || uom == 'kgs') {
      display = '${weight.toStringAsFixed(2)} kg x ₹${price.toStringAsFixed(2)} per kg';
    } else {
      display = '${quantity.toInt()} x ₹${price.toStringAsFixed(2)}';
    }

    if (debug) {
      print('DEBUG: SaleCalculator - buildQuantityPriceDisplay - Final Display: $display');
    }

    return display;
  }
}
