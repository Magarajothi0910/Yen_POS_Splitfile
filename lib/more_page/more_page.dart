import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:yenposapp/Global/Widget/custom_sized_box.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Server_Client/serverScreen.dart';

import 'package:yenposapp/printer_screen/printer_config.dart';

import 'configurations/weigheing_scale_configration.dart';
import 'controller/cash_sales_controller.dart';
import 'controller/denomination_controler.dart';
import 'screen/add_new_customer_page.dart';
import 'screen/credit_customer.dart';
import 'screen/day_end_bill.dart';
import 'screen/dinomination_bill.dart';
import 'screen/shift_close_bill.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON decoding
import 'package:network_info_plus/network_info_plus.dart';

import 'screen/wifi_ip_list.dart';

class MorePage extends StatefulWidget {
  final GlobalKey keyboardKey;
  const MorePage({super.key, required this.keyboardKey});

  @override
  _MorePageState createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String selectedOption = 'Configuration'; // Default selected option
  bool showShiftClosingData = false; // New state to track shift closing click
  int physicalCashSales = 0; // Updated after DenominationTable entry
  final TextEditingController salesInCashController = TextEditingController();
  String configurationView = ''; // Tracks which configuration to show
  String cashManagementView = 'Shift Closing'; // Default cash management view
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  int manualOpeningBalance = 0;
  int cashTotal = 0;
  int upiTotal = 0;
  int cardTotal = 0;
  String shiftOpeningDate = '';
  String shiftOpeningTime = '';
  String shiftbranchName = '';
  String shiftOpenName = '';
  int shiftOpenId = 0;
  String shiftid = "";
  double totalInvoiceCash = 0;
  double totalSalesOrderAdvanceCash = 0;
  double totalSalesReturnCash = 0;
  double systemCashTotal = 0;
  bool isShiftClosed = false; // Track if the shift is closed
  Map<String, dynamic> dayEndData = {}; // To store day-end data
  bool isDayEndLoading = false; // To track loading state
  List<dynamic> creditBills = [];
  dynamic selectedBill;

  Set<dynamic> selectedBills = {}; // To store multiple selected bills
  bool isSelectionMode = false; // Flag for selection mode
  // In your state, you already have:
  String? _wifiIP;

  Future<void> _loadWifiIP() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    setState(() {
      _wifiIP = ip ?? 'IP not available';
    });
  }

  @override
  void dispose() {
    salesInCashController.dispose();
    nameController.dispose();
    phoneController.dispose();

    super.dispose();
  }

  static String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  final String shiftGet =
      "https://yenerp.com/fastapi/shifts/?shift_opening_date=${formatDate(DateTime.now())}&branch_name=$branchName&device_number=$deviceNumber";
  final String invoiceTotalSales =
      'https://yenerp.com/fastapi/invoices/?start_date=${formatDate(DateTime.now())}&shift_number=1&branch_name=$branchName&device_number=$deviceNumber&show_totals=true';
  final String systemtotalscash =
      'https://yenerp.com/fastapi/totals/systemtotalscash?date=${formatDate(DateTime.now())}';

  final cashSalesController = Get.put(CashSalesController());
  final Map<int, TextEditingController> controllers = {
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

  final Map<int, int> totals = {
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
    5: 0,
    2: 0,
    1: 0,
  };

  Future<List<Map<String, String>>> fetchShiftDetails() async {
    final String apiUrl = "https://yenerp.com/fastapi/shifts/";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> shifts = json.decode(response.body);

        if (shifts.isEmpty) {
          return [];
        }

        List<Map<String, String>> formattedShifts = shifts.map((shift) {
          // Save the first manual opening balance to the state
          if (shift == shifts.first) {
            setState(() {
              manualOpeningBalance = int.tryParse(
                    shift['manualOpeningBalance']?.toString() ?? '0',
                  ) ??
                  0;
              shiftid = shift['shiftId'] ?? "";
            });
          }

          // Print details for each shift
          // Handle null

          return {
            "Shift Number": shift['shiftNumber'].toString(),
            "Opening Time": shift['shiftOpeningTime'].toString(),
            "Closing Time": shift['shiftClosingTime']?.toString() ?? 'N/A',
            "System Closing Balance":
                shift['systemClosingBalance']?.toString() ?? '0',
            "Manual Closing Balance":
                shift['manualClosingBalance']?.toString() ?? '0',
            "Difference": calculateDifference(
              shift['systemClosingBalance']?.toString(),
              shift['manualClosingBalance']?.toString(),
            ),
          };
        }).toList();

        return formattedShifts;
      } else {
        return [];
      }
    } catch (error) {
      return [];
    }
  }

  Future<void> fetchInvoiceData() async {
    try {
      final response = await http.get(Uri.parse(invoiceTotalSales));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Update state with fetched data
        setState(() {
          cashTotal = data['total_cash'] ?? 0; // Correct key for cash total
          upiTotal = data['total_upi'] ?? 0; // Correct key for UPI total
          cardTotal = data['total_card'] ?? 0; // Correct key for card total
        });
      } else {}
    } catch (error) {}
  }

  Future<void> fetchSystemTotalsCash() async {
    try {
      final String url = '$systemtotalscash';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          totalInvoiceCash = (data['totalInvoiceCash'] ?? 0).toDouble();
          totalSalesOrderAdvanceCash =
              (data['totalSalesOrderAdvanceCash'] ?? 0).toDouble();
          totalSalesReturnCash = (data['totalSalesReturnCash'] ?? 0).toDouble();
          systemCashTotal = (data['SystemCashTotal'] ?? 0).toDouble();
        });

        // Print detailed totals
      } else {}
    } catch (e) {}
  }

  Future<void> fetchDayEndData() async {
    final String apiUrl =
        "https://yenerp.com/fastapi/shifts/?shift_opening_date=${formatDate(DateTime.now())}&branch_name=$branchName&device_number=$deviceNumber";

    setState(() {
      isDayEndLoading = true; // Show loading indicator
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.isNotEmpty) {
          // Filter the data where dayEndStatus = 'open' and status = 'closed'
          final filteredData = data
              .where(
                (item) =>
                    item['dayEndStatus'] == 'open' &&
                    item['status'] == 'closed',
              )
              .toList();

          if (filteredData.isNotEmpty) {
            setState(() {
              dayEndData = {
                'shiftId': filteredData[0]['shiftId'],
                'shiftNumber': filteredData[0]['shiftNumber'].toString(),
                'shiftOpeningDate': filteredData[0]['shiftOpeningDate'] ?? '',
                'shiftOpeningTime': filteredData[0]['shiftOpeningTime'] ?? '',
                'shiftClosingDate': filteredData[0]['shiftClosingDate'] ?? '',
                'shiftClosingTime': filteredData[0]['shiftClosingTime'] ?? '',
                'systemOpeningBalance':
                    filteredData[0]['systemOpeningBalance'].toString(),
                'manualOpeningBalance':
                    filteredData[0]['manualOpeningBalance'].toString(),
                'systemClosingBalance':
                    filteredData[0]['systemClosingBalance'].toString(),
                'manualClosingBalance':
                    filteredData[0]['manualClosingBalance'].toString(),
                'cashSales': filteredData[0]['cashSales'] ?? '0',
                'cardSales': filteredData[0]['cardSales'] ?? '0',
                'upiSales': filteredData[0]['upiSales'] ?? '0',
                'otherSales': filteredData[0]['otherSales'] ?? '0',
                'dayEndStatus': filteredData[0]['dayEndStatus'] ?? 'open',
              };
              isDayEndLoading = false; // Hide loading indicator
            });
          } else {
            setState(() {
              dayEndData = {};
              isDayEndLoading = false;
            });
          }
        } else {
          setState(() {
            isDayEndLoading = false;
          });
        }
      } else {
        setState(() {
          isDayEndLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        isDayEndLoading = false;
      });
    }
  }

  // Future<void> fetchCreditBills() async {
  //   const String apiUrl = 'https://yenerp.com/fastapi/creditbills/';
  //   try {
  //     final response = await http.get(Uri.parse(apiUrl));

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body); // Decode JSON response

  //       print('Credit Bills Data:');
  //       print("Credit Bills Data: ${data}"); // Print the fetched data
  //       print("Total Data Count: ${data.length}"); // Print the total data count

  //       setState(() {
  //         creditBills = data; // Store the data in the state variable
  //       });
  //     } else {
  //       print('Failed to fetch credit bills: ${response.statusCode}');
  //     }
  //   } catch (error) {
  //     print('Error fetching credit bills: $error');
  //   }
  // }

  @override
  void initState() {
    fetchShiftDetails();
    fetchInvoiceData();
    fetchSystemTotalsCash();
    fetchDayEndData();
    _loadWifiIP();
    // fetchCreditBills();
    super.initState();
  }

  void _openDenominationTable() async {
    final denominationController = Get.find<DenominationController>();

    await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        int runningTotal = totals.values.fold(0, (sum, amount) => sum + amount);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            void updateRunningTotal() {
              runningTotal = totals.values.fold(
                0,
                (sum, amount) => sum + amount,
              );
              cashSalesController.updateCashSales(runningTotal);
            }

            return AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDataTable(setState, updateRunningTotal),
                    const SizedBox(height: 20),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          'Total: ₹${cashSalesController.physicalCashSales.value}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Update the denomination data in the controller
                        totals.forEach((denomination, value) {
                          int count = value ~/ denomination;
                          denominationController.updateDenomination(
                            denomination,
                            count,
                          );
                        });

                        Navigator.of(context).pop(); // Close the dialog
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDataTable(
    StateSetter setState,
    VoidCallback updateRunningTotal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width *
              0.5, // Set width to 80% of screen
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!), // Light border color
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: WidgetStateColor.resolveWith(
                (states) => Colors.blue.withOpacity(0.1),
              ), // Header row color
              columns: const [
                DataColumn(
                  label: Center(
                    child: Text(
                      'Denomination',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text(
                      'Count',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: Center(
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              rows: controllers.keys.map((denomination) {
                return DataRow(
                  cells: [
                    DataCell(
                      Center(
                        child: Text(
                          '₹$denomination',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    DataCell(
                      TextField(
                        controller: controllers[denomination],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 10.0,
                          ),
                        ),
                        onChanged: (value) {
                          int count = int.tryParse(value) ?? 0;
                          totals[denomination] = count * denomination;
                          updateRunningTotal();
                          setState(() {});
                        },
                      ),
                    ),
                    DataCell(
                      Center(
                        child: Text(
                          '₹${totals[denomination]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Row(
        children: [
          // Left side with settings options
          Container(
            decoration: BoxDecoration(
              color: Colors.white, // Background color of the container
              border: Border(
                right: BorderSide(
                  color: Colors.blue[200] ??
                      Colors.blue, // Right side border color
                  width: 2.0, // Right side border width
                ),
              ),
              borderRadius: BorderRadius.circular(
                8.0,
              ), // Optional: Add rounded corners
            ),
            width: 250, // Adjust the width to your preference
            child: ListView(
              children: [
                _buildSettingTile(
                  'Configuration',
                  onTap: () {
                    setState(() {
                      selectedOption = 'Configuration';
                      configurationView =
                          'Printer Configuration'; // Default view
                    });
                  },
                ),
                _buildSettingTile(
                  'Cash Management',
                  onTap: () {
                    setState(() {
                      selectedOption = 'Cash Management';
                      cashManagementView = 'Shift Closing'; // Reset to default
                    });
                  },
                ),
                _buildSettingTile(
                  'Credit Customer',
                  onTap: () {
                    setState(() {
                      selectedOption = 'Credit Customer';
                      cashManagementView = 'Shift Closing'; // Reset to default
                    });
                  },
                ),
                _buildSettingTile(
                  'Customer Management',
                  onTap: () {
                    setState(() {
                      selectedOption = 'Customer Management';
                      cashManagementView = 'Shift Closing'; // Reset to default
                    });
                  },
                ),
                _buildSettingTile(
                  'Device Configrations',
                  onTap: () {
                    setState(() {
                      selectedOption = 'Device Configrations';
                      cashManagementView = 'Shift Closing';
                    });
                  },
                ),
                _buildSettingTile(
                  'LogOut',
                  onTap: () {
                    _showLogoutConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Right side showing the selected content
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(
                    context,
                  ).size.height, // Minimum height of the scrollable area
                ),
                child: IntrinsicHeight(
                  // Allows the Column to determine its height based on children
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRightSideContent(),
                      if (selectedOption == 'Configuration' &&
                          configurationView.isNotEmpty) ...[
                        const Divider(thickness: 0.5),
                        _buildConfigurationDetails(),
                      ],
                      if (selectedOption == 'Device Configrations') ...[
                        Expanded(
                          child:
                              WifiDevicesScreen(), // This widget shows a list of found device IPs.
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to build each setting tile and apply background color based on selection
  Widget _buildSettingTile(String title, {VoidCallback? onTap}) {
    bool isSelected =
        selectedOption == title; // Check if the current tile is selected
    return ListTile(
      tileColor: isSelected
          ? Colors.blue.withOpacity(0.2)
          : Colors.transparent, // Change background color
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: isSelected
              ? Colors.blue
              : Colors.black, // Change text color based on selection
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isSelected ? Colors.blue : Colors.black,
      ),
      onTap: onTap,
    );
  }

  // Function to handle device configurations
  void _deviceConfigurations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Device Configurations')),
          body: const Center(child: Text('Device Name is Pos 1')),
        ),
      ),
    );
  }

  // Function to show the right side content based on the selected option
  Widget _buildRightSideContent() {
    switch (selectedOption) {
      case 'Configuration':
        return _buildConfigurationContent();
      case 'Cash Management':
        return _buildShiftClosingContent();
      case 'Customer Management':
        return Expanded(
          child: CustomerManagementPage(), // Ensure this is displayed properly
        );
      case 'Credit Customer':
        // Return CreditCustomerPage directly here
        return Expanded(
          child: CreditCustomerPage(), // Ensure this is displayed properly
        );

      default:
        return const Center(child: Text(''));
    }
  }

  Widget _buildConfigurationContent() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Printer Configuration Button
          _buildConfigurationButton(
            icon: Icons.print,
            label: 'Printer Configuration',
            onPressed: () {
              setState(() {
                configurationView = 'Printer Configuration';
              });
            },
            isSelected: configurationView == 'Printer Configuration',
          ),
          const SizedBox(width: 16),
          // Weight Scale Configuration Button
          _buildConfigurationButton(
            icon: Icons.scale,
            label: 'Weight Scale Configuration',
            onPressed: () {
              setState(() {
                configurationView = 'Weight Scale Configuration';
              });
            },
            isSelected: configurationView == 'Weight Scale Configuration',
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSelected = false, // Add isSelected to track the state of the button
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isSelected
          ? Colors.blue[600]
          : Colors.white, // Change background color based on selection
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : Colors.black, // Change icon color
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Colors.black, // Change text color
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftClosingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section for Option Cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildOptionCard(
                title: 'Shift Closing',
                description: 'Close the shift and balance your cash.',
                icon: Icons.lock_clock,
                onTap: () {
                  setState(() {
                    cashManagementView = 'Shift Closing';
                  });
                },
                isSelected: cashManagementView == 'Shift Closing',
              ),
              CustomSizedBox(width: 10),
              _buildOptionCard(
                title: 'Day End Closing',
                description: 'End the day and balance sales.',
                icon: Icons.calendar_today,
                onTap: () {
                  setState(() {
                    cashManagementView = 'Day End Closing';
                  });
                  fetchDayEndData(); // Fetch Day End Closing data
                },
                isSelected: cashManagementView == 'Day End Closing',
              ),
              CustomSizedBox(width: 10),
              _buildOptionCard(
                title: 'Cash In',
                description: 'Add cash to your drawer.',
                icon: Icons.money_sharp,
                onTap: () {
                  setState(() {
                    cashManagementView = 'Cash In';
                  });
                },
                isSelected: cashManagementView == 'Cash In',
              ),
              CustomSizedBox(width: 10),
              _buildOptionCard(
                title: 'Cash Out',
                description: 'Withdraw cash from your drawer.',
                icon: Icons.money_off,
                onTap: () {
                  setState(() {
                    cashManagementView = 'Cash Out';
                  });
                },
                isSelected: cashManagementView == 'Cash Out',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20), // Spacer between cards and the container
        // Section for Shift Closing Container
        if (cashManagementView == 'Shift Closing')
          _buildShiftClosingContainer(),
        if (cashManagementView == 'Day End Closing')
          _buildDayEndClosingContainer(),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false, // Add isSelected to track button state
  }) {
    return SizedBox(
      width: 300, // Define the width of the card
      height: 120,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isSelected
              ? Colors.blue[600]
              : Colors.white, // Change color based on selection
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: isSelected
                        ? Colors.white
                        : Colors.black, // Change icon color
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
                            color: isSelected
                                ? Colors.white
                                : Colors.black, // Change text color
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.black, // Change text color
                          ),
                        ),
                      ],
                    ),
                  ),
                  // const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double difference = 0;
  double difference2 = 0;
  // Widget to display Shift Closing content directly inside a Container
  Widget _buildShiftClosingContainer() {
    // ignore: unused_local_variable
    bool isSaved = false;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        int cashInDrawer =
            (manualOpeningBalance - cashSalesController.physicalCashSales.value)
                .abs(); // Compute absolute cash value
        double cashDifference = totalInvoiceCash - cashInDrawer;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Card(
              color: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Row(
                    //   children: [
                    //     _buildSummarySectionforshiftdetails('Opening Date', shiftOpeningDate),
                    //     _buildSummarySectionforshiftdetails('Opening Time', shiftOpeningTime),
                    //     _buildSummarySectionforshiftdetails('Branch Name', branchName),
                    //     _buildSummarySectionforshiftdetails('Shift ID', '$shiftOpenId'),
                    //     _buildSummarySectionforshiftdetails('Shift Open Name', shiftOpenName),
                    //   ],
                    // ),
                    // Row to show Opening Cash, Sales in Cash, Cash Drawer horizontally
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Opening Cash section
                        Expanded(
                          child: _buildCashDetailSection(
                            title: 'Opening Cash',
                            amount: '₹ $manualOpeningBalance',
                          ),
                        ),
                        const SizedBox(width: 12), // Spacer between fields
                        // Sales in Cash TextField
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Sales in Cash',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Obx(
                                () => ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ), // White background
                                    side: WidgetStateProperty.all(
                                      BorderSide(
                                        color: Colors.blue, // Blue border color
                                        width: 2.0, // Border width
                                      ),
                                    ),
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ), // Optional: Rounded corners
                                      ),
                                    ),
                                  ),
                                  onPressed: _openDenominationTable,
                                  child: Text(
                                    'Enter Denomination (Total: ₹${cashSalesController.physicalCashSales.value})',
                                    style: TextStyle(
                                      color: Colors.blue,
                                    ), // Optional: Blue text color
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12), // Spacer between fields
                        // Cash Drawer section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildCashDetailSection(
                                title: 'Cash Drawer',
                                amount:
                                    '₹ $cashInDrawer', // Ensure non-negative value
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20), // Spacing before next section

                    const Divider(),

                    const Text(
                      'Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSummarySection(
                      'Cash Sales',
                      '₹ $cashTotal',
                      showTextField: true,
                      hintText: 'Enter the manual cash',
                    ),
                    _buildSummarySection(
                      'UPI Sales',
                      '₹ $upiTotal',
                      showTextField: true,
                      hintText: 'Enter the manual upi',
                    ),
                    _buildSummarySection(
                      'Card Sales',
                      '₹ $cardTotal',
                      showTextField: true,
                      hintText: 'Enter the manual card',
                    ),

                    const SizedBox(
                      height: 20,
                    ), // Spacing before the save section
                    // Conditionally show the result after saving
                    if (isShiftClosed)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          children: [
                            _buildSummarySection(
                              'System Cash Sales',
                              '₹ $totalInvoiceCash',
                              isBold: true,
                            ),
                            _buildSummarySection(
                              'Physical Cash Sales',
                              '₹ $cashInDrawer',
                              isBold: true,
                            ),
                            _buildSummarySection(
                              'Cash Difference',
                              '₹ $cashDifference',
                              isBold: true,
                              color: cashDifference < 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ],
                        ),
                      ),

                    // Buttons for Cancel and Save
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isShiftClosed)
                          Text(
                            'Shift Closed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // Calculate the difference
                                difference = totalInvoiceCash - cashInDrawer;
                                isSaved = true;
                              });
                              patchShiftClosingData(
                                shiftid,
                              ); // Call the POST method

                              // DayEndPrintService.printDayEndBill(context);
                              DenominationBill.printDenominationBill(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Shift Closed Successfully'),
                                ),
                              );
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
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
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

  // Helper function to build individual cash details sections
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

  Widget _buildSummarySection(
    String title,
    String amount, {
    bool isBold = false,
    Color? color,
    bool showTextField = false,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Expanded(
          //   flex: 1,
          //   child: Text(
          //     amount,
          //     style: TextStyle(
          //       fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          //       fontSize: 16,
          //       color: color ?? Colors.black,
          //     ),
          //   ),
          // ),
          const SizedBox(width: 8),
          if (showTextField)
            Expanded(
              flex: 2,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),

                  hintText: hintText ?? 'Enter value', // Use provided hintText
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ), // Adjust padding
                ),
                onChanged: (value) {
                  // Handle the TextField's value change
                },
              ),
            ),
        ],
      ),
    );
  }

  // Helper function to build summary rows
  Widget _buildSummarySectionforshiftdetails(
    String title,
    String amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationDetails() {
    return Expanded(
      child: Container(
        color: Colors.grey[100], // Optional background color
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (configurationView == 'Printer Configuration')
              Expanded(child: PrinterSettingsScreen()),
            if (configurationView == 'Weight Scale Configuration')
              Expanded(child: ConnectWeighingScale()),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCustomerContent() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (configurationView == 'Credit Customer')
            Expanded(child: CreditCustomerPage()),
        ],
      ),
    );
  }

  void _showCustomerCreditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Create Credit Bill"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Customer Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 10.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 10.0,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  _postCustomerData(
                    nameController.text,
                    phoneController.text,
                    context,
                  );
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Name and phone number cannot be empty'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> patchShiftClosingData(String shiftId) async {
    // URL with the specific shift ID
    final String patchUrl = 'https://yenerp.com/fastapi/shifts/$shiftId';
    // Prepare the data payload
    final Map<String, dynamic> payload = {
      "shiftClosingDate": formatDate(DateTime.now()), // Closing date
      "shiftClosingTime": TimeOfDay.now().format(context), // Closing time
      "manualClosingBalance": cashTotal.toString(), // Manual closing balance
      "manualCashsales": cashTotal.toString(), // Manual cash sales
      "manualCardsales": cardTotal.toString(), // Manual card sales
      "manualUpisales": upiTotal.toString(), // Manual UPI sales
      "closingDifferenceAmount": difference.toString(), // Difference amount
      "closingDifferenceType":
          difference == 0 ? "no difference" : "difference", // Difference type
      "cashSales": cashTotal,
      "cardSales": cardTotal,
      "upiSales": upiTotal,
      "deliveryPartnerSales": "",
      "otherSales": "",
      "salesReturn": "",
      "manualDeliverypartnersales": "",
      "manualOthersales": "",
      "systemClosingBalance": "$totalInvoiceCash",
      "status": "closed",
    };
    try {
      final response = await http.patch(
        Uri.parse(patchUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          isShiftClosed = true; // Mark shift as closed
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift closed successfully!')),
        );

        // Decode the response body
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Pass the data to PrintService.printBill
        PrintService.printBill(
          context,
          branchName: responseData['branchName']?.toString() ?? 'Unknown',
          date: responseData['shiftClosingDate']?.toString() ?? '',
          time: responseData['shiftClosingTime']?.toString() ?? '',
          user: responseData['user']?.toString() ?? 'Admin',
          shiftOpenTime: responseData['shiftOpeningTime']?.toString() ?? '',
          shiftCloseTime: responseData['shiftClosingTime']?.toString() ?? '',
          systemOpenAmount:
              responseData['systemOpeningBalance']?.toString() ?? '',
          manualOpenAmount:
              responseData['manualOpeningBalance']?.toString() ?? '',
          shortage: responseData['openingDifferenceAmount']?.toString() ?? '',
          deviceId: responseData['deviceId']?.toString() ?? 'Unknown',
          deviceName: responseData['deviceNumber']?.toString() ?? 'POS1',
          systemCashSales: responseData['cashSales']?.toString() ?? '',
          manualCashSales: responseData['manualCashsales']?.toString() ?? '',
          cashSalesDifference:
              responseData['cashSalesDifference']?.toString() ?? '',
          systemClosingBalance:
              responseData['systemClosingBalance']?.toString() ?? '',
          manualClosingBalance:
              responseData['manualClosingBalance']?.toString() ?? '',
          closingAmountDifference:
              responseData['closingDifferenceAmount']?.toString() ?? '',
          closingShortageType:
              responseData['closingDifferenceType']?.toString() ?? '',
          cashSales: responseData['cashSales']?.toString() ?? '',
          cardSales: responseData['cardSales']?.toString() ?? '',
          upiSales: responseData['upiSales']?.toString() ?? '',
          zomatoSales: responseData['zomatoSales']?.toString() ?? '',
          swiggySales: responseData['swiggySales']?.toString() ?? '',
          otherSales: responseData['otherSales']?.toString() ?? '',
          totalSales: responseData['totalSales']?.toString() ?? '',
          kotSales: responseData['kotSales']?.toString() ?? '',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close shift: ${response.statusCode}'),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error closing shift')));
    }
  }

  Future<void> patchDayEndStatus(String shiftId) async {
    final String patchUrl = "https://yenerp.com/fastapi/shifts/$shiftId";

    final Map<String, dynamic> payload = {"dayEndStatus": "closed"};

    try {
      final response = await http.patch(
        Uri.parse(patchUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        fetchDayEndData(); // Refresh the data after updating
      } else {}
    } catch (error) {}
  }

  void _handleDayEndClose(BuildContext context) async {
    if (dayEndData['dayEndStatus'] == 'open') {
      // Fetch shift details and prepare data
      List<Map<String, String>> shiftDetails = await fetchShiftDetails();

      if (shiftDetails.isNotEmpty) {
        shiftDetails.forEach((shift) {
          shift.forEach((key, value) {});
        });
        // ignore: unused_local_variable
        String systemCash = calculateTotal(
          shiftDetails,
          'System Closing Balance',
        );
        // ignore: unused_local_variable
        String manualCash = calculateTotal(
          shiftDetails,
          'Manual Closing Balance',
        );
        // ignore: unused_local_variable
        String differences = calculateTotalDifferences(shiftDetails);

        Map<String, dynamic> postData = {
          "totalShifts": shiftDetails.length.toString(),
          "shiftId": shiftDetails.map((e) => e['shiftId']).toList(),
          "shiftNumbers": shiftDetails.map((e) => e['shiftNumber']).toList(),
          "shiftOpeningBalances":
              shiftDetails.map((e) => e['openingBalance']).toList(),
          "shiftSystemClosingBalances":
              shiftDetails.map((e) => e['systemClosingBalance']).toList(),
          "shiftManualClosingBalances":
              shiftDetails.map((e) => e['manualClosingBalance']).toList(),
          "shiftDifferenceAmounts":
              shiftDetails.map((e) => e['differenceAmount']).toList(),
          "shiftDifferenceTypes":
              shiftDetails.map((e) => e['differenceType']).toList(),
          "totalSystemClosingBalance":
              "Calculated Value", // Calculate or retrieve this value
          "totalManualClosingBalance": "Calculated Value",
          "totalDifferences": "Calculated Value",
          "differenceType":
              "overallDifferenceType", // Calculate or set this value
          "status": "closed",
          "dayEndDate": DateTime.now().toString(), // Use actual end date
          "branchId": "yourBranchId",
          "branchName": shiftDetails.map((e) => e['branchName']).toList(),
          "dayEndTime": DateTime.now().toString(), // Use actual end time
          "shiftOpeningDate":
              shiftDetails.map((e) => e['openingDate']).toList(),
          "shiftOpeningTime":
              shiftDetails.map((e) => e['openingTime']).toList(),
          "shiftClosingDate":
              shiftDetails.map((e) => e['closingDate']).toList(),
          "shiftClosingTime":
              shiftDetails.map((e) => e['closingTime']).toList(),
        };

        await postDayEndData(postData);

        // Call DayEndPrintService to print the bill
        await DayEndPrintService.printDayEndBill(
          context,
          branchName: dayEndData['branchName'] ?? 'Unknown',
          date: dayEndData['shiftClosingDate'] ?? 'Unknown',
          time: dayEndData['shiftClosingTime'] ?? 'Unknown',
          user: dayEndData['user'] ?? 'Admin',
          shiftDetails: shiftDetails,
          systemCash: calculateTotal(shiftDetails, 'System Closing Balance'),
          manualCash: calculateTotal(shiftDetails, 'Manual Closing Balance'),
          differences: calculateTotalDifferences(shiftDetails),
          cardSales: dayEndData['cardSales']?.toString() ?? '0',
          upiSales: dayEndData['upiSales']?.toString() ?? '0',
          swiggySales: dayEndData['swiggySales']?.toString() ?? '0',
          zomatoSales: dayEndData['zomatoSales']?.toString() ?? '0',
          otherSales: dayEndData['otherSales']?.toString() ?? '0',
          totalSales: calculateTotalSales(dayEndData),
          totalCash: calculateTotal(shiftDetails, 'System Closing Balance'),
          totalCard: dayEndData['cardSales']?.toString() ?? '0',
          totalUPI: dayEndData['upiSales']?.toString() ?? '0',
          cashReturn: '0', // If you have cash return logic, replace '0'
          cashInHand: calculateTotal(shiftDetails, 'System Closing Balance'),
          overallSales: calculateOverallSales(dayEndData),
        );

        // Update dayEndStatus to closed
        await patchDayEndStatus(dayEndData['shiftId']!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day End Closed and Receipt Printed!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No shifts available for Day End!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day End is already closed!')),
      );
    }
  }

  Widget _buildDayEndClosingContainer() {
    if (isDayEndLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dayEndData.isEmpty) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          'No data available for Day End Closing.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day End Closing Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildSummarySection(
                'Shift Number',
                dayEndData['shiftNumber'] ?? '0',
              ),
              _buildSummarySection(
                'Opening Date',
                dayEndData['shiftOpeningDate'] ?? '0',
              ),
              _buildSummarySection(
                'Opening Time',
                dayEndData['shiftOpeningTime'] ?? '0',
              ),
              _buildSummarySection(
                'Closing Date',
                dayEndData['shiftClosingDate'] ?? '0',
              ),
              _buildSummarySection(
                'Closing Time',
                dayEndData['shiftClosingTime'] ?? '0',
              ),
              _buildSummarySection(
                'System Opening Balance',
                '₹ ${dayEndData['systemOpeningBalance'] ?? '0'}',
              ),
              _buildSummarySection(
                'Manual Opening Balance',
                '₹ ${dayEndData['manualOpeningBalance'] ?? '0'}',
              ),
              _buildSummarySection(
                'System Closing Balance',
                '₹ ${dayEndData['systemClosingBalance'] ?? '0'}',
              ),
              _buildSummarySection(
                'Manual Closing Balance',
                '₹ ${dayEndData['manualClosingBalance'] ?? '0'}',
              ),
              _buildSummarySection(
                'dayEndStatus',
                dayEndData['dayEndStatus'] ?? 'open',
                color: dayEndData['dayEndStatus'] == 'closed'
                    ? Colors.red
                    : Colors.green,
              ),
              const SizedBox(height: 20),

              // Day End Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _handleDayEndClose(context),
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
                    child: Text(
                      dayEndData['dayEndStatus'] == 'closed'
                          ? 'Day End Closed'
                          : 'Close Day End',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> postDayEndData(Map<String, dynamic> dayEndData) async {
    final String url = 'https://yenerp.com/fastapi/dayends/';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dayEndData),
      );

      if (response.statusCode == 200) {
      } else {}
    } catch (e) {}
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Log Out", style: TextStyle(color: Colors.blue)),
          content: Text(
            "Are you sure you want to log out?",
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white, // Background color of the dialog
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.blue)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                backgroundColor: Colors.white, // Text color
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: Text('Log Out', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue, // Text color
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
                _navigateToLoginScreen(context); // Navigate to Login Screen
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToLoginScreen(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ),
    );
  }
}

Future<void> _postCustomerData(
  String name,
  String phone,
  BuildContext context,
) async {
  if (name.isEmpty || phone.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Name or phone cannot be empty!')));
    return;
  }

  final String url = 'https://yenerp.com/fastapi/customers/';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'customerName': name,
      'customerPhoneNumber': phone,
      "status": "1",
    }),
  );

  if (response.statusCode == 200) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Customer successfully added!')));
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to add customer')));
  }
}

String calculateDifference(String? systemClosing, String? manualClosing) {
  double system = double.tryParse(systemClosing ?? '0') ?? 0;
  double manual = double.tryParse(manualClosing ?? '0') ?? 0;
  return (system - manual).toStringAsFixed(2);
}

String calculateTotal(List<Map<String, String>> shifts, String key) {
  return shifts
      .map((shift) => double.tryParse(shift[key] ?? '0') ?? 0)
      .reduce((value, element) => value + element)
      .toStringAsFixed(2);
}

String calculateTotalDifferences(List<Map<String, String>> shifts) {
  return shifts
      .map(
        (shift) => double.tryParse(shift["Difference"] ?? '0')?.abs() ?? 0,
      ) // Handle abs
      .reduce((value, element) => value + element)
      .toStringAsFixed(2);
}

String calculateTotalSales(Map<String, dynamic> dayEndData) {
  List<String> keys = ['cardSales', 'upiSales', 'swiggySales', 'zomatoSales'];
  return keys
      .map((key) {
        final value = dayEndData[key];
        // Handle both String and double types
        if (value is String) {
          return double.tryParse(value) ?? 0;
        } else if (value is double) {
          return value;
        } else {
          return 0;
        }
      })
      .reduce((value, element) => value + element)
      .toStringAsFixed(2);
}

String calculateOverallSales(Map<String, dynamic> dayEndData) {
  List<String> keys = [
    'systemClosingBalance',
    'manualClosingBalance',
    'cardSales',
    'upiSales',
    'swiggySales',
    'zomatoSales',
  ];

  double total = keys.fold(0.0, (previousValue, key) {
    var value = dayEndData[key];
    if (value is String) {
      return previousValue + (double.tryParse(value) ?? 0.0);
    } else if (value is double) {
      return previousValue + value;
    } else {
      return previousValue;
    }
  });

  return total.toStringAsFixed(2);
}
