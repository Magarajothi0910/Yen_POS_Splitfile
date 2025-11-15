import 'package:flutter/material.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';


class ItemCardUI extends StatelessWidget {
  final String itemName;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ItemCardUI({
    super.key,
    required this.itemName,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CustomColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      elevation: 4,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize:
                MainAxisSize.min, // Ensure the Column wraps its content
            children: [
              Flexible(
                // Use Flexible instead of Expanded
                fit: FlexFit
                    .loose, // Allow the widget to take up only the necessary space
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CustomText(
                      text: itemName.isNotEmpty ? itemName[0] : '',
                      style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.black,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 15),
                child: CustomText(
                  text: itemName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CustomColors.black,
                  ),
                ),
              ),
            ],
          ),
          // Positioned for favorite icon if needed in the future
        ],
      ),
    );
  }
}
