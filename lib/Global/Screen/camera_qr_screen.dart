

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({Key? key}) : super(key: key);

  @override
  _QRCodeScannerScreenState createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // Adjusted for balanced speed
    formats: [BarcodeFormat.qrCode], // Only detect QR codes
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleScannedCode(String code) async {
   
    // Pause the scanner to stop scanning
    controller.stop();

    // Display a blank screen (simulating hardware scan)
    setState(() {});

    // Small delay to stabilize the screen
    await Future.delayed(const Duration(milliseconds: 300));

    // Use Navigator.pop to return the scanned data
    if (context.mounted) {
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI QR Code Scanner"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              controller.start(); // Start scanning on tap for better focus
            },
            child: MobileScanner(
              controller: controller,
              fit: BoxFit.cover,
              onDetect: (BarcodeCapture capture) {
                for (final barcode in capture.barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
            
                    _handleScannedCode(code);
                    break; // Stop further processing after finding a valid code
                  }
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.stop();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text("Cancel"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
