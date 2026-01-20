import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/regular_mode_page/provider/image_service.dart';

import '../provider/favorite_page_provider.dart';

class ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemCard({super.key, required this.item});

  @override
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  @override
  Widget build(BuildContext context) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    bool isFavorite = favoriteProvider.isFavorite(widget.item);
    final imageUrl = widget.item['imagePath'] ?? '';
    final cachedBytes = imageUrl.isNotEmpty
        ? ImageCacheService.getImage(imageUrl)
        : null;

    Widget _fallbackLetter() {
      return Center(
        child: Text(
          widget.item['name'][0].toString().toUpperCase(),
          style: const TextStyle(fontSize: 40, fontFamily: "Poppins"),
        ),
      );
    }

    return Card(
      color: CustomColors.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      elevation: 4,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // child: Container(
                //   color: Colors.grey[200],
                //   child: Center(
                //     child: CustomText(
                //       text: widget.item['name']?.isNotEmpty ?? false
                //           ? widget.item['name'][0]
                //           : '',
                //       style:  TextStyle(
                //         fontFamily: "Poppins",
                //         fontSize: 40,

                //         color: CustomColors.black,
                //       ),
                //     ),
                //   ),
                // ),
                child: Container(
                  color: Colors.grey[200],

                  child: cachedBytes != null
                      ? Image.memory(cachedBytes, fit: BoxFit.cover)
                      : imageUrl.toString().isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return _fallbackLetter();
                          },
                        )
                      : _fallbackLetter(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 5,
                  bottom: 5,
                  left: 2,
                  right: 1,
                ),
                child: CustomText(
                  text: widget.item['name'] ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CustomColors.black,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  favoriteProvider.toggleFavorite(widget.item);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ItemCakeCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemCakeCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Here we assume that the favorite provider logic still applies.
    // (You might need to adjust favorite handling for the flattened variance cards.)
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    // ignore: unused_local_variable
    bool isFavorite = favoriteProvider.isFavorite(item);

    // Retrieve the variance details from the 'variance' key.
    final variance = item['variance'] as Map<String, dynamic>? ?? {};
    final String varianceName = variance['varianceName'] as String? ?? '';
    // Extract branchwise data for branch 'AR'
    final branchwise = variance['branchwise'] as Map<String, dynamic>? ?? {};
    final arBranch = branchwise['AR'] as Map<String, dynamic>? ?? {};
    // Convert the physicalStock value to an integer (defaults to 0 if missing)
    final int physicalStock = (arBranch['physicalStock'] as num?)?.toInt() ?? 0;

    return Card(
      color: CustomColors.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      elevation: 4,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The top portion shows a large letter (first letter of the variance name).
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CustomText(
                      text: varianceName.isNotEmpty ? varianceName[0] : '',
                      style: const TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.black,
                      ),
                    ),
                  ),
                ),
              ),
              // Instead of the item name, display the variance name.
              Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 15),
                child: CustomText(
                  text: varianceName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CustomColors.black,
                  ),
                ),
              ),
            ],
          ),
          // Favorite icon (if needed).
          // Positioned(
          //   top: -8,
          //   right: -8,
          //   child: IconButton(
          //     icon: Icon(
          //       isFavorite ? Icons.favorite : Icons.favorite_border,
          //       color: isFavorite ? Colors.red : Colors.grey,
          //       size: 22,
          //     ),
          //     onPressed: () {
          //       favoriteProvider.toggleFavorite(item);
          //     },
          //   ),
          // ),
          // Positioned favorite icon with an overlaid badge.
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue, // Badge background color
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              child: Center(
                child: Text(
                  physicalStock.toString(), // Display the physicalStock value
                  style: TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
