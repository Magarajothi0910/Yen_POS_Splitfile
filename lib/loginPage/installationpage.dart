import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Widgets/top_message.dart';
import 'package:yenpos/Server_Client/serverScreen.dart';

import 'provider/deviceProvider.dart';

class InstallPOSApp extends StatefulWidget {

  const InstallPOSApp({super.key, });
  @override
  _InstallKOTAppState createState() => _InstallKOTAppState();
}

class _InstallKOTAppState extends State<InstallPOSApp> {
  Map<String, dynamic>? deviceData;

  late DeviceProvider deviceProvider;
  @override
  void initState() {
    super.initState();
    checkForStoredDeviceCode();
  }

  Future<void> checkForStoredDeviceCode() async {

    try {
      var box = await Hive.openBox('deviceData');

      final storedDeviceCode = box.get('deviceCode');

      if (storedDeviceCode != null && storedDeviceCode.isNotEmpty) {
        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
      } else {
        if (!mounted) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDeviceCodeDialog();
        });
      }
    } catch (e, stackTrace) {
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

        return WillPopScope(
          onWillPop: () async {
            showExitConfirmationDialog();
            return false;
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            // ↓ Decrease inset padding so dialog uses more screen space
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 40,
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, scale, _) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      // ↓ Increased width for larger display
                      width: mediaQuery.width > 900
                          ? 700
                          : mediaQuery.width > 600
                          ? 550
                          : mediaQuery.width * 0.9,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.97),
                            Colors.blueGrey.shade50.withOpacity(0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 25,
                            spreadRadius: 3,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            '🔐 Enter Device Code',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey.shade900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Please enter your 12-digit device code to continue setup.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Pin Code Field
                          PinCodeTextField(
                            appContext: context,
                            length: 12,
                            obscureText: false,
                            animationType: AnimationType.fade,
                            controller: deviceCodeController,
                            autoDismissKeyboard: true,
                            cursorColor: Colors.blueAccent,
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(14),
                              fieldHeight: mediaQuery.width > 600 ? 60 : 48,
                              fieldWidth: mediaQuery.width > 600 ? 45 : 30,
                              activeColor: Colors.blueAccent,
                              inactiveColor: Colors.grey.shade300,
                              selectedColor: Colors.blueAccent,
                              activeFillColor: Colors.white,
                              selectedFillColor: Colors.blue.shade50,
                              inactiveFillColor: Colors.grey.shade100,
                              borderWidth: 1.6,
                            ),
                            animationDuration: const Duration(
                              milliseconds: 250,
                            ),
                            backgroundColor: Colors.transparent,
                            enableActiveFill: true,
                            onChanged: (value) {},
                          ),

                          const SizedBox(height: 40),

                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  showExitConfirmationDialog();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  final code = deviceCodeController.text;
                                  if (code.length == 12) {
                                    await fetchDeviceData(code);
                                    if (context.mounted)
                                      Navigator.of(context).pop();
                                  } else {
                                    if (context.mounted) {
                                      showSnackbar(
                                        "Please enter a valid 12-digit device code.",
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Verify',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> fetchDeviceData(String deviceCode) async {
    const url = 'https://yenerp.com/fastapi/devicecode/';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> devices = data;
        final device = devices.firstWhere(
          (device) => device['deviceCode'] == deviceCode,
          orElse: () => null,
        );

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
            "Failed to fetch device data. Status code: ${response.statusCode}",
          );
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
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: "Branch Confirmation",
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation1, animation2) =>
            const SizedBox.shrink(),
        transitionBuilder: (context, anim, secondary, child) {
          final curved = Curves.easeOutBack.transform(anim.value);
          return Transform.scale(
            scale: curved,
            child: Opacity(
              opacity: anim.value,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width > 600
                      ? 480
                      : MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.95),
                        Colors.blueGrey.shade50.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.7),
                              Colors.lightBlueAccent.withOpacity(0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Confirm Your Branch",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you part of the branch:\n"$branchName"?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            label: const Text("Yes"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 6,
                              shadowColor: Colors.blueAccent.withOpacity(0.4),
                            ),
                            onPressed: () async {
                              final deviceProvider =
                                  Provider.of<DeviceProvider>(
                                    context,
                                    listen: false,
                                  );
                              try {

                                globals.aliasname = deviceData!['branchName'];
                                // Store the device data
                                await deviceProvider.storeDeviceData(
                                  deviceData!['deviceCode'],
                                  deviceData!['branchName'],
                                  deviceData!['deviceCodeId'],
                                );

                                // Close dialog
                                if (mounted) Navigator.of(context).pop();

                                // Show success SnackBar
                                if (mounted) {
                                  TopMessage.show(
                                    context,
                                    message: "Branch confirmed successfully!",
                                    backgroundColor: Colors.green.shade600,
                                  );
                                }
                              } catch (e) {
                                // Optional: handle error
                                if (mounted) {
                                  TopMessage.show(
                                    context,
                                    message: "Failed to confirm branch.",
                                    backgroundColor: Colors.green.shade600,
                                  );
                                }
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.redAccent,
                            ),
                            label: const Text("No"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              if (mounted) {
                                Navigator.of(context).pop();
                                showErrorDialog(
                                  "Branch mismatch. Please enter the correct device code.",
                                ).then((_) {
                                  if (mounted) showDeviceCodeDialog();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> showExitConfirmationDialog() async {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Exit App",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondary, child) {
        final curved = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curved,
          child: Opacity(
            opacity: anim.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.97),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.exit_to_app_rounded,
                      size: 48,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exit Application',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Are you sure you want to close the application?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (mounted) Navigator.of(context).maybePop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            "Exit",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showErrorDialog(String message) async {
    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Error",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondary, child) {
        final curved = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curved,
          child: Opacity(
            opacity: anim.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Error",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          Navigator.of(context).pop();
                          showDeviceCodeDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        elevation: 3,
                      ),
                      child: const Text(
                        "OK",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        body: Stack(children: [LoginScreen()]),
      ),
    );
  }
}
