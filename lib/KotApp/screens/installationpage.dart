import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:hive/hive.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../screens/kot_screen/global/globals.dart';
import '../../server/Screen/serverScreen.dart';
import '../models/globals.dart';
import '../kotproviders/deviceProvider.dart';
import 'loginScreen.dart';
import 'serverScreen.dart';

class InstallKOTApp extends StatefulWidget {
  const InstallKOTApp({super.key});

  @override
  _InstallKOTAppState createState() => _InstallKOTAppState();
}

class _InstallKOTAppState extends State<InstallKOTApp> {
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false, // Removes all previous routes
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
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final mediaQuery = MediaQuery.of(context).size;
        return WillPopScope(
          onWillPop: () async {
            showExitConfirmationDialog();
            return false;
          },
          child: AlertDialog(
            title: const Text('Enter Device Code'),
            content: SingleChildScrollView(
              child: SizedBox(
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
                  var deviceCode = deviceCodeController.text;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) =>
                        false, // Removes all previous routes
                  ); //testing purpose
                  if (deviceCode.isNotEmpty && deviceCode.length == 12) {
                    await deviceProvider.fetchDeviceData(deviceCode);
                    if (deviceProvider.deviceData != null) {
                      Navigator.of(context).pop(); // Close dialog if valid
                      showConfirmationDialog(
                          deviceProvider.deviceData!['branchName']);
                    } else {
                      showSnackbar("Device not found or expired.");
                    }
                  } else {
                    showSnackbar("Please enter a valid 12-digit device code.");
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

  Future<void> showConfirmationDialog(String branch) async {
    if (!mounted) return;

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Branch Confirmation'),
          content: Text(
            'Are you part of the corresponding branch: $branch?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () async {
                final box = await Hive.openBox('deviceData');
                branchName = deviceProvider.deviceData!['branchName'];
                await box.put('branchName', branchName); // Store the branchName

                await deviceProvider.storeDeviceData(
                  deviceProvider.deviceData!['deviceCode'],
                  deviceProvider.deviceData!['branchName'],
                  deviceProvider.deviceData!['deviceCodeId'],
                );

                // Patch the status to 0 after storing device data
                await deviceProvider.patchDeviceStatus(
                    deviceProvider.deviceData!['deviceCodeId']);

                // Show server IP dialog
                // ignore: use_build_context_synchronously
                // await showServerIpDialog(
                //     context, deviceProvider.deviceData!['deviceCode']);

                // Validate branchName and serverip before navigating
                final storedBranchName = box.get('branchName');
                // final serverIpBox = await Hive.openBox('settings');
                // final storedServerIp = serverIpBox.get('serverip');

                if (storedBranchName != null && storedBranchName.isNotEmpty
                    // storedServerIp != null &&
                    // storedServerIp.isNotEmpty
                    ) {
                  if (mounted) {
                    Navigator.of(context).pop(); // Close confirmation dialog
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) =>
                          false, // Removes all previous routes
                    );
                  }
                } else {
                  showSnackbar(
                      "Branch Name or Server IP is not correctly set. Please try again.");
                }
              },
            ),
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
                showErrorDialog(
                        "Branch mismatch. Please enter the correct device code.")
                    .then((_) {
                  if (mounted) {
                    showDeviceCodeDialog();
                  }
                });
              },
            ),
          ],
        );
      },
    );
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
        backgroundColor: Color(0xFFFAF8F0),
        body: Stack(
          children: [
            LoginScreen(),
          ],
        ),
      ),
    );
  }
}
