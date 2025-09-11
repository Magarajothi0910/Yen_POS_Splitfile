import 'package:flutter/material.dart';

class FullScreenCarousel extends StatelessWidget {
  const FullScreenCarousel({Key? key}) : super(key: key);

  // List of image paths or network URLs. Adjust these to your assets.
  final List<String> images = const [
    'assets/bestmummy.png',
    'assets/bestmummy123.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            return Center(
              child: Image.asset(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),
      ),
    );
  }
}
