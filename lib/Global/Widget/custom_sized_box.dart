import 'package:flutter/material.dart';

class CustomSizedBox extends StatelessWidget {
  final double? height;
  final double? width;
  final Widget? child; // Optional child
  final bool shrink; // Optional shrink parameter

  const CustomSizedBox({
    super.key,
    this.height,
    this.width,
    this.child,
    this.shrink = false, // Default to false (not shrunk)
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: shrink ? 0 : height, // Shrink height to 0 if shrink is true
      width: shrink ? 0 : width, // Shrink width to 0 if shrink is true
      child: child, // Optional child
    );
  }
}
