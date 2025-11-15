library globals;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Sale_order/Models/sales_invoicemodel.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/modifyOrderProvider.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';

// ======================================================
// 🧩 BASIC DEVICE & USER DETAILS
// ======================================================

String deviceName = "POS1";
const String deviceId = "2";
const String deviceNumber = "1";

String userName = "";
String password = "";
String branchName = "";
String branchId = "";
String aliasname = "";
String branchAddress = "";
String branchPhoneno = "";

String ordertype = "Dinning";
String appType = ""; // "server" or "client"
bool sentServer = false;

// ======================================================
// 🌐 SERVER CONFIGURATION
// ======================================================

String serverip = "";
int port = 8181;
int udpPort = 56789;

// ======================================================
// 🔄 SHIFT / DAY STATUS TRACKERS
// ======================================================

final shiftId = ValueNotifier<String>("");
final shiftNumber = ValueNotifier<String>("");

final dayEndStatus = ValueNotifier<String>("");
final status = ValueNotifier<String>("");

final dispatchStatus = ValueNotifier<String>("");
final itemTransferStatus = ValueNotifier<String>("");
final soApprovalStatus = ValueNotifier<String>("");
final storeStatus = ValueNotifier<String>("");
final soDeliveryStatus = ValueNotifier<String>("");
final shiftOpenStatus = ValueNotifier<String>("");

List<Map<String, String>> dayEndData = [];

final currentDate = ValueNotifier<String>("");
final currentTime = ValueNotifier<String>("");

String ticketName = "";
// ======================================================
// 💾 WEBSOCKET CLIENT MANAGEMENT
// ======================================================

/// Active WebSocket client connections
final Set<WebSocketChannel> clients = {};

/// Mapping each WebSocket client to an identifier
final Map<WebSocketChannel, String> clientIds = {};

/// Global list of all received WebSocket messages
final List<Map<String, dynamic>> receivedData = [];

/// Remove a client safely and close its connection
void removeClient(WebSocketChannel client) {
  clients.remove(client);
  clientIds.remove(client);
  client.sink.close();
}

// ======================================================
// 💰 SALES, CART & ORDER DATA
// ======================================================

List<CartItem> cartItems = [];
int cartItemCount = 0;

List<SalesOrderItem> invoiceItems = [];
List<modifyCartItem> modifyItems = [];

// ======================================================
// 🧮 OTHER GLOBAL VARIABLES
// ======================================================

String enteredWeight = '';
int count = 0;
int count2 = 0;
int count3 = 0;
int count4 = 0;

bool hold = false;
const String empId = "1234";
const int kMaxRemarkLength = 50;

// ======================================================
// 🧠 TEXT FIELD & INPUT MANAGEMENT
// ======================================================

TextEditingController commonController = TextEditingController();
late FocusNode commonFocusNode;

/// Tracks quantity changes for order items
late ValueNotifier<Map<int, double>> quantityChangesNotifier;

//KOT

String createdBy = "";
final Map<String, WebSocketChannel> deviceClientMap =
    {}; // Map deviceCode to WebSocketChannel
List<String> areaNames = [];
const int maxExtraSeatsPerTable = 3;
Map<String, List<String>> extraTables = {};
List<Map<String, dynamic>> tables = [];

/// Toggles and features
bool isKeyboardEnabled = false;
bool isPaymentEnabled = true;
bool isPrintEnabled = true;
bool isWhatsAppEnabled = false;
bool isSMSEnabled = false;
bool isGSTEnabled = true;
bool isTicketEnabled = false;
bool isCartEnabled = false;

// ======================================================
// 🎯 ACTIVE INPUT FIELD MANAGER
// (Helps manage dynamic text fields like discount, customer number, etc.)
// ======================================================

class ActiveField {
  static final ValueNotifier<TextEditingController?> controller =
      ValueNotifier<TextEditingController?>(null);

  static final ValueNotifier<FocusNode?> focus = ValueNotifier<FocusNode?>(
    null,
  );

  static final ValueNotifier<bool> isNumeric = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isDiscount = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isCustomCharge = ValueNotifier<bool>(false);

  /// Stores field type (e.g., "customer number", "custom charge")
  static final ValueNotifier<String?> type = ValueNotifier<String?>(null);

  static final Map<TextEditingController, VoidCallback> _listenerMap = {};

  /// Activates a specific field, sets its behavior, and attaches listener
  static void activate({
    required BuildContext context,
    required TextEditingController ctrl,
    required FocusNode node,
    bool numeric = false,
    bool discount = false,
    bool customCharge = false,
    String? fieldType,
    void Function(String)? onChanged,
  }) {
    // Unfocus any previously active field
    focus.value?.unfocus();

    // Assign new field states
    controller.value = ctrl;
    focus.value = node;
    isNumeric.value = numeric;
    isDiscount.value = discount;
    isCustomCharge.value = customCharge;
    type.value = fieldType;

    node.requestFocus();

    // Remove any old listener attached to this controller
    if (_listenerMap.containsKey(ctrl)) {
      ctrl.removeListener(_listenerMap[ctrl]!);
    }

    // Define listener
    void listener() {
      final fieldType = type.value;

      if (fieldType == "customer number") {
        // Allow only 10 digits for customer number
        if (ctrl.text.contains('-')) return;

        final digitsOnly = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.length > 10) {
          ctrl.text = digitsOnly.substring(0, 10);
        } else if (digitsOnly != ctrl.text) {
          ctrl.text = digitsOnly;
        }
        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      } else if (fieldType == "custom charge") {
        final digitsOnly = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');

        // Check if value is empty
        if (digitsOnly.isEmpty) {
          TopMessage.show(
            context,
            message: "Box Qty cannot be empty",
            backgroundColor: Colors.redAccent,
          );
          return; // Stop further processing
        }

        // Disallow leading zero
        if (digitsOnly.startsWith('0')) {
          TopMessage.show(
            context,
            message: "Value cannot start with 0",
            backgroundColor: Colors.redAccent,
          );
          ctrl.clear();
          return;
        }

        // Limit digits
        if (digitsOnly.length > 5) {
          TopMessage.show(
            context,
            message: "Only up to 5 digits allowed",
            backgroundColor: Colors.orangeAccent,
          );
          ctrl.text = digitsOnly.substring(0, 5);
        } else if (digitsOnly != ctrl.text) {
          ctrl.text = digitsOnly;
        }

        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      } else if (fieldType == "discount") {
        // Allow only numeric + dot
        final valueText = ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
        if (valueText != ctrl.text) {
          ctrl.text = valueText;
        }

        final value = double.tryParse(valueText);
        if (value != null) {
          if (value > 100) {
            TopMessage.show(
              context,
              message: "Discount cannot exceed 100%",
              backgroundColor: Colors.orangeAccent,
            );
            ctrl.text = '100';
          } else if (value < 1 && valueText.isNotEmpty) {
            TopMessage.show(
              context,
              message: "Minimum discount is 1%",
              backgroundColor: Colors.orangeAccent,
            );
            ctrl.text = '1';
          }
        }

        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      }

      if (onChanged != null) onChanged(ctrl.text);
    }

    // Add listener and store it
    ctrl.addListener(listener);
    _listenerMap[ctrl] = listener;
  }

  /// Clears the active field and resets all flags
  static void clear() {
    focus.value?.unfocus();
    controller.value = null;
    focus.value = null;
    isNumeric.value = false;
    isDiscount.value = false;
    isCustomCharge.value = false;
    type.value = null;
  }
}
