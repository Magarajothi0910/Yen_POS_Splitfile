import 'dart:convert';
import 'package:connectivity_plus_platform_interface/src/enums.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';

import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sync_service.dart';
import 'package:yenpos/more_page/providers/cash_management_provider.dart';

import '../../Sale_order/Widgets/customd_keyboard.dart';

class OpeningCashDialog extends StatefulWidget {
  const OpeningCashDialog({Key? key}) : super(key: key);

  @override
  _OpeningCashDialogState createState() => _OpeningCashDialogState();
}

class _OpeningCashDialogState extends State<OpeningCashDialog> {
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
  late List<FocusNode> focusNodes;
  late ValueNotifier<int> currentFocusIndexNotifier;

  @override
  void initState() {
    super.initState();
    focusNodes = _controllers.keys.map((_) => FocusNode()).toList();
    currentFocusIndexNotifier = ValueNotifier<int>(0);
    _initializeControllers();
    _updateTotals();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    currentFocusIndexNotifier.dispose();
    denominationTotals.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final counts = CashManagementProvider.denominationCounts.value;
    for (final denom in _controllers.keys) {
      final count = counts[denom] ?? 0;
      _controllers[denom]!.text = count.toString();
    }
  }

  void _updateTotals() {
    final newTotals = <int, int>{};
    final newCounts = <int, int>{};
    for (var denom in _controllers.keys) {
      final count = int.tryParse(_controllers[denom]!.text) ?? 0;
      newTotals[denom] = denom * count;
      newCounts[denom] = count;
    }
    denominationTotals.value = newTotals;
    CashManagementProvider.denominationCounts.value = newCounts;
  }

  int _calculateGrandTotal() {
    return denominationTotals.value.values.fold(0, (sum, total) => sum + total);
  }

  void _saveOpeningCash() {
    CashManagementProvider.manualOpeningBalance.value = _calculateGrandTotal();
    _clearControllers();
  }

  void _clearControllers() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
    _updateTotals();
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentFocusIndexNotifier,
      builder: (context, currentFocusIndex, _) {
        void moveToNextField() {
          if (currentFocusIndex < _controllers.keys.length - 1) {
            currentFocusIndexNotifier.value++;
            focusNodes[currentFocusIndexNotifier.value].requestFocus();
          } else {
            _saveOpeningCash();
            Navigator.pop(context);
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
                    'Opening Cash Denominations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                                          'Denomination',
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
                                              '₹$denom',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: TextField(
                                              focusNode: focusNode,
                                              controller: controller,
                                              keyboardType: TextInputType.none,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color:
                                                    currentFocusIndex == index
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
                                                    currentFocusIndex == index
                                                    ? Colors.blue.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.white,
                                                filled: true,
                                              ),
                                              onTap: () {
                                                currentFocusIndexNotifier
                                                        .value =
                                                    index;
                                              },
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              '₹${totals[denom] ?? 0}',
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Grand Total: ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${_calculateGrandTotal()}',
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
                    const VerticalDivider(width: 20, thickness: 1),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Column(
                            children: [
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
                                    final currentController =
                                        _controllers[_controllers.keys
                                            .toList()[currentFocusIndex]]!;
                                    currentController.text =
                                        currentController.text + text;
                                    _updateTotals();
                                  },
                                  onBackspace: () {
                                    final currentController =
                                        _controllers[_controllers.keys
                                            .toList()[currentFocusIndex]]!;
                                    if (currentController.text.isNotEmpty) {
                                      currentController.text = currentController
                                          .text
                                          .substring(
                                            0,
                                            currentController.text.length - 1,
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
                              const SizedBox(height: 10),
                              Text(
                                'Current: ₹${_controllers.keys.toList()[currentFocusIndex]}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final shouldCancel =
                                      await _showConfirmationDialog(
                                        title: 'Cancel Opening Cash',
                                        content:
                                            'Are you sure you want to cancel? Any changes will be lost.',
                                        confirmText: 'Yes, Cancel',
                                        cancelText: 'No, Continue',
                                      );
                                  if (shouldCancel == true && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(
                                    0.1,
                                  ),
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
                                  final shouldSave = await _showConfirmationDialog(
                                    title: 'Save Opening Cash',
                                    content:
                                        'Are you sure you want to save the opening cash denominations?',
                                    confirmText: 'Yes, Save',
                                    cancelText: 'No, Edit',
                                  );
                                  if (shouldSave == true && context.mounted) {
                                    _saveOpeningCash();
                                    Navigator.pop(context);
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
                                  final shouldClear = await _showConfirmationDialog(
                                    title: 'Clear All Denominations',
                                    content:
                                        'Are you sure you want to clear all denomination counts?',
                                    confirmText: 'Yes, Clear',
                                    cancelText: 'No, Keep',
                                  );
                                  if (shouldClear == true && context.mounted) {
                                    _clearControllers();
                                  }
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
  }
}

class DenominationDialog extends StatefulWidget {
  const DenominationDialog({Key? key}) : super(key: key);

  @override
  _DenominationDialogState createState() => _DenominationDialogState();
}

class _DenominationDialogState extends State<DenominationDialog> {
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
  late List<FocusNode> focusNodes;
  late ValueNotifier<int> currentFocusIndexNotifier;

  @override
  void initState() {
    super.initState();
    focusNodes = _controllers.keys.map((_) => FocusNode()).toList();
    currentFocusIndexNotifier = ValueNotifier<int>(0);
    _initializeControllers();
    _updateTotals();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    currentFocusIndexNotifier.dispose();
    denominationTotals.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final counts = CashManagementProvider.denominationCounts.value;
    for (final denom in _controllers.keys) {
      final count = counts[denom] ?? 0;
      _controllers[denom]!.text = count.toString();
    }
  }

  void _updateTotals() {
    final newTotals = <int, int>{};
    final newCounts = <int, int>{};
    for (var denom in _controllers.keys) {
      final count = int.tryParse(_controllers[denom]!.text) ?? 0;
      newTotals[denom] = denom * count;
      newCounts[denom] = count;
    }
    denominationTotals.value = newTotals;
    CashManagementProvider.denominationCounts.value = newCounts;
    CashManagementProvider.physicalCashSales.value = newTotals.values.fold(
      0,
      (sum, total) => sum + total,
    );
  }

  int _calculateGrandTotal() {
    return denominationTotals.value.values.fold(0, (sum, total) => sum + total);
  }

  void _saveDenominations() {
    CashManagementProvider.physicalCashSales.value = _calculateGrandTotal();
    CashManagementProvider.persistDenominationsToStore();

    Navigator.pop(context);
  }

  void _clearControllers() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
    _updateTotals();
  }

  Future<bool?> _showConfirmationDialog({
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentFocusIndexNotifier,
      builder: (context, currentFocusIndex, _) {
        void moveToNextField() {
          if (currentFocusIndex < _controllers.keys.length - 1) {
            currentFocusIndexNotifier.value++;
            focusNodes[currentFocusIndexNotifier.value].requestFocus();
          } else {
            _saveDenominations();
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
                    'Denominations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                                          'Denomination',
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
                                              '₹$denom',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: TextField(
                                              focusNode: focusNode,
                                              controller: controller,
                                              keyboardType: TextInputType.none,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color:
                                                    currentFocusIndex == index
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
                                                    currentFocusIndex == index
                                                    ? Colors.blue.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.white,
                                                filled: true,
                                              ),
                                              onTap: () {
                                                currentFocusIndexNotifier
                                                        .value =
                                                    index;
                                                _updateTotals();
                                              },
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              '₹${totals[denom] ?? 0}',
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Grand Total: ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${_calculateGrandTotal()}',
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
                    const VerticalDivider(width: 20, thickness: 1),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Column(
                            children: [
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
                                    final currentController =
                                        _controllers[_controllers.keys
                                            .toList()[currentFocusIndex]]!;
                                    currentController.text =
                                        currentController.text + text;
                                    _updateTotals();
                                  },
                                  onBackspace: () {
                                    final currentController =
                                        _controllers[_controllers.keys
                                            .toList()[currentFocusIndex]]!;
                                    if (currentController.text.isNotEmpty) {
                                      currentController.text = currentController
                                          .text
                                          .substring(
                                            0,
                                            currentController.text.length - 1,
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
                              const SizedBox(height: 10),
                              Text(
                                'Current: ₹${_controllers.keys.toList()[currentFocusIndex]}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final shouldCancel =
                                      await _showConfirmationDialog(
                                        title: 'Cancel Denominations',
                                        content:
                                            'Are you sure you want to cancel? Any changes will be lost.',
                                        confirmText: 'Yes, Cancel',
                                        cancelText: 'No, Continue',
                                      );
                                  if (shouldCancel == true && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(
                                    0.1,
                                  ),
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
                                  final shouldSave = await _showConfirmationDialog(
                                    title: 'Save Denominations',
                                    content:
                                        'Are you sure you want to save the denomination values?',
                                    confirmText: 'Yes, Save',
                                    cancelText: 'No, Edit',
                                  );
                                  if (shouldSave == true && context.mounted) {
                                    _saveDenominations();
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
                                  final shouldClear = await _showConfirmationDialog(
                                    title: 'Clear All Denominations',
                                    content:
                                        'Are you sure you want to clear all denomination counts?',
                                    confirmText: 'Yes, Clear',
                                    cancelText: 'No, Keep',
                                  );
                                  if (shouldClear == true && context.mounted) {
                                    _clearControllers();
                                  }
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
  }
}

Future<void> openDenominationDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const DenominationDialog(),
  );
}

Widget buildOptionCard({
  required String title,
  required String description,
  required IconData icon,
  required VoidCallback onTap,
  required bool isSelected,
}) {
  return SizedBox(
    width: 300,
    height: 120,
    child: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isSelected ? Colors.blue[600] : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ShiftClosingContainer extends StatefulWidget {
  final ValueNotifier<ConnectivityResult> connectivityResult;

  const ShiftClosingContainer({Key? key, required this.connectivityResult})
    : super(key: key);

  @override
  _ShiftClosingContainerState createState() => _ShiftClosingContainerState();
}

class _ShiftClosingContainerState extends State<ShiftClosingContainer> {
  final FocusNode _upiFocusNode = FocusNode();
  final FocusNode _cardFocusNode = FocusNode();
  final ValueNotifier<int> _currentFocusIndexNotifier = ValueNotifier<int>(-1);
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();

  @override
  void initState() {
    super.initState();
    CashManagementProvider.fetchValidationDetails();
    // Initialize controller text with provider values
    _upiController.text = CashManagementProvider.upiSalesController.value;
    _cardController.text = CashManagementProvider.cardSalesController.value;

    // Sync controller text to provider
    _upiController.addListener(() {
      CashManagementProvider.upiSalesController.value = _upiController.text;
    });
    _cardController.addListener(() {
      CashManagementProvider.cardSalesController.value = _cardController.text;
    });

    // Sync provider changes back to controllers
    CashManagementProvider.upiSalesController.addListener(() {
      if (_upiController.text !=
          CashManagementProvider.upiSalesController.value) {
        _upiController.text = CashManagementProvider.upiSalesController.value;
      }
    });
    CashManagementProvider.cardSalesController.addListener(() {
      if (_cardController.text !=
          CashManagementProvider.cardSalesController.value) {
        _cardController.text = CashManagementProvider.cardSalesController.value;
      }
    });
  }

  @override
  void dispose() {
    _upiFocusNode.dispose();
    _cardFocusNode.dispose();
    _currentFocusIndexNotifier.dispose();
    _upiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Widget buildShiftClosingContainer(
    BuildContext context,
    ValueNotifier<ConnectivityResult> connectivityResult,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildOpeningCashSection(context),
                      SizedBox(
                        width: 280,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => openDenominationDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable:
                                CashManagementProvider.physicalCashSales,
                            builder: (context, total, _) {
                              return Text(
                                'Enter Denomination\n(Total: ₹$total)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.blue),
                              );
                            },
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            CashManagementProvider.physicalCashSales,
                        builder: (context, denominationTotal, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable:
                                CashManagementProvider.manualOpeningBalance,
                            builder: (context, openingCash, __) {
                              final cashDrawer =
                                  openingCash + denominationTotal;
                              return _buildCashDetailSection(
                                title: 'Cash Drawer',
                                amount: '₹ $cashDrawer',
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildSummaryColumns(context, connectivityResult),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningCashSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opening Cash',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: CashManagementProvider.manualOpeningBalance,
          builder: (context, openingCash, _) {
            return GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (context) => const OpeningCashDialog(),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 30,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '₹ $openingCash',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCashDetailSection({
    required String title,
    required String amount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(amount, style: const TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildSummaryColumns(
    context,
    ValueNotifier<ConnectivityResult> connectivityResult,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: CashManagementProvider.physicalCashSales,
      builder: (context, denominationTotal, _) {
        return ValueListenableBuilder<int>(
          valueListenable: CashManagementProvider.manualOpeningBalance,
          builder: (context, openingCash, __) {
            final cashSales = denominationTotal;
            return Container(
              //color: Colors.red,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    // color: Colors.amber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        _buildSummaryRowReadOnly("Cash Sales", '₹ $cashSales'),
                        _buildSummaryRowWithManual(
                          title: "UPI Sales",
                          controller: _upiController,
                          focusNode: _upiFocusNode,
                          index: 0,
                          valueListenable:
                              CashManagementProvider.upiSalesController,
                        ),
                        _buildSummaryRowWithManual(
                          title: "Card Sales",
                          controller: _cardController,
                          focusNode: _cardFocusNode,
                          index: 1,
                          valueListenable:
                              CashManagementProvider.cardSalesController,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 80),
                          child: _buildShiftClosingButton(
                            context,
                            connectivityResult,
                            soApprovalStatus,
                          ),
                        ),
                      ],
                    ),
                  ),
                  //  const VerticalDivider(width: 20, thickness: 1),
                  const SizedBox(width: 16),
                  Container(
                    color: Colors.white,
                    child: Expanded(
                      flex: 2,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentFocusIndexNotifier,
                        builder: (context, currentFocusIndex, _) {
                          final activeController = currentFocusIndex == 0
                              ? _upiController
                              : currentFocusIndex == 1
                              ? _cardController
                              : null;
                          final activeFocusNode = currentFocusIndex == 0
                              ? _upiFocusNode
                              : currentFocusIndex == 1
                              ? _cardFocusNode
                              : null;

                          return Column(
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                child:
                                    activeController != null &&
                                        activeFocusNode != null
                                    ? NumericKeyboard(
                                        focusNode: activeFocusNode,
                                        controller: activeController,
                                        onTextInput: (text) {
                                          activeController.text += text;
                                          // No need to update provider here, handled by controller listener
                                        },
                                        onBackspace: () {
                                          if (activeController
                                              .text
                                              .isNotEmpty) {
                                            activeController.text =
                                                activeController.text.substring(
                                                  0,
                                                  activeController.text.length -
                                                      1,
                                                );
                                          }
                                        },
                                        onOk: () {
                                          if (currentFocusIndex == 0) {
                                            _currentFocusIndexNotifier.value =
                                                1;
                                            _cardFocusNode.requestFocus();
                                          } else if (currentFocusIndex == 1) {
                                            _currentFocusIndexNotifier.value =
                                                -1;
                                            activeFocusNode.unfocus();
                                          }
                                        },
                                        isLastField: currentFocusIndex == 1,
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 60),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          child: const Text(
                                            'Tap UPI or Card field to enter amount',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                currentFocusIndex == 0
                                    ? 'Current: UPI Sales'
                                    : currentFocusIndex == 1
                                    ? 'Current: Card Sales'
                                    : 'Select a field',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRowReadOnly(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[100],
              ),
              child: Text(
                amount,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRowWithManual({
    required String title,
    required TextEditingController controller,
    required FocusNode focusNode,
    required int index,
    required ValueNotifier<String>
    valueListenable, // Add ValueNotifier parameter
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 110,
            child: ValueListenableBuilder<String>(
              valueListenable: valueListenable,
              builder: (context, value, _) {
                // Ensure controller text is in sync with ValueNotifier
                if (controller.text != value) {
                  controller.text = value;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.none, // Disable default keyboard
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _currentFocusIndexNotifier.value == index
                        ? Colors.blue
                        : Colors.black,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _currentFocusIndexNotifier.value == index
                            ? Colors.blue
                            : Colors.grey,
                        width: _currentFocusIndexNotifier.value == index
                            ? 2.0
                            : 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _currentFocusIndexNotifier.value == index
                            ? Colors.blue
                            : Colors.grey,
                        width: _currentFocusIndexNotifier.value == index
                            ? 2.0
                            : 1.0,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2.0),
                    ),
                    fillColor: _currentFocusIndexNotifier.value == index
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.white,
                    filled: true,
                    hintText: 'Enter',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefix: Text(
                      "₹",
                      style: TextStyle(
                        color: _currentFocusIndexNotifier.value == index
                            ? Colors.blue
                            : Colors.black54,
                      ),
                    ),
                  ),
                  onTap: () {
                    _currentFocusIndexNotifier.value = index;
                    focusNode.requestFocus();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftClosingButton(
    BuildContext context,
    ValueNotifier<ConnectivityResult> connectivityResult,
    ValueNotifier<String> soApprovalStatus,
  ) {
    bool _isProcessing = false; // Flag to prevent double taps

    return ValueListenableBuilder<bool>(
      valueListenable: CashManagementProvider.isShiftClosed,
      builder: (context, closed, _) {
        return ValueListenableBuilder<String>(
          valueListenable: shiftId,
          builder: (context, shiftId, __) {
            debugPrint("Shift ID 1: $shiftId");
            return ValueListenableBuilder<ConnectivityResult>(
              valueListenable: connectivityResult,
              builder: (context, connectivity, ___) {
                final isConnected = connectivity != ConnectivityResult.none;
                return ElevatedButton(
                  onPressed: isConnected && !_isProcessing
                      ? () async {
                          if (_isProcessing) return; // Prevent double tap
                          _isProcessing = true;

                          try {
                            // Check soApprovalStatus
                            if (soApprovalStatus.value == "failed") {
                              final proceed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text("Approval Status Error"),
                                    content: const Text(
                                      "Some Sale Order Approvals are Pending. Do you want to proceed anyway?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text(
                                          "Go Back and Check",
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                        child: const Text(
                                          "Proceed Anyway",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (proceed != true) {
                                _isProcessing = false;
                                return;
                              }
                            }

                            // Show confirmation dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text("Confirm Save"),
                                  content: const Text(
                                    "Are you sure you want to close this shift?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                      child: const Text(
                                        "Yes, Save",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) {
                              _isProcessing = false;
                              return;
                            }

                            debugPrint("Button tapped & confirmed");

                            var invoiceBox = await Hive.openBox('invoicesBox');
                            bool needsSync = invoiceBox.values.any((
                              invoiceData,
                            ) {
                              if (invoiceData is String) {
                                invoiceData =
                                    jsonDecode(invoiceData)
                                        as Map<String, dynamic>;
                              }
                              return invoiceData is Map<String, dynamic> &&
                                  invoiceData['sync'] == 'No';
                            });

                            if (needsSync) {
                              final syncService = Provider.of<SyncService>(
                                context,
                                listen: false,
                              );
                              final itemProvider = Provider.of<ItemProvider>(
                                context,
                                listen: false,
                              );
                              await syncService.syncUnsyncedInvoices();
                            }

                            debugPrint("Sync Service Completed");

                            await CashManagementProvider.patchShiftClosingData(
                              shiftId,
                              context,
                            );
                          } finally {
                            _isProcessing =
                                false; // Reset flag after processing
                          }
                        }
                      : () {
                          if (!_isProcessing) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'No internet connection. Please check your network.',
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildShiftClosingContainer(context, widget.connectivityResult);
  }
}
