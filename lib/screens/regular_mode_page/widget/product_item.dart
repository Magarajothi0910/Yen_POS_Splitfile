import 'package:flutter/material.dart';

import '../../../Global/custom_textWidgets.dart';

class ProductItem extends StatelessWidget {
  final String title;
  final String price;
  final bool isSoldOut;

  const ProductItem({
    super.key,
    required this.title,
    required this.price,
    required this.isSoldOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomText(text: title, style: const TextStyle(fontSize: 16)),
          isSoldOut
              ? const CustomText(
                  text: 'Sold out',
                  style: TextStyle(fontSize: 16, color: Colors.red))
              : CustomText(text: price, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
