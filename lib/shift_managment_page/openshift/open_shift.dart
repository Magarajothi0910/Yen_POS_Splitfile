import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Mode_page/choose_mode_screen.dart';
import 'package:yenpos/Sale_order/Widgets/customd_keyboard.dart';

import 'dart:convert';

import 'package:yenpos/more_page/providers/cash_management_provider.dart';

class OpenShift extends StatefulWidget {
  const OpenShift({super.key});

  @override
  State<OpenShift> createState() => _OpenShiftState();
}

class _OpenShiftState extends State<OpenShift> {
  // Constant actual opening cash
  static const int actualOpeningCash = 3000;
  final ValueNotifier<ConnectivityResult> _connectivityResult = ValueNotifier(
    ConnectivityResult.none,
  );

  // system opening cash
  final ValueNotifier<int> systemOpeningBalance = ValueNotifier(0);

  // shift status
  final ValueNotifier<bool> isShiftOpened = ValueNotifier(false);

  // Date/Time
  final ValueNotifier<String> currentDate = ValueNotifier("");
  final ValueNotifier<String> currentTime = ValueNotifier("");

  // denomination controllers & totals
  final Map<int, TextEditingController> _controllers = {
    500: TextEditingController(),
    200: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
    5: TextEditingController(),
    2: TextEditingController(),
    1: TextEditingController(),
  };

  final ValueNotifier<Map<int, int>> denominationTotals =
      ValueNotifier<Map<int, int>>({});

  // NEW: Global full-screen loading state
  bool _isFullScreenLoading = false;

  // NEW: Disable main button while processing
  bool _isMainButtonDisabled = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentDateTime();
    CashManagementProvider.fetchValidationDetails();
    CashManagementProvider.fetchShiftDetails();
    CashManagementProvider.fetchShiftOpenCheck();
    denominationTotals.value = {for (var d in _controllers.keys) d: 0};
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityResult.value = result.first;
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _connectivityResult.value = result.first;
  }

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<void> _fetchCurrentDateTime() async {
    final url = 'https://yenerp.com/liveapi/datetime';
    final response = await _dio.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.data);
      currentDate.value = data["current_date"];
      currentTime.value = data["current_time"];
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch date and time.')),
        );
      }
    }
  }

  int _calculateGrandTotal() {
    return denominationTotals.value.values.fold(0, (a, b) => a + b);
  }

  int _calculateDifference(int physicalCash) {
    return physicalCash - actualOpeningCash;
  }

  // Modified to show full-screen loading
  Future<void> _postShiftData(int physicalCash) async {
    final url = "https://yenerp.com/fluttertestapi/shifts/";

    final openingDifferenceAmount = _calculateDifference(physicalCash);
    final openingDifferenceType = openingDifferenceAmount > 0
        ? "excess"
        : (openingDifferenceAmount < 0 ? "shortage" : "no difference");

    final payload = {
      // "shiftNumber": "1",
      "systemOpeningBalance": actualOpeningCash,
      "manualOpeningBalance": physicalCash,
      "openingDifferenceAmount": openingDifferenceAmount,
      "openingDifferenceType": openingDifferenceType,
      "systemClosingBalance": actualOpeningCash,
      "dayEndStatus": "open",
      "status": "open",
      "branchId": "1",
      "branchName": branchName,
      "empId": userName,
      "empName": userName,
      "deviceId": "2",
      "deviceNumber": "1",
    };

    try {
      setState(() {
        _isFullScreenLoading = true;
      });

      final response = await _dio.post(url, data: jsonEncode(payload));

      if (response.statusCode == 200 || response.statusCode == 300) {
        dynamic shiftId;
        dynamic shiftNumber;
        if (response.data is String) {
          shiftId = response.data;
        } else if (response.data is Map<String, dynamic>) {
          shiftId = response.data['shiftId'] ?? response.data['shiftId'];
          shiftNumber =
              response.data['shiftNumber'] ?? response.data['shiftNumber'];
        }

        globals.shiftId.value = shiftId?.toString() ?? '';
        globals.shiftNumber.value = shiftNumber;
        systemOpeningBalance.value = physicalCash;
        isShiftOpened.value = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift created successfully!')),
          );
          // Navigate after success
          // _navigateToChooseMode(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed. Error: ${response.statusCode}')),
          );
        }
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exception: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFullScreenLoading = false;
          _isMainButtonDisabled = false;
        });
      }
    }
  }

  Future<bool> hasRealInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return false;

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 6));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<CashManagementProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: isShiftOpened,
                  builder: (context, opened, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (opened) _buildOpeningCashDetails(),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<ConnectivityResult>(
                          valueListenable: _connectivityResult,
                          builder: (context, connectivity, __) {
                            final isConnected =
                                connectivity != ConnectivityResult.none;

                            return ValueListenableBuilder<String>(
                              valueListenable: shiftOpenStatus,
                              builder: (context, shiftStatus, _) {
                                return IgnorePointer(
                                  ignoring:
                                      prov.isLoading || _isMainButtonDisabled,
                                  child: OutlinedButton(
                                    onPressed: _isMainButtonDisabled
                                        ? null
                                        : isConnected
                                        ? () async {
                                            setState(() {
                                              _isMainButtonDisabled = true;
                                            });

                                            final bool hasInternet =
                                                await hasRealInternetConnection();
                                            if (!hasInternet) {
                                              _showNoInternetDialog(context);
                                              setState(
                                                () => _isMainButtonDisabled =
                                                    false,
                                              );
                                              return;
                                            }

                                            await CashManagementProvider.fetchShiftOpenCheck();
                                            if (shiftStatus == "open") {
                                              _showShiftAlreadyOpenDialog(
                                                context,
                                              );
                                              setState(
                                                () => _isMainButtonDisabled =
                                                    false,
                                              );
                                              return;
                                            }

                                            if (!opened) {
                                              _showShiftDialog(context);
                                            } else {
                                              _navigateToChooseMode(context);
                                            }

                                            // Re-enable if no dialog was shown
                                            if (mounted) {
                                              setState(
                                                () => _isMainButtonDisabled =
                                                    false,
                                              );
                                            }
                                          }
                                        : () {
                                            _showNoNetworkDialog(context);
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 60,
                                        vertical: 25,
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      disabledForegroundColor: Colors.grey,
                                    ),
                                    child: Text(
                                      opened
                                          ? 'Good Day to Start'
                                          : 'Open The Shift',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // Full-screen loading overlay
          if (_isFullScreenLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpeningCashDetails() {
    return ValueListenableBuilder<int>(
      valueListenable: systemOpeningBalance,
      builder: (context, physicalCash, _) {
        final difference = _calculateDifference(physicalCash);
        return Column(
          children: [
            Text(
              'Actual Opening Cash: $actualOpeningCash',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Physical Opening Cash: $physicalCash',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Difference: $difference',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: difference >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showShiftDialog(BuildContext context) {
    final List<FocusNode> focusNodes = _controllers.keys
        .map((_) => FocusNode())
        .toList();
    final currentFocusIndexNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      builder: (_) {
        return ValueListenableBuilder<int>(
          valueListenable: currentFocusIndexNotifier,
          builder: (context, currentFocusIndex, _) {
            void moveToNextField() {
              if (currentFocusIndex < _controllers.keys.length - 1) {
                currentFocusIndexNotifier.value++;
                focusNodes[currentFocusIndexNotifier.value].requestFocus();
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(
                      child: Text(
                        'Denomination',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ValueListenableBuilder<Map<int, int>>(
                            valueListenable: denominationTotals,
                            builder: (context, totals, _) {
                              return Container(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: const [
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              'Cash',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              'Count',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              'Total',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(thickness: 2),
                                    ..._controllers.keys.toList().asMap().entries.map((
                                      entry,
                                    ) {
                                      final index = entry.key;
                                      final denom = entry.value;
                                      final controller = _controllers[denom]!;
                                      final focusNode = focusNodes[index];

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  '$denom',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: TextField(
                                                  focusNode: focusNode,
                                                  controller: controller,
                                                  keyboardType:
                                                      TextInputType.none,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 16,
                                                    color:
                                                        currentFocusIndex ==
                                                            index
                                                        ? Colors.blue
                                                        : Colors.black,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 7,
                                                          horizontal: 6,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            currentFocusIndex ==
                                                                index
                                                            ? Colors.blue
                                                            : Colors.grey,
                                                        width:
                                                            currentFocusIndex ==
                                                                index
                                                            ? 2.0
                                                            : 1.0,
                                                      ),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            currentFocusIndex ==
                                                                index
                                                            ? Colors.blue
                                                            : Colors.grey,
                                                        width:
                                                            currentFocusIndex ==
                                                                index
                                                            ? 2.0
                                                            : 1.0,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                                color:
                                                                    Colors.blue,
                                                                width: 2.0,
                                                              ),
                                                        ),
                                                    fillColor:
                                                        currentFocusIndex ==
                                                            index
                                                        ? Colors.blue
                                                              .withOpacity(0.1)
                                                        : Colors.white,
                                                    filled: true,
                                                  ),
                                                  onTap: () =>
                                                      currentFocusIndexNotifier
                                                              .value =
                                                          index,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  '${totals[denom] ?? 0}',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    const Divider(thickness: 2),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Grand Total: ',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${_calculateGrandTotal()}',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const VerticalDivider(width: 20, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    child: NumericKeyboard(
                                      focusNode: focusNodes[currentFocusIndex],
                                      controller:
                                          _controllers[_controllers.keys
                                              .toList()[currentFocusIndex]]!,
                                      onTextInput: (text) {
                                        final ctrl =
                                            _controllers[_controllers.keys
                                                .toList()[currentFocusIndex]]!;
                                        ctrl.text += text;
                                        _updateTotals();
                                      },
                                      onBackspace: () {
                                        final ctrl =
                                            _controllers[_controllers.keys
                                                .toList()[currentFocusIndex]]!;
                                        if (ctrl.text.isNotEmpty) {
                                          ctrl.text = ctrl.text.substring(
                                            0,
                                            ctrl.text.length - 1,
                                          );
                                          _updateTotals();
                                        }
                                      },
                                      onOk: moveToNextField,
                                      isLastField:
                                          currentFocusIndex ==
                                          _controllers.keys.length - 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: 280,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () async {
                                          final confirm =
                                              await _showConfirmationDialog(
                                                context: context,
                                                title: 'Cancel Denomination',
                                                content:
                                                    'Are you sure you want to cancel? Any changes will be lost.',
                                                confirmText: 'Yes, Cancel',
                                                cancelText: 'No, Continue',
                                              );
                                          if (confirm == true &&
                                              context.mounted)
                                            Navigator.pop(context);
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.redAccent
                                              .withOpacity(0.1),
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () async {
                                          final confirm =
                                              await _showConfirmationDialog(
                                                context: context,
                                                title:
                                                    'Clear All Denominations',
                                                content:
                                                    'Are you sure you want to clear all denomination counts?',
                                                confirmText: 'Yes, Clear',
                                                cancelText: 'No, Keep',
                                              );
                                          if (confirm == true &&
                                              context.mounted)
                                            _clearControllers();
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent
                                              .withOpacity(0.1),
                                          foregroundColor: Colors.orangeAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'All Clear',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: 280,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () async {
                                          final confirm = await _showConfirmationDialog(
                                            context: context,
                                            title:
                                                'Save Denomination & Open Shift',
                                            content:
                                                'Are you sure you want to Open Shift with the denomination Values?',
                                            confirmText: 'Yes, Open Shift',
                                            cancelText: 'No, Edit',
                                          );

                                          if (confirm == true &&
                                              context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // Close dialog
                                            await _postShiftData(
                                              _calculateGrandTotal(),
                                            ); // This triggers full-screen loading
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.blueAccent
                                              .withOpacity(0.1),
                                          foregroundColor: Colors.blueAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Save',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _clearControllers() {
    for (var controller in _controllers.values) controller.clear();
    _updateTotals();
  }

  void _updateTotals() {
    final newTotals = <int, int>{};
    for (var denom in _controllers.keys) {
      final count = int.tryParse(_controllers[denom]!.text) ?? 0;
      newTotals[denom] = denom * count;
    }
    denominationTotals.value = newTotals;
  }

  Future<bool?> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(child: Text(title)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChooseMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChooseModePage()),
    );
  }

  // Extracted dialog methods to avoid duplication
  void _showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Please check your internet connection and try again.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoNetworkDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'Network Error',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'No internet connection. Please check your network.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShiftAlreadyOpenDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.blueAccent,
                  size: 40,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'Shift Already Opened',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'This employee already has a shift opened.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
}
