import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkText extends StatelessWidget {
  final String url;
  final String text;

  const LinkText({Key? key, required this.url, required this.text})
      : super(key: key);

  void _launchURL() async {
    if (!await launchUrl(Uri.parse(url))) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _launchURL,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue, // Set the color of the text
          decoration: TextDecoration.underline, // Underline the text
        ),
      ),
    );
  }
}
