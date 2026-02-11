import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int maxLines;
  final TextStyle? style; // Optional TextStyle parameter

  const CustomText({
    super.key,
    required this.text,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.style, // Initialize the style parameter
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ) ??
          TextStyle(
            color: color ?? Colors.black,
            fontSize: fontSize ?? 14.0,
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
