import 'package:flutter/material.dart';
import 'package:yenpos/Global/globals_data.dart';


class OptionsProvider extends ChangeNotifier {
  void toggleKeyboardButton() {
    isKeyboardEnabled = !isKeyboardEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    debugPrint("Keyboard : $isKeyboardEnabled");
    notifyListeners();
  }

   void toggleTicketButton() {
    isTicketEnabled = !isTicketEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    debugPrint("Ticket : $isTicketEnabled");
    notifyListeners();
  }
  void toggleCartButton() {
    isCartEnabled = !isCartEnabled;
    //isPaymentEnabled = !isPaymentEnabled;
    debugPrint("Cart : $isCartEnabled");
    notifyListeners();
  }

  void togglePaymentButton() {
    isPaymentEnabled = !isPaymentEnabled;
    debugPrint("Payment : $isPaymentEnabled");
    notifyListeners();
  }

  void togglePrintButton() {
    isPrintEnabled = !isPrintEnabled;
    debugPrint("Print : $isPrintEnabled");
    notifyListeners();
  }

  void toggleWhatsAppButton() {
    isWhatsAppEnabled = !isWhatsAppEnabled;
    debugPrint("WhatsApp : $isWhatsAppEnabled");
    notifyListeners();
  }

  void toggleSMSButton() {
    isSMSEnabled = !isSMSEnabled;
    debugPrint("SMS : $isSMSEnabled");
    notifyListeners();
  }

  void toggleGSTButton() {
    isGSTEnabled = !isGSTEnabled;
    debugPrint("GST : $isGSTEnabled");
    notifyListeners();
  }
}
