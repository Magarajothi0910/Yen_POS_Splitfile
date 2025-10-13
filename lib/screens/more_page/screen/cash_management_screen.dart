// // lib/cash_management/cash_management_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:yenposapp/screens/more_page/providers/cash_management_provider.dart';
import 'package:yenposapp/screens/more_page/widgets/cash_management_widgets.dart';

class CashManagementScreen extends StatefulWidget {
  const CashManagementScreen({super.key});

  @override
  State<CashManagementScreen> createState() => _CashManagementScreenState();
}

class _CashManagementScreenState extends State<CashManagementScreen> {
  final ValueNotifier<ConnectivityResult> connectivityResult =
      ValueNotifier(ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    // Bootstrap initial data (no setState used anywhere)
    CashManagementProvider.bootstrap();
    _checkConnectivity();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      connectivityResult.value =
          result.first; // Handle Stream<List<ConnectivityResult>>
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    connectivityResult.value = result.first;
  }

  @override
  void dispose() {
    CashManagementProvider.disposeAll();
    connectivityResult.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CashManagementProvider.cashManagementView,
      builder: (context, view, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  buildOptionCard(
                    title: 'Shift Closing',
                    description: 'Close the shift and balance your cash.',
                    icon: Icons.lock_clock,
                    isSelected: view == 'Shift Closing',
                    onTap: () {
                      CashManagementProvider.cashManagementView.value =
                          'Shift Closing';
                    },
                  ),
                  const SizedBox(width: 10),
                  buildOptionCard(
                    title: 'Cash In',
                    description: 'Add cash to your drawer.',
                    icon: Icons.money_sharp,
                    isSelected: view == 'Cash In',
                    onTap: () {
                      CashManagementProvider.cashManagementView.value =
                          'Cash In';
                    },
                  ),
                  const SizedBox(width: 10),
                  buildOptionCard(
                    title: 'Cash Out',
                    description: 'Withdraw cash from your drawer.',
                    icon: Icons.money_off,
                    isSelected: view == 'Cash Out',
                    onTap: () {
                      CashManagementProvider.cashManagementView.value =
                          'Cash Out';
                    },
                  ),
                ],
              ),
            ),
            //const SizedBox(height: 20),
            Expanded(
              child: view == 'Shift Closing'
                  ? ShiftClosingContainer(
                      connectivityResult: connectivityResult)
                  : view == 'Cash In'
                      ? const Center(
                          child: Text(
                            'Cash In functionality not implemented yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : view == 'Cash Out'
                          ? const Center(
                              child: Text(
                                'Cash Out functionality not implemented yet',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : const Center(
                              child: Text(
                                'Select a view',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }
}
