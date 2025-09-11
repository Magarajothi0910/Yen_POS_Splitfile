import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import '../../../Global/globals_data.dart';
import '../../choose_mode/choose_mode_screen.dart';

class OpenShift extends StatefulWidget {
  final GlobalKey keyboardKey;
  const OpenShift({super.key, required this.keyboardKey});

  @override
  _OpenShiftState createState() => _OpenShiftState();
}

class _OpenShiftState extends State<OpenShift> {
  @override
  void initState() {
    _fetchCurrentDateTime();
    super.initState();
  }

  // Controllers for denomination text fields
  final TextEditingController _controller500 = TextEditingController();
  final TextEditingController _controller200 = TextEditingController();
  final TextEditingController _controller100 = TextEditingController();
  final TextEditingController _controller50 = TextEditingController();
  final TextEditingController _controller20 = TextEditingController();
  final TextEditingController _controller10 = TextEditingController();
  final TextEditingController _controller5 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller1 = TextEditingController();
  final String pettyCash = "3000";
  bool isShiftOpened = false; // Flag to track shift status

  // Variables to hold totals
  int _total500 = 0;
  int _total200 = 0;
  int _total100 = 0;
  int _total50 = 0;
  int _total20 = 0;
  int _total10 = 0;
  int _total5 = 0;
  int _total2 = 0;
  int _total1 = 0;

  String currentDate = "";
  String currentTime = "";

  // Fetch current date and time from API
  Future<void> _fetchCurrentDateTime() async {
    final url = Uri.parse('https://yenerp.com/liveapi/datetime');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        currentDate = data["current_date"];
        currentTime = data["current_time"];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch date and time.')),
      );
    }
  }

  // Function to update totals based on denomination
  void _updateTotal(int denomination, TextEditingController controller,
      Function(int) updateTotalCallback) {
    setState(() {
      int count = int.tryParse(controller.text) ?? 0;
      updateTotalCallback(count * denomination);
    });
  }

  // Function to calculate grand total
  int _calculateGrandTotal() {
    return _total500 +
        _total200 +
        _total100 +
        _total50 +
        _total20 +
        _total10 +
        _total5 +
        _total2 +
        _total1;
  }

  // Function to calculate the difference between petty cash and the total
  Future<void> _postShiftData(int manualOpeningBalance) async {
    final url = Uri.parse('https://yenerp.com/fastapi/shifts/');
    final openingDifferenceAmount = _calculateDifference();
    final openingDifferenceType = openingDifferenceAmount > 0
        ? "excess"
        : (openingDifferenceAmount < 0 ? "shortage" : "no difference");

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "shiftNumber": 1,
        "shiftOpeningDate": "$currentDate",
        "shiftOpeningTime": "$currentTime",
        "systemOpeningBalance": 3000, // add branch petty cash
        "manualOpeningBalance": manualOpeningBalance,
        "openingDifferenceAmount": openingDifferenceAmount,
        "openingDifferenceType": openingDifferenceType,
        "dayEndStatus": "open",
        "status": "open",
        "branchId": 1,
        "branchName": branchName,
        "shiftOpenId": "",
        "shiftOpenName": "",
        "deviceId": 2,
        "deviceNumber": 1,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        isShiftOpened = true; // Set the shift opened flag to true
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift created and data posted successfully!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to create shift. Error: ${response.statusCode}'),
        ),
      );
    }
  }

  int _calculateDifference() {
    int grandTotal = _calculateGrandTotal();
    int pettyCashValue = int.tryParse(pettyCash) ?? 0;
    return grandTotal - pettyCashValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display the totals and difference only when shift is opened
              if (isShiftOpened) _buildOpeningCashDetails(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      if (!isShiftOpened) {
                        _showShiftDialog(context);
                      } else {
                        _navigateToChooseMode(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 25),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isShiftOpened ? 'Good Day to Start' : 'Open The Shift',
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 1,
                      ),
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

  // Build the widget to display the totals and difference
  Widget _buildOpeningCashDetails() {
    return Column(
      children: [
        Text(
          'Actual Opening Cash: ${_calculateGrandTotal()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Physical Opening Cash: ${_calculateGrandTotal()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Difference: ${_calculateDifference()}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _calculateDifference() > 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  // Function to show the denomination entry dialog
  void _showShiftDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Denomination'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDataTable2(setState),
                    const SizedBox(height: 20),
                    // Display the grand total at the bottom of the table
                    Text(
                      'Total: ${_calculateGrandTotal()}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the main dialog
                  },
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    _showConfirmationDialog(
                        context); // Show the confirmation dialog
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Function to show the confirmation dialog
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text('Do you want to create the shift?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the confirmation dialog
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the confirmation dialog

                // Get the grand total and pass it as the manualOpeningBalance
                int grandTotal = _calculateGrandTotal();
                _postShiftData(grandTotal); // Post the data

                Navigator.of(context).pop(); // Close the main dialog
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Function to build the data table with editable text fields and total calculation
  Widget _buildDataTable2(void Function(void Function()) setState) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Cash')),
        DataColumn(label: Text('Denomination')),
        DataColumn(label: Text('Total')),
      ],
      rows: [
        DataRow(cells: [
          const DataCell(Text('500*')),
          DataCell(TextField(
            controller: _controller500,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  500, _controller500, (total) => _total500 = total, setState);
            },
          )),
          DataCell(Text('$_total500')),
        ]),
        DataRow(cells: [
          const DataCell(Text('200*')),
          DataCell(TextField(
            controller: _controller200,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  200, _controller200, (total) => _total200 = total, setState);
            },
          )),
          DataCell(Text('$_total200')),
        ]),
        DataRow(cells: [
          const DataCell(Text('100*')),
          DataCell(TextField(
            controller: _controller100,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  100, _controller100, (total) => _total100 = total, setState);
            },
          )),
          DataCell(Text('$_total100')),
        ]),
        DataRow(cells: [
          const DataCell(Text('50*')),
          DataCell(TextField(
            controller: _controller50,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  50, _controller50, (total) => _total50 = total, setState);
            },
          )),
          DataCell(Text('$_total50')),
        ]),
        DataRow(cells: [
          const DataCell(Text('20*')),
          DataCell(TextField(
            controller: _controller20,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  20, _controller20, (total) => _total20 = total, setState);
            },
          )),
          DataCell(Text('$_total20')),
        ]),
        DataRow(cells: [
          const DataCell(Text('10*')),
          DataCell(TextField(
            controller: _controller10,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  10, _controller10, (total) => _total10 = total, setState);
            },
          )),
          DataCell(Text('$_total10')),
        ]),
        DataRow(cells: [
          const DataCell(Text('5*')),
          DataCell(TextField(
            controller: _controller5,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  5, _controller5, (total) => _total5 = total, setState);
            },
          )),
          DataCell(Text('$_total5')),
        ]),
        DataRow(cells: [
          const DataCell(Text('2*')),
          DataCell(TextField(
            controller: _controller2,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  2, _controller2, (total) => _total2 = total, setState);
            },
          )),
          DataCell(Text('$_total2')),
        ]),
        DataRow(cells: [
          const DataCell(Text('1*')),
          DataCell(TextField(
            controller: _controller1,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
            onChanged: (value) {
              _updateTotalWithDialogState(
                  1, _controller1, (total) => _total1 = total, setState);
            },
          )),
          DataCell(Text('$_total1')),
        ]),
      ],
    );
  }

  // Function to update totals based on denomination within the dialog's state
  void _updateTotalWithDialogState(
      int denomination,
      TextEditingController controller,
      Function(int) updateTotalCallback,
      void Function(void Function()) setState) {
    setState(() {
      int count = int.tryParse(controller.text) ?? 0;
      updateTotalCallback(count * denomination);
    });
  }

  // Function to navigate to ChooseModePage
  void _navigateToChooseMode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChooseModePage(
                keyboardKey: widget.keyboardKey,
              )), // Change ChooseModePage to your actual widget class
    );
  }
}
