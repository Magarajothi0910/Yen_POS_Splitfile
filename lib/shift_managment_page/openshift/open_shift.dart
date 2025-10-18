import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Global/globals_data.dart' as globals;
import 'package:yenposapp/Mode_page/choose_mode_screen.dart';
import 'package:yenposapp/Sale_order/Widgets/customd_keyboard.dart';

import 'dart:convert';

import 'package:yenposapp/more_page/providers/cash_management_provider.dart';

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

  // system opening cash (initially 0, will be set to physical cash after shift is saved)
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

  @override
  void initState() {
    super.initState();
    _fetchCurrentDateTime();
    CashManagementProvider.fetchValidationDetails();
    CashManagementProvider.fetchShiftDetails();
    CashManagementProvider.fetchShiftOpenCheck();
    // initialize totals
    denominationTotals.value = {for (var d in _controllers.keys) d: 0};
    _checkConnectivity();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityResult.value =
          result.first; // Handle Stream<List<ConnectivityResult>>
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _connectivityResult.value = result.first;
  }

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // fetch current date/time from API
  Future<void> _fetchCurrentDateTime() async {
  try {
    final url = 'https://yenerp.com/liveapi/datetime';
    final response = await _dio.get(url);

    if (response.statusCode == 200) {
      final rawData = response.data;
      final data = rawData is String ? jsonDecode(rawData) : rawData;

      currentDate.value = data["current_date"];
      currentTime.value = data["current_time"];
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch date and time.')),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching date/time: $e')),
      );
    }
  }
}
  // calculate total from denominations
  int _calculateGrandTotal() {
    return denominationTotals.value.values.fold(0, (a, b) => a + b);
  }

  // calculate difference: Actual − Physical
  int _calculateDifference(int physicalCash) {
    return physicalCash - actualOpeningCash;
  }

  // post shift data

  Future<void> _postShiftData(int physicalCash) async {
    final url = "https://yenerp.com/fastapi/shifts/";
    debugPrint('🔗 Posting to URL: $url');

    final openingDifferenceAmount = _calculateDifference(physicalCash);
    final openingDifferenceType = openingDifferenceAmount > 0
        ? "excess"
        : (openingDifferenceAmount < 0 ? "shortage" : "no difference");

    final payload = {
      "shiftNumber": "1",
      "shiftOpeningDate": currentDate.value,
      "shiftOpeningTime": currentTime.value,
      "systemOpeningBalance": actualOpeningCash.toString(),
      "manualOpeningBalance": physicalCash.toString(),
      "openingDifferenceAmount": openingDifferenceAmount.toString(),
      "openingDifferenceType": openingDifferenceType,
      "systemClosingBalance": actualOpeningCash.toString(),
      "manualClosingBalance": '',
      "dayEndStatus": "open",
      "status": "open",
      "branchId": "1",
      "branchName": branchName,
      "empId": "1234",
      "empName": empId,
      "deviceId": "2",
      "deviceNumber": "1",
    };

    debugPrint('➡ Payload being sent: ${jsonEncode(payload)}');

    try {
      final response = await _dio.post(url, data: jsonEncode(payload));

      debugPrint('⬅ Response received — Status: ${response.statusCode}');
      debugPrint('⬅ Response body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 300) {
        // ✅ Safe extraction of shiftId
        dynamic shiftId;
        if (response.data is String) {
          shiftId = response.data;
        } else if (response.data is Map<String, dynamic>) {
          shiftId = response.data['id'] ?? response.data['_id'];
        }

        debugPrint('✅ Shift ID returned: $shiftId');

        globals.shiftId.value = shiftId?.toString() ?? '';
        systemOpeningBalance.value = physicalCash;
        isShiftOpened.value = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift created successfully!')),
          );
        }
      } else {
        debugPrint('⚠️ Posting failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed. Error: ${response.statusCode}')),
          );
        }
      }
    } catch (e, st) {
      debugPrint('❌ Exception during POST: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exception: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
                            return OutlinedButton(
                              onPressed: isConnected
                                  ? () async {
                                      await CashManagementProvider
                                          .fetchShiftOpenCheck();
                                      if (shiftStatus == "open") {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (context) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            elevation: 10,
                                            backgroundColor: Colors.transparent,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white,
                                                    Colors.grey.shade100,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                                  // Optional Premium Icon
                                                  Container(
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent
                                                          .withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.blueAccent,
                                                      size: 40,
                                                    ),
                                                  ),
                                                  SizedBox(height: 15),
                                                  // Title
                                                  Text(
                                                    'Shift Already Opened',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                      letterSpacing: 0.5,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 10),
                                                  // Content
                                                  Text(
                                                    'This employee already has a shift opened.',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black54,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 20),
                                                  // Action Button
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.blueAccent,
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          vertical: 14,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            12,
                                                          ),
                                                        ),
                                                        elevation: 5,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        context,
                                                      ),
                                                      child: Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      // original logic
                                      if (!opened) {
                                        _showShiftDialog(context);
                                      } else {
                                        _navigateToChooseMode(context);
                                      }
                                    }
                                  : () {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (context) => Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          elevation: 10,
                                          backgroundColor: Colors.transparent,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  Colors.grey.shade100,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                                // Network Icon
                                                Container(
                                                  padding: EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.wifi_off_rounded,
                                                    color: Colors.redAccent,
                                                    size: 40,
                                                  ),
                                                ),
                                                SizedBox(height: 15),
                                                // Title
                                                Text(
                                                  'Network Error',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                    letterSpacing: 0.5,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                SizedBox(height: 10),
                                                // Content
                                                Text(
                                                  'No internet connection. Please check your network.',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black54,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                SizedBox(height: 20),
                                                // Action Button
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          12,
                                                        ),
                                                      ),
                                                      elevation: 5,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(
                                                      'OK',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 60,
                                  vertical: 25,
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                disabledForegroundColor: Colors.grey,
                              ),
                              child: Text(
                                opened ? 'Good Day to Start' : 'Open The Shift',
                                style: const TextStyle(
                                  fontSize: 20,
                                  letterSpacing: 1,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Visibility(
                      visible: !opened,
                      child: OutlinedButton(
                        onPressed: () async {
                          final ValidationData = {
                            "branchName": branchName,
                            // Add other necessary fields
                          };
                          // await CashManagementProvider.postValidationData(
                          //     ValidationData, context);
                          await CashManagementProvider.fetchValidationDetails();
                          await CashManagementProvider.fetchShiftDetails();
                          await CashManagementProvider.fetchShiftOpenCheck();

                          final status = globals.status.value;
                          final dayEndStatus = globals.dayEndStatus.value;
                          final connectivity = _connectivityResult.value;
                          final dispatch = dispatchStatus.value;
                          final itemTransfer = itemTransferStatus.value;
                          final soApproval = soApprovalStatus.value;
                          final store = storeStatus.value;
                          final soDelivery = soDeliveryStatus.value;

                          final isConnected =
                              connectivity != ConnectivityResult.none;
                          final isDayOpen = status == "open";
                          final isDispatchApproved =
                              dispatch.isEmpty || dispatch == "success";
                          final isItemTransferApproved =
                              itemTransfer.isEmpty || itemTransfer == "success";
                          final isSoApprovalApproved =
                              soApproval.isEmpty || soApproval == "success";
                          final isStoreApproved =
                              store.isEmpty || store == "success";
                          final isSoDeliveryApproved =
                              soDelivery.isEmpty || soDelivery == "success";

                          debugPrint(
                            "Status: $status, DayEndStatus: $dayEndStatus, Connected: $isConnected, DispatchStatus: $dispatch, ItemTransfer: $itemTransfer, SoApproval: $soApproval, Store: $store, SoDelivery: $soDelivery",
                          );

                          void showPremiumDialog({
                            required BuildContext context,
                            required String title,
                            required Widget content,
                            Color accentColor =
                                Colors.blueAccent, // default accent
                            IconData? icon, // optional icon
                          }) {
                            showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 10,
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.grey.shade100,
                                      ],
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
                                      if (icon != null) ...[
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: accentColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            icon,
                                            color: accentColor,
                                            size: 40,
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                      ],
                                      // Title
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          letterSpacing: 0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 10),
                                      // Content
                                      content,
                                      SizedBox(height: 20),
                                      // Action Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentColor,
                                            padding: EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 5,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            'OK',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
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

                          if (isDayOpen) {
                            showPremiumDialog(
                              context: context,
                              title: 'Warning',
                              content: const Text(
                                'Shift is not closed yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.orangeAccent,
                              icon: Icons.warning_amber_rounded,
                            );
                            return;
                          }

                          if (!isConnected) {
                            showPremiumDialog(
                              context: context,
                              title: 'Network Error',
                              content: const Text(
                                'No internet connection. Please check your network.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.wifi_off_rounded,
                            );
                            return;
                          }

                          if (!isDispatchApproved && dispatch.isNotEmpty) {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Some dispatches are not received yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          if (!isItemTransferApproved &&
                              itemTransfer.isNotEmpty) {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Some item transfers are not received yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          if (!isSoApprovalApproved && soApproval.isNotEmpty) {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Some Sale Order approvals are pending.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          if (!isStoreApproved && store.isNotEmpty) {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Store Dispatch is not received.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          if (!isSoDeliveryApproved && soDelivery.isNotEmpty) {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Some Sale Orders are not Delivered or pending.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          if (dayEndStatus.isEmpty ||
                              dayEndStatus == "closed") {
                            showPremiumDialog(
                              context: context,
                              title: 'Error',
                              content: const Text(
                                'Cannot end day: No open shift available',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              accentColor: Colors.redAccent,
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Center(
                                child: Text('Confirm Day End'),
                              ),
                              content: const Text(
                                'Are you sure you want to end the day?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      CashManagementProvider
                                          .fetchShiftDetails();
                                      final dayEndPost = {
                                        "branchName": branchName,
                                        // Add other necessary fields
                                      };
                                      await CashManagementProvider
                                          .postDayEndData(
                                        dayEndPost,
                                        context,
                                      );
                                      await CashManagementProvider
                                          .fetchShiftDetails();

                                      if (context.mounted) {
                                        Navigator.pop(
                                          context,
                                        ); // close any loading dialogs

                                        showPremiumDialog(
                                          context: context,
                                          title: 'Success',
                                          content: const Text(
                                            'Day End completed successfully.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 16,
                                            ),
                                          ),
                                          accentColor: Colors.green,
                                          icon: Icons.check_circle_outline,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Navigator.pop(context);

                                        showPremiumDialog(
                                          context: context,
                                          title: 'Error',
                                          content: Text(
                                            'Day End failed: $e',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 16,
                                            ),
                                          ),
                                          accentColor: Colors.redAccent,
                                          icon: Icons.error_outline,
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Confirm',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 25,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledForegroundColor: Colors.grey,
                        ),
                        child: const Text(
                          "Day End",
                          style: TextStyle(fontSize: 20, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Physical Opening Cash: $physicalCash',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Difference: $difference',
              style: TextStyle(
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
    final List<FocusNode> focusNodes =
        _controllers.keys.map((_) => FocusNode()).toList();
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
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Main content row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Denomination table (left side)
                        Expanded(
                          flex: 3,
                          child: ValueListenableBuilder<Map<int, int>>(
                            valueListenable: denominationTotals,
                            builder: (context, totals, _) {
                              return Container(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  children: [
                                    // Header
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: const [
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              'Cash',
                                              style: TextStyle(
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
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(thickness: 2),
                                    // Denomination rows
                                    ..._controllers.keys
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((
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
                                                  style: const TextStyle(
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
                                                    fontSize: 16,
                                                    color: currentFocusIndex ==
                                                            index
                                                        ? Colors.blue
                                                        : Colors.black,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
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
                                                    enabledBorder:
                                                        OutlineInputBorder(
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
                                                      borderSide: BorderSide(
                                                        color: Colors.blue,
                                                        width: 2.0,
                                                      ),
                                                    ),
                                                    fillColor:
                                                        currentFocusIndex ==
                                                                index
                                                            ? Colors.blue
                                                                .withOpacity(
                                                                    0.1)
                                                            : Colors.white,
                                                    filled: true,
                                                  ),
                                                  onTap: () {
                                                    currentFocusIndexNotifier
                                                        .value = index;
                                                  },
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  '${totals[denom] ?? 0}',
                                                  style: const TextStyle(
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
                                    // Grand total
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
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${_calculateGrandTotal()}',
                                            style: const TextStyle(
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

                        // Vertical divider
                        const VerticalDivider(width: 20, thickness: 1),

                        // Right side column (keyboard + buttons)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // Custom keyboard
                              Column(
                                children: [
                                  // const Text(
                                  //   'Numeric Keyboard',
                                  //   style: TextStyle(
                                  //       fontWeight: FontWeight.bold,
                                  //       fontSize: 16),
                                  // ),
                                  const SizedBox(height: 10),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    child: NumericKeyboard(
                                      focusNode: focusNodes[currentFocusIndex],
                                      controller: _controllers[_controllers.keys
                                          .toList()[currentFocusIndex]]!,
                                      onTextInput: (text) {
                                        final currentController = _controllers[
                                            _controllers.keys
                                                .toList()[currentFocusIndex]]!;
                                        currentController.text =
                                            currentController.text + text;
                                        _updateTotals();
                                      },
                                      onBackspace: () {
                                        final currentController = _controllers[
                                            _controllers.keys
                                                .toList()[currentFocusIndex]]!;
                                        if (currentController.text.isNotEmpty) {
                                          currentController.text =
                                              currentController.text.substring(
                                            0,
                                            currentController.text.length - 1,
                                          );
                                          _updateTotals();
                                        }
                                      },
                                      onOk: moveToNextField,
                                      isLastField: currentFocusIndex ==
                                          _controllers.keys.length - 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Current: ${_controllers.keys.toList()[currentFocusIndex]}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Action buttons under the keyboard
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      final shouldCancel =
                                          await _showConfirmationDialog(
                                        context: context,
                                        title: 'Cancel Denomination',
                                        content:
                                            'Are you sure you want to cancel? Any changes will be lost.',
                                        confirmText: 'Yes, Cancel',
                                        cancelText: 'No, Continue',
                                      );

                                      if (shouldCancel == true) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.redAccent.withOpacity(0.1),
                                      foregroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final shouldSave =
                                          await _showConfirmationDialog(
                                        context: context,
                                        title: 'Save Denomination',
                                        content:
                                            'Are you sure you want to save the denomination values?',
                                        confirmText: 'Yes, Save',
                                        cancelText: 'No, Edit',
                                      );

                                      if (shouldSave == true) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          _postShiftData(
                                            _calculateGrandTotal(),
                                          );
                                        }
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.blueAccent.withOpacity(0.1),
                                      foregroundColor: Colors.blueAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final shouldClear =
                                          await _showConfirmationDialog(
                                        context: context,
                                        title: 'Clear All Denominations',
                                        content:
                                            'Are you sure you want to clear all denomination counts?',
                                        confirmText: 'Yes, Clear',
                                        cancelText: 'No, Keep',
                                      );
                                      if (shouldClear == true &&
                                          context.mounted) {
                                        _clearControllers();
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.orangeAccent.withOpacity(0.1),
                                      foregroundColor: Colors.orangeAccent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'All Clear',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
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
    for (var controller in _controllers.values) {
      controller.clear();
    }
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
            child: Text(cancelText, style: const TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChooseMode(BuildContext context) {
    final GlobalKey keyboardKey = GlobalKey();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseModePage(keyboardKey: keyboardKey),
      ),
    );
  }
}
