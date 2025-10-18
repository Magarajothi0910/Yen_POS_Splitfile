import 'dart:io';
import 'package:flutter/material.dart';

class PhotosScreen extends StatelessWidget {
  final List<String> imagePaths;

  const PhotosScreen({Key? key, required this.imagePaths}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final validImages = imagePaths
        .where((path) => path.isNotEmpty && File(path).existsSync())
        .toList();

    if (validImages.isEmpty) {
      return const Center(child: Text("No images available"));
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 240, 240, 240),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: validImages.map((path) {
            final file = File(path);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => _showMediumSizeImage(context, file),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMediumSizeImage(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
