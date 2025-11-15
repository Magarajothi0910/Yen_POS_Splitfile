import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_type_provider.dart';

class OrderTypeRadio extends StatelessWidget {
  const OrderTypeRadio({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderTypeProvider = Provider.of<OrderTypeProviderDine>(context);

    return Row(
      children: [
        Radio<String>(
          value: 'Dine In',
          groupValue: orderTypeProvider.orderType,
          onChanged: (String? value) {
            orderTypeProvider.setOrderType(value!);
          },
          activeColor: const Color(0xFFA5D6A7), // Active color
        ),
        const Text('Dine In'),
        Radio<String>(
          value: 'Parcel',
          groupValue: orderTypeProvider.orderType,
          onChanged: (String? value) {
            orderTypeProvider.setOrderType(value!);
          },
          activeColor: const Color(0xFFA5D6A7), // Active color
        ),
        const Text('Parcel'),
      ],
    );
  }
}
