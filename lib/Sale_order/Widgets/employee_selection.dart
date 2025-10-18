import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/Screen/camera_qr_screen.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Global/pos_detector.dart';
import 'package:yenposapp/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenposapp/Sale_order/Provider/detailsProvider.dart';

class EmployeeSearchDropdown extends StatefulWidget {
  const EmployeeSearchDropdown({Key? key}) : super(key: key);

  @override
  _EmployeeSearchDropdownState createState() => _EmployeeSearchDropdownState();
}

class _EmployeeSearchDropdownState extends State<EmployeeSearchDropdown> {
  bool _isProgrammaticUpdate = false;
  final _salesmanFocus = FocusNode();
  @override
  Widget build(BuildContext context) {
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: // inside build() of EmployeeSearchDropdown
                TextField(
              readOnly: true,
              showCursor: true, // Ensure cursor is visible
              focusNode: _salesmanFocus,
              controller: customerScreenProvider.searchController,
              decoration: InputDecoration(
                labelText: 'Search SalesMan',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _toggleQrMode,
                ),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black),

              // 🔧 new onTap
              onTap: () {
                ActiveField.activate(
                    ctrl: customerScreenProvider.searchController,
                    node: _salesmanFocus,
                    numeric: false);
              },
            ),
          ),
          if (_isQrMode)
            Offstage(
              offstage: true,
              child: TextField(
                focusNode: _focusNode,
                controller: _textController,
                keyboardType: TextInputType.none,
                onSubmitted: _handleInput,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 0),
                onTap: () {
                  ActiveField.activate(
                    ctrl: _textController,
                    node: _focusNode,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isQrMode = false;
  bool _isProcessing = false;
  Timer? _debounceTimer; // Added debounce timer
  List<String> _lastFilteredList = []; // Cache last filtered list

  @override
  void initState() {
    super.initState();

    final provider = context.read<CustomerScreenProvider>();

    // 🔑 this drives the overlay every time the text changes
    provider.searchController.addListener(_debouncedUpdateOverlay);
  }

  void _debouncedUpdateOverlay() {
    if (_isProgrammaticUpdate) return; // Skip if programmatic update
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _updateOverlay);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    customerScreenProvider.searchController
        .removeListener(_debouncedUpdateOverlay);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }
  // Keep existing dispose method unchanged

  void _updateOverlay() {
    if (_isProgrammaticUpdate) return;

    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);

    detailsProvider.searchQuery = customerScreenProvider.searchController.text;

    // If there's a search query and no overlay, create one
    if (detailsProvider.searchQuery.isNotEmpty && _overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context)!.insert(_overlayEntry!);
    }
    // If search query is empty, remove overlay
    else if (detailsProvider.searchQuery.isEmpty && _overlayEntry != null) {
      _removeOverlay();
    }
    // Otherwise, rebuild the existing overlay
    else if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
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

  Future<String> _scanWithCamera() async {
    // Simulate camera scan (you can integrate any camera QR scanner library here)
    await Future.delayed(const Duration(seconds: 1)); // Simulated delay
    return '{"Name": "John Doe"}'; // Simulated scanned data
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
      _textController.clear();
      _focusNode.unfocus(); // Make sure to unfocus
      setState(() {
        _isProcessing = false;
      });
    }
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200, // Constrain maximum height
                minWidth: size.width,
              ),
              child: Selector<DetailsProvider, List<String>>(
                selector: (_, provider) =>
                    provider.filteredEmployeeFirstNames ?? [],
                shouldRebuild: (prev, next) => !listEquals(prev, next),
                builder: (context, filteredEmployees, _) {
                  if (listEquals(filteredEmployees, _lastFilteredList)) {
                    return const SizedBox.shrink();
                  }
                  _lastFilteredList = filteredEmployees;

                  return filteredEmployees.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true, // Add shrinkWrap
                          padding: EdgeInsets.zero,
                          itemCount: filteredEmployees.length,
                          itemBuilder: (context, index) => _ListItem(
                            employeeName: filteredEmployees[index],
                            onSelect: _handleEmployeeSelection,
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No matches found'),
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {}
  }

  void _handleEmployeeSelection(String employeeName) {
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);

    // Set flag to avoid triggering the debounced update
    setState(() => _isProgrammaticUpdate = true);

    // Update the text field
    customerScreenProvider.searchController.text = employeeName;

    // Clear the search query in the provider
    detailsProvider.searchQuery = '';

    // Remove focus from the text field
    FocusScope.of(context).unfocus();

    // Remove overlay first
    _removeOverlay();

    // Reset the programmatic update flag after a small delay
    // to ensure the listener doesn't trigger immediately
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isProgrammaticUpdate = false);
      }
    });
  }
  // Keep rest of the methods unchanged
}

class _ListItem extends StatelessWidget {
  final String employeeName;
  final Function(String) onSelect;

  const _ListItem({
    required this.employeeName,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(employeeName),
      title: Text(
        employeeName,
        style: const TextStyle(color: Colors.black),
      ),
      hoverColor: Colors.blue.shade50,
      onTap: () => onSelect(employeeName),
    );
  }
}
