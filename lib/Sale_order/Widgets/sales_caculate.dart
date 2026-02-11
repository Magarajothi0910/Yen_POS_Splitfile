// sale_calculator.dart

class SaleCalculator {
  double _discountPercentage = 0.0;
  double _customCharge = 0.0;
  List<Map<String, dynamic>> _currentSaleItems = [];
  double sgst = 0.0;
  double cgst = 0.0;

  SaleCalculator(List<Map<String, dynamic>> currentSaleItems) {
    _currentSaleItems = currentSaleItems;
  }

  set discountPercentage(double value) {
    _discountPercentage = value;
  }

  set customCharge(double value) {
    _customCharge = value;
  }

  double calculateTotal() {
    double total = 0.0;
    sgst = 0.0; // Reset SGST total
    cgst = 0.0; // Reset CGST total

    // Calculate the total price and tax for all items
    for (var item in _currentSaleItems) {
      double itemTotal = calculateItemTotal(item);
      total += itemTotal;

      // Dynamically retrieve tax for the item
      double taxPercentage = (item['itemData']['tax'] as num).toDouble();

      // Calculate the tax for the item
      double itemTax = itemTotal * (taxPercentage / 100);

      // Split the tax into SGST and CGST
      double itemSGST = itemTax / 2;
      double itemCGST = itemTax / 2;

      // Add the item's SGST and CGST to the totals
      sgst += itemSGST;
      cgst += itemCGST;
    }

    // Apply any discount if applicable
    if (_discountPercentage > 0) {
      double discountAmount = total * (_discountPercentage / 100);
      total -= discountAmount;

      // Recalculate SGST and CGST after discount
      sgst -= sgst * (_discountPercentage / 100);
      cgst -= cgst * (_discountPercentage / 100);
    }

    // Add custom charge if applicable
    if (_customCharge > 0) {
      total += _customCharge;
    }

    return total;
  }

  double calculateItemTotal(Map<String, dynamic> item) {
    final String uom = item['varianceData']['variance_Uom'].toLowerCase();
    final double price = (item['varianceData']['variance_Defaultprice'] as num)
        .toDouble(); // Ensuring double
    final double quantity =
        (item['quantity'] as num).toDouble(); // Ensuring double

    if (uom == 'kg' || uom == 'kgs') {
      return price * quantity; // Quantity is the weight entered
    } else {
      return price * quantity; // Quantity is the count
    }
  }

  double calculateDiscountAmount() {
    double total = calculateTotal();
    return total * (_discountPercentage / 100);
  }

  String buildQuantityPriceDisplay(Map<String, dynamic> item) {
    // Check if varianceData exists and contains the expected keys
    final varianceData = item['varianceData'];
    if (varianceData == null) {
      return 'Data Unavailable'; // Return a default message if varianceData is null
    }

    final String? uom = varianceData['variance_Uom']?.toLowerCase();
    final double price =
        (varianceData['variance_Defaultprice'] ?? 0).toDouble();
    final double quantity = (item['quantity'] ?? 1).toDouble();

    // Check the UOM and format the display accordingly
    if (uom == 'kg' || uom == 'kgs') {
      return '${quantity.toStringAsFixed(2)} kg x ₹ ${price.toStringAsFixed(2)} per kg';
    } else {
      return '${quantity.toInt()} x ₹ ${price.toStringAsFixed(2)}';
    }
  }
}
