import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'login_page.dart';
import 'provider/deviceProvider.dart';

class InstallPOSApp extends StatefulWidget {
  @override
  _InstallKOTAppState createState() => _InstallKOTAppState();
}

class _InstallKOTAppState extends State<InstallPOSApp> {
  Map<String, dynamic>? deviceData;
  final GlobalKey keyboardKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    checkForStoredDeviceCode();
  }

  Future<void> checkForStoredDeviceCode() async {
    var box = await Hive.openBox('deviceData');
    final storedDeviceCode = box.get('deviceCode');
    if (storedDeviceCode != null && storedDeviceCode.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogInScreen(
            keyboardKey: keyboardKey,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDeviceCodeDialog();
      });
    }
  }

  Future<void> showDeviceCodeDialog() async {
    if (!mounted) return;

    final TextEditingController deviceCodeController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final mediaQuery = MediaQuery.of(context).size;
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: () async {
            showExitConfirmationDialog();
            return false;
          },
          child: AlertDialog(
            title: const Text('Enter Device Code'),
            content: SingleChildScrollView(
              child: Container(
                width: mediaQuery.width * 0.8,
                child: PinCodeTextField(
                  appContext: context,
                  length: 12,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(4),
                    fieldHeight: mediaQuery.width > 600 ? 50 : 40,
                    fieldWidth: mediaQuery.width > 600 ? 50 : 19,
                    activeFillColor: Colors.white,
                    selectedFillColor: Colors.grey.shade200,
                    inactiveFillColor: Colors.grey.shade300,
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  backgroundColor: Colors.transparent,
                  enableActiveFill: true,
                  controller: deviceCodeController,
                  autoDismissKeyboard: true,
                  onChanged: (value) {},
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Submit'),
                onPressed: () async {
                  final deviceCode = deviceCodeController.text;
                  if (deviceCode.isNotEmpty && deviceCode.length == 12) {
                    if (!mounted) return;
                    await fetchDeviceData(deviceCode);
                    if (mounted) {
                      Navigator.of(context).pop(); // Close the dialog
                    }
                  } else {
                    if (mounted) {
                      showSnackbar(
                          "Please enter a valid 12-digit device code.");
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    ).then((_) {
      deviceCodeController.dispose();
    });
  }

  Future<void> fetchDeviceData(String deviceCode) async {
    const url = 'https://yenerp.com/fastapi/devicecodes';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> devices = data;
        final device = devices.firstWhere(
            (device) => device['deviceCode'] == deviceCode,
            orElse: () => null);

        if (device != null) {
          setState(() {
            deviceData = device;
          });

          if (device['status'] == '1') {
            if (!mounted) return;
            showConfirmationDialog(device['branchName']);
          } else {
            if (mounted) {
              showSnackbar("Device code is expired.");
            }
          }
        } else {
          if (mounted) {
            showSnackbar("Device not found.");
          }
        }
      } else {
        if (mounted) {
          showSnackbar(
              "Failed to fetch device data. Status code: ${response.statusCode}");
        }
      }
    } catch (error) {
      if (mounted) {
        showSnackbar("Failed to fetch device data.");
      }
    }
  }

  Future<void> showConfirmationDialog(String branchName) async {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Branch Confirmation'),
            content: Text(
              'Are you part of the corresponding branch: $branchName?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Yes'),
                onPressed: () async {
                  final deviceProvider =
                      Provider.of<DeviceProvider>(context, listen: false);
                  await deviceProvider.storeDeviceData(
                      deviceData!['deviceCode'],
                      deviceData!['branchName'],
                      deviceData!['deviceCodeId']);
                  // ignore: use_build_context_synchronously

                  if (mounted) {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LogInScreen(
                          keyboardKey: keyboardKey,
                        ),
                      ),
                    );
                  }
                },
              ),
              TextButton(
                child: const Text('No'),
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop();
                    showErrorDialog(
                            "Branch mismatch. Please enter the correct device code.")
                        .then((_) {
                      if (mounted) {
                        showDeviceCodeDialog();
                      }
                    });
                  }
                },
              ),
            ],
          );
        },
      );
    });
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> showExitConfirmationDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Application'),
          content: const Text('Are you sure you want to exit the application?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showErrorDialog(String message) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                  showDeviceCodeDialog();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        showExitConfirmationDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F0),
        body: Stack(
          children: [
            LogInScreen(
              keyboardKey: keyboardKey,
            ),
          ],
        ),
      ),
    );
  }
}
