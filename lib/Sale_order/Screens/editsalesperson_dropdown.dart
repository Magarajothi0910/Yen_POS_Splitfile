import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Sale_order/Provider/detailsProvider.dart';
import 'package:yenposapp/Sale_order/Provider/editcustomerscreenProvider.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 300});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class EditEmployeeSearchDropdown extends StatefulWidget {
  final bool modifyMode;

  const EditEmployeeSearchDropdown({Key? key, required this.modifyMode})
      : super(key: key);

  @override
  _EditEmployeeSearchDropdownState createState() =>
      _EditEmployeeSearchDropdownState();
}

class _EditEmployeeSearchDropdownState
    extends State<EditEmployeeSearchDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final Debouncer _debouncer = Debouncer(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);
    customerScreenProvider.searchController.addListener(_updateOverlay);
  }

  @override
  void dispose() {
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);

    customerScreenProvider.searchController.removeListener(_updateOverlay);
    customerScreenProvider.searchController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _updateOverlay() {
    if (!widget.modifyMode)
      return; // Prevent updating overlay if not in modify mode

    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);

    _debouncer.run(() {
      detailsProvider.searchQuery =
          customerScreenProvider.searchController.text;

      if (customerScreenProvider.searchController.text.isNotEmpty &&
          _overlayEntry == null) {
        _overlayEntry = _createOverlayEntry();
        Overlay.of(context).insert(_overlayEntry!);
      } else if (customerScreenProvider.searchController.text.isEmpty) {
        _removeOverlay();
      } else {
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

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
            child: Consumer<DetailsProvider>(
              builder: (context, detailsProvider, _) {
                final filteredEmployees =
                    detailsProvider.filteredEmployeeFirstNames;

                return filteredEmployees.isNotEmpty
                    ? ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employeeName = filteredEmployees[index];
                          return ListTile(
                            title: Text(
                              employeeName,
                              style: TextStyle(color: Colors.black),
                            ),
                            hoverColor: Colors.blue.shade50,
                            onTap: () {
                              _handleEmployeeSelection(employeeName);
                            },
                          );
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'No matches found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleEmployeeSelection(String employeeName) {
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);

    customerScreenProvider.searchController.text = employeeName;

    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);
    detailsProvider.filteredEmployeeFirstNames.clear();
    detailsProvider.notifyListeners();

    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: customerScreenProvider.searchController,
        enabled: widget.modifyMode, // Read-only unless modify mode is enabled
        decoration: const InputDecoration(
          labelText: 'Search SalesMan',
          border: OutlineInputBorder(),
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        style: TextStyle(fontSize: 14),
        cursorColor: widget.modifyMode
            ? Colors.blue
            : Colors.grey, // Indicate if editable
      ),
    );
  }
}
