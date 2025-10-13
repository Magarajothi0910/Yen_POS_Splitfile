import 'package:flutter/material.dart';
import '../../../../Global/custom_textWidgets.dart';
import '../../screens/model/sales_order_display_model.dart';

class BalanceAndActions extends StatelessWidget {
  final double balanceAmount;
  final bool isPrintButtonEnabled;
  final String salesOrderId;
  final SalesOrderDisplay salesOrder;
  final String selectedPaymentOption;
  final int cashAmount;
  final int cardAmount;
  final int upiAmount;
  final VoidCallback onPrint;
  final VoidCallback onCancel;

  const BalanceAndActions({
    super.key,
    required this.balanceAmount,
    required this.isPrintButtonEnabled,
    required this.salesOrderId,
    required this.salesOrder,
    required this.selectedPaymentOption,
    required this.cashAmount,
    required this.cardAmount,
    required this.upiAmount,
    required this.onPrint,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Row(
          children: [
            Expanded(child: _buildOrderAmountSection()),
            _verticalDivider(),
            Expanded(child: _buildBalanceAmountSection()),
            _verticalDivider(),
            _buildPrintButton(),
            const SizedBox(width: 12),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: VerticalDivider(thickness: 1, color: Colors.black12),
    );
  }

  Widget _buildOrderAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: "Total",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        CustomText(
          text: "₹${salesOrder.totalAmount.toStringAsFixed(0)}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: "Balance",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        CustomText(
          text: "₹${balanceAmount.abs().toStringAsFixed(0)}",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.print, size: 18),
      label: const Text(
        "Print",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrintButtonEnabled ? Colors.blueAccent : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 3,
      ),
      onPressed: isPrintButtonEnabled ? onPrint : null,
    );
  }

  Widget _buildCancelButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.cancel, size: 18),
      label: const Text(
        "Cancel",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 3,
      ),
      onPressed: onCancel,
    );
  }
}
