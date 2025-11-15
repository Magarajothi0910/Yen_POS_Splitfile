import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import '../../components/flushbar.dart';

import '../../providers/upi_provider.dart';
import '../../services/websocketService.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool _isServerApp() => appType == 'server';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Payment Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // Main content - can be expanded with more payment options
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'UPI Payment Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage UPI payment toggles and settings here.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Positioned UPI Toggle
          Positioned(
            top: 5,
            left: 16,
            child: Consumer<UpiProviderDine>(
              builder: (context, upiProvider, child) {
                debugPrint('🔄 Consumer rebuilding with UPI state: ${upiProvider.isUpiEnabled}');
                return Row(
                  children: [
                    const Text(
                      'UPI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (!_isServerApp()) {
                          print('🔒 Access denied: App type is not server');
                          showCustomFlushbar(
                            context,
                            "Only server device can modify printer details.",
                            type: FlushbarType.accessDenied,
                          );
                          return;
                        }
                        final webSocketService = Provider.of<WebSocketService>(context, listen: false);
                        debugPrint('🟢 Current UPI State before toggle: ${upiProvider.isUpiEnabled}');
                        upiProvider.toggleUpi(webSocketService: webSocketService);
                        debugPrint('🟣 Toggle requested, waiting for confirmation from server...');
                      },
                      child: Container(
                        width: 60,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          color: upiProvider.isUpiEnabled ? Colors.blue : Colors.grey[400],
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: upiProvider.isUpiEnabled ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}