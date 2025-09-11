// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';

// class AudioProvider with ChangeNotifier {
//   final AudioPlayer _player = AudioPlayer();
//   bool _isLoading = false;
//   String? _error;
//   String? _audioFilePath;
//   Uint8List? _audioData;

//   bool get isLoading => _isLoading;
//   String? get error => _error;
//   AudioPlayer get player => _player;
//   String? get audioFilePath => _audioFilePath;
//   Uint8List? get audioData => _audioData;

//   // Fetch audio data from the server
//   Future<void> fetchAudio(String customId) async {
//     _isLoading = true;
//     notifyListeners();

//     try {
//       final response = await http.get(Uri.parse(
//           'http://$ipAddress/audioOrder/media/$customId/audio'));

//       if (response.statusCode == 200) {
//         final audioData = json.decode(response.body);
//         _audioData = _hexToBytes(audioData['content']);

//         final tempDir = await getTemporaryDirectory();
//         final tempFile = File('${tempDir.path}/${audioData['filename']}');
//         await tempFile.writeAsBytes(_audioData!);

//         _audioFilePath = tempFile.path;
//         await _player.setFilePath(_audioFilePath!);
//       } else {
//         throw Exception('Failed to load audio');
//       }
//     } catch (e) {
//       _error = 'Error loading audio: $e';
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Convert hex string to bytes
//   List<int> _hexToBytes(String hex) {
//     var cleanHex = hex.replaceAll(' ', '');
//     var bytes = <int>[];
//     for (var i = 0; i < cleanHex.length; i += 2) {
//       bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
//     }
//     return bytes;
//   }

//   @override
//   void dispose() {
//     _player.dispose();
//     super.dispose();
//   }
// }
