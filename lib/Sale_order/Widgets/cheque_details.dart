import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Sale_order/Widgets/bank_search_dropdown.dart';
import 'package:yenposapp/Sale_order/Widgets/paymentDetail_keybaord.dart';

class ChequeDetails extends StatefulWidget {
  final TextEditingController chequeNumberController;
  final TextEditingController chequeAmountController;
  final TextEditingController chequeNameController;
  final TextEditingController chequeDateController;

  final FocusNode chequeNumberFocus;
  final FocusNode chequeAmountFocus;
  final FocusNode chequeNameFocus;
  final FocusNode chequeDateFocus;

  final void Function(int) onFocusChanged;
  final GlobalKey keyboardKey;

  const ChequeDetails({
    super.key,
    required this.chequeNumberController,
    required this.chequeAmountController,
    required this.chequeNameController,
    required this.chequeDateController,
    required this.chequeNumberFocus,
    required this.chequeAmountFocus,
    required this.chequeNameFocus,
    required this.chequeDateFocus,
    required this.onFocusChanged,
    required this.keyboardKey,
  });

  @override
  State<ChequeDetails> createState() => _ChequeDetailsState();
}

class _ChequeDetailsState extends State<ChequeDetails> {
  PaymentDetailKeyboardProvider? customKeyboardProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Safe to access provider here
    customKeyboardProvider =
        Provider.of<PaymentDetailKeyboardProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    widget.chequeNumberFocus.addListener(() {
      if (widget.chequeNumberFocus.hasFocus) widget.onFocusChanged(0);
    });
    widget.chequeAmountFocus.addListener(() {
      if (widget.chequeAmountFocus.hasFocus) widget.onFocusChanged(1);
    });
    widget.chequeDateFocus.addListener(() {
      if (widget.chequeDateFocus.hasFocus) widget.onFocusChanged(2);
    });
    widget.chequeNameFocus.addListener(() {
      if (widget.chequeNameFocus.hasFocus) widget.onFocusChanged(3);
    });
  }

  void _handleTap(
      FocusNode node, TextEditingController controller, String type) {
    final index = customKeyboardProvider!.controllers.indexOf(controller);
    if (index != -1) {
      // Update the input type in the keyboard's internal list
      if (customKeyboardProvider!.inputTypes.length > index) {
        customKeyboardProvider!.inputTypes[index] =
            type; // set type: 'numeric', 'text', 'alphanumeric'
      }
      customKeyboardProvider!.setIndex(index); // just set index
    }
    FocusScope.of(context).requestFocus(node);
  }

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.42;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildChequeField(
                        label: 'Cheque No.',
                        controller: widget.chequeNumberController,
                        focusNode: widget.chequeNumberFocus,
                        icon: Icons.numbers,
                        width: fieldWidth,
                        inputType:
                            'alphanumeric', // ✅ allow both letters & numbers
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChequeField(
                        label: 'Amount',
                        controller: widget.chequeAmountController,
                        focusNode: widget.chequeAmountFocus,
                        icon: Icons.currency_rupee,
                        prefixText: '₹ ',
                        width: fieldWidth,
                        inputType: 'numeric', // ✅ numbers only
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(width: fieldWidth),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChequeField(
                        label: 'Holder Name',
                        controller: widget.chequeNameController,
                        focusNode: widget.chequeNameFocus,
                        icon: Icons.person,
                        width: fieldWidth,
                        inputType: 'text', // ✅ letters only
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        child: BankSearchDropdown(
                          keyboardKey:
                              widget.keyboardKey, // ✅ use widget.keyboardKey
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChequeField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required double width,
    String? prefixText,
    required String inputType, // 'alphanumeric', 'numeric', 'text'
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: true, // disable system keyboard
        showCursor: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefixText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onTap: () {
          // 👉 activate custom keyboard properly
          ActiveField.activate(
            ctrl: controller,
            node: focusNode,
            numeric: inputType == 'numeric',
          );

          // 👉 also update provider type (if you need text/alphanumeric handling)
          final index = customKeyboardProvider!.controllers.indexOf(controller);
          if (index != -1 &&
              customKeyboardProvider!.inputTypes.length > index) {
            customKeyboardProvider!.inputTypes[index] = inputType;
            customKeyboardProvider!.setIndex(index);
          }
        },
      ),
    );
  }

  Widget _buildDateField({required double width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: widget.chequeDateController,
        focusNode: widget.chequeDateFocus,
        readOnly: true,
        showCursor: true,
        decoration: InputDecoration(
          labelText: 'Cheque Date',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onTap: () async {
          _handleTap(
              widget.chequeDateFocus, widget.chequeDateController, 'text');

          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.blue, // header background color
                    onPrimary: Colors.white, // header text color
                    onSurface: Colors.black, // body text color
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue, // buttons (OK/CANCEL) color
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            widget.chequeDateController.text =
                "${picked.day}/${picked.month}/${picked.year}";
          }
        },
      ),
    );
  }
}
