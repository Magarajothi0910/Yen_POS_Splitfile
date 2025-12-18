import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/websocketService.dart';


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
   void toggleKOTPaymentButton(context) {
    isKOTPaymentEnabled = !isKOTPaymentEnabled;
      final webSocketService = Provider.of<WebSocketService>(context, listen: false);
      webSocketService.sendUpiState(isKOTPaymentEnabled);
      debugPrint("KOT Online Payment : $isKOTPaymentEnabled");
    notifyListeners();
  }
   void toggleSOPrintButton() {
    isSOPrintEnabled = !isSOPrintEnabled;
    debugPrint("SO Print : $isSOPrintEnabled");
    notifyListeners();
  }
   void toggleSOWhatsappTButton() {
    isSOWhatsAppEnabled = !isSOWhatsAppEnabled;
    debugPrint("SO Whatsapp : $isSOWhatsAppEnabled");
    notifyListeners();
  }
   void toggleSOSMSButton() {
    isSOSMSEnabled = !isSOSMSEnabled;
    debugPrint("SO SMS : $isSOSMSEnabled");
    notifyListeners();
  }
  void toggleKOTPrintButton() {
    isKOTPrintEnabled = !isKOTPrintEnabled;
    debugPrint("KOT Overall Print : $isKOTPrintEnabled");
    notifyListeners();
  }
   void toggleKOTWhatsappButton() {
    isKOTWhatsappEnabled = !isKOTWhatsappEnabled;
    debugPrint("KOT Whatsapp : $isKOTWhatsappEnabled");
    notifyListeners();
  }
   void toggleSOPaymentButton() {
    isSOPaymentEnabled = !isSOPaymentEnabled;
    debugPrint("SO Online Payment : $isSOPaymentEnabled");
    notifyListeners();
  }
}
