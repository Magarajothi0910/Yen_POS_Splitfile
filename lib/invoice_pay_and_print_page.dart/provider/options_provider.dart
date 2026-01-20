import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/websocketService.dart';

class OptionsProvider extends ChangeNotifier {
  void toggleKeyboardButton() {
    isKeyboardEnabled = !isKeyboardEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    notifyListeners();
  }

  void toggleTicketButton() {
    isTicketEnabled = !isTicketEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    notifyListeners();
  }

  void toggleCartButton() {
    isCartEnabled = !isCartEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    notifyListeners();
  }

  void togglePaymentButton() {
    isPaymentEnabled = !isPaymentEnabled;
    notifyListeners();
  }

  void togglePrintButton() {
    isPrintEnabled = !isPrintEnabled;
    notifyListeners();
  }

  void toggleWhatsAppButton() {
    isWhatsAppEnabled = !isWhatsAppEnabled;
    notifyListeners();
  }

  void toggleSMSButton() {
    isSMSEnabled = !isSMSEnabled;
    notifyListeners();
  }

  void toggleGSTButton() {
    isGSTEnabled = !isGSTEnabled;
    notifyListeners();
  }

  void toggleSOPrintButton() {
    isSOPrintEnabled = !isSOPrintEnabled;
    notifyListeners();
  }

  void toggleSOWhatsappTButton() {
    isSOWhatsAppEnabled = !isSOWhatsAppEnabled;
    notifyListeners();
  }

  void toggleSOSMSButton() {
    isSOSMSEnabled = !isSOSMSEnabled;
    notifyListeners();
  }

  void toggleKOTPrintButton() {
    isKOTPrintEnabled = !isKOTPrintEnabled;
    notifyListeners();
  }

  void toggleKOTWhatsappButton() {
    isKOTWhatsappEnabled = !isKOTWhatsappEnabled;
    notifyListeners();
  }

  void toggleSOPaymentButton() {
    isSOPaymentEnabled = !isSOPaymentEnabled;
    notifyListeners();
  }

  void toggleKOTPaymentButton(context) {
    isKOTPaymentEnabled = !isKOTPaymentEnabled;
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    notifyListeners();

    if (webSocketService != null) {
      try {
        webSocketService.sendUpiState(isKOTPaymentEnabled);
      } catch (e) {
      }
    }
  }

  void setUpiState(bool enabled) {
    isKOTPaymentEnabled = enabled;
    notifyListeners();
  }
}
