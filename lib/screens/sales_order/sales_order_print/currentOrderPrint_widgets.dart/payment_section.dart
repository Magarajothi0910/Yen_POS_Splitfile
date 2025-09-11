import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/customAll_keyboard.dart';

import './cheque_details.dart';

class PaymentSection extends StatefulWidget {
  final String selectedPaymentMethod;
  final List<String> cashOptions;
  final double originalAmount;
  final Function(String, String) onSelectPaymentOption;

  final TextEditingController customCashController;
  final TextEditingController customUpiController;
  final TextEditingController customCardController;
  final TextEditingController chequeNumberController;
  final TextEditingController chequeAmountController;
  final TextEditingController chequeNameController;
  final TextEditingController chequeBankController;
  final TextEditingController chequeDateController;

  final FocusNode customCashFocusNode;
  final FocusNode customUpiFocusNode;
  final FocusNode customCardFocusNode;

  final FocusNode chequeNumberFocus;
  final FocusNode chequeAmountFocus;
  final FocusNode chequeNameFocus;
  final FocusNode chequeDateFocus;

  final GlobalKey keyboardKey;

  const PaymentSection({
    super.key,
    required this.selectedPaymentMethod,
    required this.cashOptions,
    required this.originalAmount,
    required this.onSelectPaymentOption,
    required this.customCashController,
    required this.customUpiController,
    required this.customCardController,
    required this.chequeNumberController,
    required this.chequeAmountController,
    required this.chequeNameController,
    required this.chequeBankController,
    required this.chequeDateController,
    required this.customCashFocusNode,
    required this.customUpiFocusNode,
    required this.customCardFocusNode,
    required this.chequeNumberFocus,
    required this.chequeAmountFocus,
    required this.chequeNameFocus,
    required this.chequeDateFocus,
    required this.keyboardKey,
  });

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  KeyboardProvider? customKeyboardProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Safe to access provider here
    customKeyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedPaymentMethod == 'Cheque') {
      return ChequeDetails(
        chequeNumberController: widget.chequeNumberController,
        chequeAmountController: widget.chequeAmountController,
        chequeNameController: widget.chequeNameController,
        chequeDateController: widget.chequeDateController,
        chequeNumberFocus: widget.chequeNumberFocus,
        chequeAmountFocus: widget.chequeAmountFocus,
        chequeNameFocus: widget.chequeNameFocus,
        chequeDateFocus: widget.chequeDateFocus,
        keyboardKey: widget.keyboardKey,
        onFocusChanged: (index) {
          customKeyboardProvider!.setIndex(index);
        },
      );
    }

    final options = widget.selectedPaymentMethod == 'Cash'
        ? widget.cashOptions
        : [widget.originalAmount.toStringAsFixed(0)];

    final controller = widget.selectedPaymentMethod == 'Cash'
        ? widget.customCashController
        : widget.selectedPaymentMethod == 'Upi'
            ? widget.customUpiController
            : widget.customCardController;

    final focusNode = widget.selectedPaymentMethod == 'Cash'
        ? widget.customCashFocusNode
        : widget.selectedPaymentMethod == 'Upi'
            ? widget.customUpiFocusNode
            : widget.customCardFocusNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            '₹${controller.text.isEmpty ? '0' : controller.text}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                return GestureDetector(
                  onTap: () {
                    controller.text = option;
                    controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length));
                    widget.onSelectPaymentOption(
                        widget.selectedPaymentMethod, option);
                    focusNode.requestFocus();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal),
                    ),
                    child: Text(
                      '₹$option',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
