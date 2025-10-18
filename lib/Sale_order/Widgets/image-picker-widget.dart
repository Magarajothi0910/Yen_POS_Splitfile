import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(File?, File?)?
      onImagesSelected; // Callback to return selected images

  const ImagePickerWidget({Key? key, this.onImagesSelected}) : super(key: key);

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _image1;
  File? _image2;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, int imageNumber) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (imageNumber == 1) {
            _image1 = File(pickedFile.path);
          } else {
            _image2 = File(pickedFile.path);
          }
        });

        // Notify parent widget when both images are picked
        if (widget.onImagesSelected != null) {
          widget.onImagesSelected!(_image1, _image2);
        }
      }
    } catch (e) {}
  }

  void _showImageSourceDialog(int imageNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, imageNumber);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, imageNumber);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // First Image
            Column(
              children: [
                GestureDetector(
                  onTap: () => _showImageSourceDialog(1),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _image1 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _image1!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate,
                            size: 25,
                            color: Colors.blue,
                          ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
            // Second Image

            Column(
              children: [
                GestureDetector(
                  onTap: () => _showImageSourceDialog(2),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _image2 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _image2!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate,
                            size: 25,
                            color: Colors.blue,
                          ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
