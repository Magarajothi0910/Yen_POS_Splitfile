import 'package:flutter/foundation.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';

class UpiProviderDine with ChangeNotifier {
  bool _isUpiEnabled = true;

  bool get isUpiEnabled => _isUpiEnabled;

  void toggleUpi({WebSocketService? webSocketService}) {
    _isUpiEnabled = !_isUpiEnabled;
    debugPrint('🔄 UPI toggled to: $_isUpiEnabled, notifying listeners');
    notifyListeners();

    if (webSocketService != null) {
      try {
        webSocketService.sendUpiState(_isUpiEnabled);
        debugPrint('📤 Sent UPI state update via WebSocket: $_isUpiEnabled');
      } catch (e) {
        debugPrint('⚠️ Failed to send UPI state via WebSocket: $e');
      }
    }
  }

  void setUpiState(bool enabled) {
    _isUpiEnabled = enabled;
    debugPrint('✅ Set UPI state to: $_isUpiEnabled, notifying listeners');
    notifyListeners();
  }
}
