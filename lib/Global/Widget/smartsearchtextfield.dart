import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yen_pos/Global/pos_detector.dart';

class SmartSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;

  const SmartSearchField({
    required this.controller,
    required this.onSearch,
    Key? key,
  }) : super(key: key);

  @override
  State<SmartSearchField> createState() => _SmartSearchFieldState();
}

class _SmartSearchFieldState extends State<SmartSearchField> {
  late final FocusNode _focusNode;
  late final MobileScannerController _scannerController;
  bool _isPOSMode = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _scannerController = MobileScannerController();

    // Default: Assume not POS until we check
    _isPOSMode = false;

    // Check POS device asynchronously
    _checkPOSDevice();
  }

  Future<void> _checkPOSDevice() async {
    final isPOS = await POSDetector.isPOSDevice;

    if (!mounted) {
      return;
    }

    setState(() {
      _isPOSMode = isPOS;
    });

    if (_isPOSMode) {
      _focusNode.addListener(_handleScannerInput);

      // Optional: request focus automatically
      FocusScope.of(context).requestFocus(_focusNode);
    } else {}
  }

  void _handleScannerInput() {
    if (_focusNode.hasFocus) {
      widget.controller.clear();
    }
  }

  Future<void> _handleScanAction() async {
    if (_isPOSMode) {
      _focusNode.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ready to scan - use hardware scanner')),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan QR/Barcode',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Expanded(
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final barcode = capture.barcodes.firstOrNull;

                        if (barcode?.rawValue != null) {
                          setState(() {
                            widget.controller.text = barcode!.rawValue!;
                          });
                          widget.onSearch(barcode!.rawValue!);
                          Navigator.pop(context);
                        } else {}
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      onChanged: (value) {
        setState(() {
          widget.controller.text = value;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: widget.controller.text.length),
          );
          widget.onSearch(value);
        });
      },
      onSubmitted: (value) {
        setState(() {
          widget.controller.text = value.trim();
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: widget.controller.text.length),
          );
        });
        widget.onSearch(value.trim());
      },
      decoration: InputDecoration(
        hintText: 'Search orders',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: Icon(
            _isPOSMode ? Icons.qr_code : Icons.qr_code_scanner,
            color: Colors.blue,
          ),
          onPressed: _handleScanAction,
          tooltip: _isPOSMode ? 'Use hardware scanner' : 'Scan QR/Barcode',
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}
