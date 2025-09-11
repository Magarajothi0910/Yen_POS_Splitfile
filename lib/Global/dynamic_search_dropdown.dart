import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/sales_order/sales_order_providers/customerScreen_provider.dart';
import '../screens/sales_order/sales_order_providers/detailsProvider.dart';
import 'camera_qr_screen.dart';
import 'pos_detector.dart';

class DynamicSearchDropdown extends StatefulWidget {
  final TextEditingController controller;
  final List<String> filteredItems;
  final ValueChanged<String> onSelected;
  final String labelText;
  final bool enableQrScan;

  const DynamicSearchDropdown({
    Key? key,
    required this.controller,
    required this.filteredItems,
    required this.onSelected,
    this.labelText = 'Search',
    this.enableQrScan = true,
  }) : super(key: key);

  @override
  _DynamicSearchDropdownState createState() => _DynamicSearchDropdownState();
}

class _DynamicSearchDropdownState extends State<DynamicSearchDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _qrTextController = TextEditingController();

  bool _isQrMode = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateOverlay);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateOverlay);
    _overlayEntry?.remove();
    _focusNode.dispose();
    _qrTextController.dispose();
    super.dispose();
  }

  void _updateOverlay() {
    if (widget.controller.text.isNotEmpty && _overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else if (widget.controller.text.isEmpty) {
      _removeOverlay();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
     
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: _buildResultsList(),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return widget.filteredItems.isNotEmpty
        ? ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: widget.filteredItems.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(widget.filteredItems[index]),
              hoverColor: Colors.blue.shade50,
              onTap: () => _handleSelection(widget.filteredItems[index]),
            ),
          )
        : const Padding(
            padding: EdgeInsets.all(8.0),
            child:
                Text('No matches found', style: TextStyle(color: Colors.grey)),
          );
  }

  void _handleSelection(String value) {
    widget.controller.text = value;
    widget.onSelected(value);
    FocusScope.of(context).unfocus();
    _removeOverlay();
  }

  // ... [Keep all the QR scanning methods unchanged from original] ...

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        children: [
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
              suffixIcon: widget.enableQrScan
                  ? IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _toggleQrMode,
                    )
                  : null,
            ),
          ),
          if (_isQrMode)
            Offstage(
              child: TextField(
                focusNode: _focusNode,
                controller: _qrTextController,
                onSubmitted: _handleInput,
                style: const TextStyle(fontSize: 0),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleQrMode() async {
    bool isPOS = await POSDetector.isPOSDevice;

    if (isPOS) {
      _startHardwareScanner(); // Use hardware scanner for POS devices
    } else {
      _startCameraScan(); // Use camera for non-POS devices
    }
  }

  void _startHardwareScanner() {
    setState(() {
      _isQrMode = true;
      _focusNode.requestFocus(); // Focus on the hidden field
    });
  
  }

  void _startCameraScan() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRCodeScannerScreen()),
    ).then((scannedData) {
    
      if (scannedData != null && scannedData is String) {
        _handleInput(scannedData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No QR code detected or scanning canceled."),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _handleInput(String value) async {
    if (_isProcessing || !_isQrMode || value.isEmpty) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final Map<String, dynamic> scannedData = _parseScannedData(value);
      if (scannedData.containsKey('Name')) {
        final employeeName = scannedData['Name'];
        _handleEmployeeSelection(employeeName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid QR data. 'EmployeeName' not found."),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          duration: const Duration(milliseconds: 500),
        ),
      );
    } finally {
      _qrTextController.clear();
      _focusNode.unfocus(); // Make sure to unfocus
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handleEmployeeSelection(String employeeName) {
  
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    customerScreenProvider.searchController.text = employeeName;
   
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
   
    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);
    detailsProvider.filteredEmployeeFirstNames.clear();
    detailsProvider.searchQuery = '';
   
    detailsProvider.notifyListeners();
    
    _removeOverlay();
  }

  Map<String, dynamic> _parseScannedData(String value) {
    if (value.trim().isEmpty) {
      throw FormatException("Scanned data is empty");
    }
    try {
      return json.decode(value); // Try parsing JSON
    } catch (_) {
      // Fallback to key-value pair parsing
      final Map<String, dynamic> parsedData = {};
      value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          parsedData[keyValue[0].trim()] = keyValue[1].trim();
        }
      });
      if (parsedData.isEmpty) {
        throw FormatException("Scanned data is not in a recognizable format");
      }
      return parsedData;
    }
  }
}
