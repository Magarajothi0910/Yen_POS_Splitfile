import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Widgets/photoScreen.dart';

bool _isRestoringHeldOrder = false;
Future<void> restoreHeldOrderData({
  required BuildContext context,
  required HeldOrder order,
  required CustomerScreenProvider customerProvider,
  required CartProvider cartProvider,
  required CartSelectionProvider selectionProvider,
}) async {
  if (_isRestoringHeldOrder) return;
  _isRestoringHeldOrder = true;

  try {
    print("🟦 ================================");
    print("🟦 RESTORING HELD ORDER");
    print("🟦 ================================");
    print("📊 Order details:");
    print("  - Customer: ${order.customerName}");
    print("  - Box Qty Data: ${order.boxQty}");
    print("  - IsBoxItem Data: ${order.isBoxItem}");
    print("  - Discount Data: ${order.itemWiseDiscount}");
    print("  - Discount Amount Data: ${order.itemWiseDiscountAmount}");
    print("  - status: ${order.status}");

    // Set restoring flag BEFORE updating controllers
    customerProvider.setRestoringOrder(true);

    // Check if this order was sent for approval
    bool isApprovalOrder =
        (order.status?.toLowerCase().contains('approved') == true ||
        order.status?.toLowerCase().contains('pending') == true);
    print("📋 isApprovalOrder: $isApprovalOrder");

    if (isApprovalOrder) {
      print("⚠️ This is an approval order - marking restoration state");
      customerProvider.setRestoringApprovalOrder(true);
      customerProvider.setOriginalApprovalStatus(order.status);
    } else {
      customerProvider.setRestoringApprovalOrder(false);
      customerProvider.setOriginalApprovalStatus(order.status);
    }

    // ---------------------- RESET UI ----------------------
    print("🔄 Resetting UI state...");

    // Clear all controllers and states
    customerProvider.resetControllers();

    cartProvider.clearCart();
    selectionProvider.clearSelections();
    selectionProvider.setShowCheckBoxes(false);

    // ✅ IMPORTANT: Reset media states
    customerProvider.showAudioandImage = false;
    customerProvider.audioPlayer = null;
    customerProvider.photoScreen = null;
    customerProvider.recordedFilePath = '';
    customerProvider.pickedImage1 = null;
    customerProvider.pickedImage2 = null;
    customerProvider.pickedImages.clear();

    // Clear custom charge controllers
    cartProvider.customChargeControllers.clear();
    cartProvider.customCharge.value = 0.0;

    // Clear global controllers
    globals.allBoxQtyController.clear();
    globals.bulkDiscountController.clear();
    globals.boxQtyControllers.clear();
    globals.discountControllers.clear();

    // ---------------------- RESTORE CUSTOMER DETAILS ----------------------
    print("👤 Restoring customer details...");

    customerProvider.customerNameController.text = order.customerName ?? "";
    customerProvider.mobileNoController.text = order.customerNumber ?? "";
    customerProvider.customerCombinedController.text =
        "${order.customerNumber ?? ''} - ${order.customerName ?? ''}";
    customerProvider.searchController.text = order.employeeName ?? "";
    customerProvider.addressController.text = order.address ?? "";
    customerProvider.landmarkController.text = order.landmark ?? "";
    customerProvider.remarkController.text = order.remark ?? "";
    customerProvider.setSelectedEvent(order.event);
    customerProvider.setSelectedDeliveryType(order.deliveryType);
    customerProvider.patchHoldOrderId = order.holdOrderId ?? "";
    customerProvider.customChargeController.text =
        order.customCharge?.toString() ?? "";

    // ---------------------- RESTORE AUDIO AND IMAGES ----------------------
    print("🎵 Restoring audio and images...");

    // Reset media states
    customerProvider.recordedFilePath = '';
    customerProvider.pickedImages.clear();
    customerProvider.showAudioandImage = false;

    // Restore audio
    if (order.audioPath != null && order.audioPath!.isNotEmpty) {
      final audioFile = File(order.audioPath!);
      if (await audioFile.exists()) {
        customerProvider.recordedFilePath = order.audioPath!;
        customerProvider.showAudioandImage = true;
        customerProvider.audioWidgetKey = GlobalKey();
        print("✅ Audio restored: ${order.audioPath}");
      } else {
        print("⚠️ Audio file not found: ${order.audioPath}");
      }
    }

    // Restore images
    if (order.imagePaths != null && order.imagePaths!.isNotEmpty) {
      for (final path in order.imagePaths!) {
        final file = File(path);
        if (await file.exists()) {
          customerProvider.pickedImages.add(file);
          customerProvider.showAudioandImage = true;
          print("✅ Image restored: $path");
        }
      }
    }

    // ✅ Show photo screen if images exist
    if (customerProvider.pickedImages.isNotEmpty) {
      PhotosScreen(
        imagePaths: customerProvider.pickedImages.map((f) => f.path).toList(),
      );
      customerProvider.showAudioandImage = true;
      print(
        "🖼️ Photo screen created with ${customerProvider.pickedImages.length} images",
      );
    }

    // Delivery Date
    if (order.deliveryDate != null && order.deliveryDate!.trim().isNotEmpty) {
      try {
        DateTime d = DateTime.parse(order.deliveryDate!);
        customerProvider.dateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(d);
        customerProvider.timeController.text = DateFormat('hh:mm a').format(d);
        print(
          "📅 Delivery date restored: ${customerProvider.dateController.text} ${customerProvider.timeController.text}",
        );
      } catch (_) {
        print("⚠️ Error parsing delivery date: ${order.deliveryDate}");
      }
    }

    // Event Date
    if (order.eventDate != null && order.eventDate!.trim().isNotEmpty) {
      try {
        DateTime ev = DateTime.parse(order.eventDate!);
        customerProvider.birthdaydateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(ev);
        print(
          "📅 Event date restored: ${customerProvider.birthdaydateController.text}",
        );
      } catch (_) {
        print("⚠️ Error parsing event date: ${order.eventDate}");
      }
    }

    // ---------------------- PREPARE FOR RESTORATION ----------------------
    print("🛒 Preparing to restore cart items...");

    int itemCount = order.itemName.length;
    bool hasBoxItem = false;
    int? commonBoxQty;
    double? commonDiscount;

    // Initialize discount arrays
    List<dynamic> itemWiseDiscounts =
        order.itemWiseDiscount ?? List.filled(itemCount, 0.0);
    List<dynamic> itemWiseDiscountAmounts =
        order.itemWiseDiscountAmount ?? List.filled(itemCount, 0.0);

    // Handle box quantity data properly
    List<dynamic> boxQtyList = [];
    if (order.boxQty != null) {
      if (order.boxQty is List) {
        boxQtyList = order.boxQty as List<dynamic>;
      } else {
        // If it's a single value, create a list with that value
        boxQtyList = List.filled(itemCount, order.boxQty);
      }
    } else {
      boxQtyList = List.filled(itemCount, 0);
    }

    // Handle isBoxItem data properly
    List<dynamic> isBoxItemList = [];
    if (order.isBoxItem != null) {
      if (order.isBoxItem is List) {
        isBoxItemList = order.isBoxItem as List<dynamic>;
      } else {
        // If it's a single value, create a list with that value
        isBoxItemList = List.filled(itemCount, order.isBoxItem);
      }
    } else {
      isBoxItemList = List.filled(itemCount, "no");
    }

    print("🔍 Box Quantity Data: $boxQtyList");
    print("🔍 IsBoxItem Data: $isBoxItemList");
    print("🔍 Discount Data: $itemWiseDiscounts");

    // Create a list to store cart items temporarily
    List<CartItem> cartItems = [];
    List<String> boxItemKeys = [];

    // Store box qty and discount values for controller setup
    Map<String, String> boxQtyValues = {};
    Map<String, String> discountValues = {};

    for (int i = 0; i < itemCount; i++) {
      print("\n🔹 Processing item $i: ${order.itemName[i]}");

      // Check if item is box item
      bool isBoxItem = false;
      dynamic isBoxItemData =
          isBoxItemList.isNotEmpty && i < isBoxItemList.length
          ? isBoxItemList[i]
          : "no";

      if (isBoxItemData is String) {
        isBoxItem = isBoxItemData.toLowerCase() == "yes";
      } else if (isBoxItemData is bool) {
        isBoxItem = isBoxItemData;
      } else {
        isBoxItem =
            isBoxItemData.toString().toLowerCase() == "true" ||
            isBoxItemData.toString().toLowerCase() == "yes";
      }

      // Extract box quantity
      int boxQty = 0;
      dynamic boxQtyData = boxQtyList.isNotEmpty && i < boxQtyList.length
          ? boxQtyList[i]
          : 0;

      if (boxQtyData != null) {
        if (boxQtyData is String) {
          boxQty = int.tryParse(boxQtyData) ?? 0;
        } else if (boxQtyData is int) {
          boxQty = boxQtyData;
        } else if (boxQtyData is double) {
          boxQty = boxQtyData.toInt();
        }
      }

      // Store for controller setup
      final varianceName = order.varianceName[i] ?? "item_$i";
      if (isBoxItem && boxQty > 0) {
        boxQtyValues[varianceName] = boxQty.toString();
        if (commonBoxQty == null) {
          commonBoxQty = boxQty;
          print("📦 Common box quantity found: $commonBoxQty");
        }
      }

      // Extract discount percentage
      double itemWiseDiscount = 0.0;
      if (i < itemWiseDiscounts.length && itemWiseDiscounts[i] != null) {
        dynamic discountValue = itemWiseDiscounts[i];
        if (discountValue is String) {
          itemWiseDiscount = double.tryParse(discountValue) ?? 0.0;
        } else if (discountValue is int) {
          itemWiseDiscount = discountValue.toDouble();
        } else if (discountValue is double) {
          itemWiseDiscount = discountValue;
        }
      }

      // Store for controller setup
      if (itemWiseDiscount > 0) {
        discountValues[varianceName] = itemWiseDiscount.toStringAsFixed(0);
        if (commonDiscount == null && isBoxItem) {
          commonDiscount = itemWiseDiscount;
        }
      }

      // Extract discount amount
      double itemWiseDiscountAmount = 0.0;
      if (i < itemWiseDiscountAmounts.length &&
          itemWiseDiscountAmounts[i] != null) {
        dynamic discountAmountValue = itemWiseDiscountAmounts[i];
        if (discountAmountValue is String) {
          itemWiseDiscountAmount = double.tryParse(discountAmountValue) ?? 0.0;
        } else if (discountAmountValue is int) {
          itemWiseDiscountAmount = discountAmountValue.toDouble();
        } else if (discountAmountValue is double) {
          itemWiseDiscountAmount = discountAmountValue;
        }
      }

      // Parse quantity safely
      int quantity = 0;
      if (i < order.qty.length && order.qty[i] != null) {
        dynamic qtyValue = order.qty[i];
        if (qtyValue is String) {
          quantity = int.tryParse(qtyValue) ?? 0;
        } else if (qtyValue is int) {
          quantity = qtyValue;
        } else if (qtyValue is double) {
          quantity = qtyValue.toInt();
        }
      }

      // Parse weight safely
      double weight = 0.0;
      if (i < order.weight.length && order.weight[i] != null) {
        dynamic weightValue = order.weight[i];
        if (weightValue is String) {
          weight = double.tryParse(weightValue) ?? 0.0;
        } else if (weightValue is int) {
          weight = weightValue.toDouble();
        } else if (weightValue is double) {
          weight = weightValue;
        }
      }

      // Parse price safely
      int pricePerKg = 0;
      if (i < order.price.length && order.price[i] != null) {
        dynamic priceValue = order.price[i];
        if (priceValue is String) {
          pricePerKg = int.tryParse(priceValue) ?? 0;
        } else if (priceValue is int) {
          pricePerKg = priceValue;
        } else if (priceValue is double) {
          pricePerKg = priceValue.toInt();
        }
      }

      // Parse tax safely
      int tax = 0;
      if (i < order.tax.length && order.tax[i] != null) {
        dynamic taxValue = order.tax[i];
        if (taxValue is String) {
          tax = int.tryParse(taxValue) ?? 0;
        } else if (taxValue is int) {
          tax = taxValue;
        } else if (taxValue is double) {
          tax = taxValue.toInt();
        }
      }

      print("   - Variance: $varianceName");
      print("   - Qty: $quantity, Box Qty: $boxQty, Price: ₹$pricePerKg");
      print("   - Is Box Item: $isBoxItem");
      print("   - Item-wise Discount: ${itemWiseDiscount}%");
      print("   - Item-wise Discount Amount: ₹${itemWiseDiscountAmount}");

      // Create CartItem with proper box quantity and discount values
      CartItem item = CartItem(
        varianceName: varianceName,
        itemName: order.itemName[i] ?? "",
        itemCode: order.itemCode[i] ?? "",
        pricePerKg: pricePerKg,
        sellingPrice: pricePerKg,
        itemWiseDiscount: itemWiseDiscount,
        itemWiseDiscountAmount: itemWiseDiscountAmount,
        discount: itemWiseDiscount > 0 ? itemWiseDiscount : null,
        isBoxItem: isBoxItem ? "yes" : "no",
        tax: tax,
        boxQuantity: isBoxItem ? boxQty : null,
        uom: order.uom[i] ?? "",
        quantity: quantity,
        weight: weight,
        showDiscount: itemWiseDiscount > 0 || itemWiseDiscountAmount > 0,
        showBoxQuantity: isBoxItem,
      );

      // Calculate selling amount based on discount
      double sellingPrice = pricePerKg.toDouble();
      double sellingAmount = 0.0;

      if (itemWiseDiscount > 0) {
        sellingPrice = pricePerKg * (1 - itemWiseDiscount / 100);
        sellingAmount = sellingPrice * quantity;
        print(
          "   - Applied ${itemWiseDiscount}% discount, New Price: ₹${sellingPrice.toStringAsFixed(2)}",
        );
      } else if (itemWiseDiscountAmount > 0) {
        double discountPerUnit = itemWiseDiscountAmount / quantity;
        sellingPrice = pricePerKg - discountPerUnit;
        sellingAmount = (pricePerKg * quantity) - itemWiseDiscountAmount;
        print(
          "   - Applied ₹${itemWiseDiscountAmount} discount, New Price: ₹${sellingPrice.toStringAsFixed(2)}",
        );
      } else {
        sellingPrice = pricePerKg.toDouble();
        sellingAmount = pricePerKg.toDouble() * quantity.toDouble();
      }

      // Update item with calculated values
      item.sellingPrice = sellingPrice.round();
      item.sellingAmount = sellingAmount;
      item.finalPrice = sellingPrice;

      // Add to temporary list
      cartItems.add(item);

      if (isBoxItem) {
        hasBoxItem = true;
        boxItemKeys.add(varianceName);
        print("   - Added as box item with quantity: $boxQty");
      }
    }

    // ---------------------- SETUP CONTROLLERS BEFORE ADDING TO CART ----------------------
    print("\n🎯 Setting up controllers BEFORE adding items to cart...");

    // Initialize controllers with values
    for (final varianceName in boxQtyValues.keys) {
      if (!globals.boxQtyControllers.containsKey(varianceName)) {
        globals.boxQtyControllers[varianceName] = TextEditingController();
      }
      final value = boxQtyValues[varianceName]!;
      globals.boxQtyControllers[varianceName]!.text = value;
      print("   📦 BoxQty controller for '$varianceName': $value");
    }

    for (final varianceName in discountValues.keys) {
      if (!globals.discountControllers.containsKey(varianceName)) {
        globals.discountControllers[varianceName] = TextEditingController();
        globals.discountFocusNodes[varianceName] = FocusNode();
      }
      final value = discountValues[varianceName]!;
      globals.discountControllers[varianceName]!.text = value;
      print("   💰 Discount controller for '$varianceName': ${value}%");
    }

    // Set bulk controllers
    if (commonBoxQty != null && commonBoxQty > 0) {
      globals.allBoxQtyController.text = commonBoxQty.toString();
      print("📊 Set bulk box quantity: $commonBoxQty");
    }

    if (commonDiscount != null && commonDiscount > 0) {
      globals.bulkDiscountController.text = commonDiscount.toStringAsFixed(0);
      print("📊 Set bulk discount: $commonDiscount%");
    }

    // ---------------------- ADD ALL ITEMS TO CART ----------------------
    print("\n🛒 Adding items to cart...");
    cartProvider.clearCart();

    for (var item in cartItems) {
      cartProvider.addItemToCart(item);
      print("   ➕ Added to cart: ${item.varianceName}");
    }

    // ---------------------- ENABLE GIFT MODE ----------------------
    if (hasBoxItem) {
      print("\n🎁 Gifted items detected -> enabling checkbox mode");
      selectionProvider.setShowCheckBoxes(true);

      // Select all box items
      for (final key in boxItemKeys) {
        selectionProvider.itemSelectionState[key] = true;
        print("   ✓ Selected box item: $key");
      }
    }

    // ---------------------- STORE COMMON BOX QUANTITY FOR CONTROLLER ----------------------
    if (commonBoxQty != null && commonBoxQty > 0) {
      customerProvider.restoredBoxQty = commonBoxQty;
      print("✅ Stored restored box quantity: $commonBoxQty");
    }

    // ---------------------- UPDATE UI ----------------------
    print("\n🔄 Updating UI...");

    // Force update all providers and rebuild UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // Update providers
        cartProvider.updateCart();
        customerProvider.updateCartItems();
        customerProvider.updateCartCount();

        // Notify all listeners
        cartProvider.notifyListeners();
        customerProvider.notifyListeners();
        selectionProvider.notifyListeners();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order restored successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print("✅ Order restoration completed successfully");
        print("🟦 ================================");
      }
    });
  } catch (e, s) {
    print("❌ Error restoring order: $e");
    print("Stack trace: $s");

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore order: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        customerProvider.setRestoringOrder(false);
        _isRestoringHeldOrder = false;
        print("🔚 Restoration process completed");
      }
    });
  }
}
