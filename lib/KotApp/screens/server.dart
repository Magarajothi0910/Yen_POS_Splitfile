// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:server/main.dart';

// void main() {
//   runApp(const ServerApp());
// }

// class ServerApp extends StatelessWidget {
//   const ServerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       home: ServerScreen2(),
//     );
//   }
// }

// class ServerScreen2 extends StatefulWidget {
//   const ServerScreen2({super.key});

//   @override
//   _ServerScreen2State createState() => _ServerScreen2State();
// }

// class _ServerScreen2State extends State<ServerScreen2> {
//   String _data = 'Server is running';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Device B - Server'),
//       ),
//       body: Column(
//         children: [
//           ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => MyApp()),
//                 );
//               },
//               child: Text("Start"))
//           // Text(_data),
//         ],
//       ),
//     );
//   }

//   void handleRequest(HttpRequest request) async {
//     print("req..");
//     try {
//       if (request.method == 'POST' && request.uri.path == '/receive-data') {
//         // Get data from client request
//         var data = await utf8.decoder.bind(request).join();
//         var jsonData = jsonDecode(data);

//         // Process data (e.g., save to database)
//         print('Received data from client: $jsonData');

//         setState(() {
//           _data = jsonData["data"];
//         });

//         print("Updated data: $_data");

//         // Send response to client
//         var responseData = {'status': '$jsonData'};
//         request.response
//           ..statusCode = HttpStatus.ok
//           ..headers.contentType = ContentType.json
//           ..write(jsonEncode(responseData))
//           ..close();
//       } else {
//         request.response.statusCode = HttpStatus.notFound;
//         request.response.write('Not Found');
//         request.response.close();
//       }
//     } catch (e) {
//       print('Error handling request: $e');
//       request.response
//         ..statusCode = HttpStatus.internalServerError
//         ..write('Error handling request: $e')
//         ..close();
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     startServer();
//   }

//   Future<void> startServer() async {
//     final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
//     print('Server running on ${server.address}:${server.port}');

//     await for (var request in server) {
//       handleRequest(request);
//     }
//   }
// }
