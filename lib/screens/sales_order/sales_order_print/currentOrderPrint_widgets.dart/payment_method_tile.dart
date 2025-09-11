import 'package:flutter/material.dart';

class PaymentMethodTile extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String?> onChanged;

  const PaymentMethodTile({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> paymentMethods = [
      'Cash',
      'Card',
      'UPI',
      'Cheque',
      'Others',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonFormField<String>(
        value: selectedMethod.isNotEmpty ? selectedMethod : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: 'Select Payment Method',
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.arrow_drop_down),
        items: paymentMethods.map((method) {
          return DropdownMenuItem<String>(
            value: method,
            child: Row(
              children: [
                Icon(_getIcon(method), size: 20, color: Colors.grey[700]),
                const SizedBox(width: 10),
                Text(method),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getIcon(String method) {
    switch (method) {
      case 'Cash':
        return Icons.money;
      case 'Card':
        return Icons.credit_card;
      case 'UPI':
        return Icons.phone_android;
      case 'Cheque':
        return Icons.account_balance_wallet;
      case 'Others':
        return Icons.more_horiz;
      default:
        return Icons.payment;
    }
  }
}
