import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/favorite_page_provider.dart';
import 'my_grid_view.dart';

class FavoritePageWidget extends StatelessWidget {
  const FavoritePageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    final favoriteItems = favoriteProvider.favoriteItems.take(20).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: favoriteItems.isNotEmpty
          ? MyGridView(items: favoriteItems)
          : const Center(
              child: Text(
                'No favorite items found.',
                style: TextStyle(fontSize: 18),
              ),
            ),
    );
  }
}
