import 'package:flutter/material.dart';

class GridViewUI extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
      itemBuilder;
  final Function(Map<String, dynamic> item)? onTap;

  const GridViewUI({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => onTap != null ? onTap!(item) : null,
          child: itemBuilder(context, item),
        );
      },
    );
  }
}

class GridCakeViewUI extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
      itemBuilder;
  final Function(Map<String, dynamic> item)? onTap;

  const GridCakeViewUI({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => onTap != null ? onTap!(item) : null,
          child: itemBuilder(context, item),
        );
      },
    );
  }
}
