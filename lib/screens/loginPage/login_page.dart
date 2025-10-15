import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Global/globals_data.dart' as globals;
import '../../services/branchwise_item_fetch.dart';
import '../choose_mode/choose_mode_screen.dart';
import '../shift_managment_page/openshift/open_shift.dart';
import 'provider/branch_select_provider.dart';
import 'widgets/SearchableDropdown_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

import 'widgets/pin_filed.dart';

// class LogInScreen extends StatefulWidget {
//   const LogInScreen({super.key});

//   @override
//   _LogInScreenState createState() => _LogInScreenState();
// }

// class _LogInScreenState extends State<LogInScreen> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final bool _rememberMe = false;
//   String? _selectedBranch;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<ItemProvider>(context, listen: false).fetchDataIfNeeded();
//     });
//   }

//   void _openBranchSelectDialog() async {
//     final List<String> branchNames =
//         Provider.of<ItemProvider>(context, listen: false).getBranchNames();
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           title: const Text('Select Branch'),
//           content: ChangeNotifierProvider(
//             create: (_) => BranchFilterProvider(branchNames),
//             child: SearchableDropdown(
//               onSelect: (selected) {
//                 setState(() {
//                   _selectedBranch = selected;
//                 });
//                 Navigator.of(context).pop();
//               },
//               branchNames: branchNames,
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _handleSignIn() async {
//     if (_selectedBranch != null) {
//       final aliasName = await Provider.of<ItemProvider>(context, listen: false)
//           .getAliasName(_selectedBranch!);

//       if (aliasName != null) {
//         await Provider.of<ItemProvider>(context, listen: false)
//             .fetchDataIfNeeded(branchAlias: aliasName);
//       }
//     }
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const ChooseModePage(),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     List<ConnectivityResult> status =
//         Provider.of<ConnectivityProvider>(context).connectionStatus;
//     bool isOffline = status.contains(ConnectivityResult.none);
//     String connectionMessage = isOffline ? "Offline" : "Online";
//     IconData connectionIcon =
//         isOffline ? Icons.signal_wifi_off : Icons.signal_wifi_4_bar;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Icon(connectionIcon,
//                     color: isOffline ? Colors.red : Colors.green),
//                 const SizedBox(width: 8),
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: isOffline ? Colors.red : Colors.green,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     connectionMessage,
//                     style: const TextStyle(color: Colors.white, fontSize: 12),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Row(
//         children: <Widget>[
//           Expanded(
//             flex: 1,
//             child: RepaintBoundary(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage("assets/pos1.png"),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(32.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: <Widget>[
//                   const Text(
//                     'Log In',
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 30.0,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const CustomSizedBox(height: 40.0),
//                   RepaintBoundary(
//                     child: TextField(
//                       controller: _emailController,
//                       decoration: InputDecoration(
//                         labelText: 'Device Id',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 20, vertical: 18),
//                       ),
//                     ),
//                   ),
//                   const CustomSizedBox(height: 20.0),
//                   const CustomSizedBox(height: 30.0),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       foregroundColor: Colors.white,
//                       backgroundColor: Colors.blue,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 100, vertical: 20),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       elevation: 4,
//                     ),
//                     onPressed: _handleSignIn,
//                     child: const Text('Log In'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Retrieve employee data from Hive
Future<List<dynamic>> _getEmployeesFromHive() async {
  var box = await Hive.openBox('employeeBox');
  return box.get('employees', defaultValue: []);
}

class LogInScreen extends StatefulWidget {
  final GlobalKey keyboardKey;
  const LogInScreen({super.key, required this.keyboardKey});

  @override
  _LogInScreenState createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  String enteredDeviceId = '';
  final String loginId = "7373"; // Expected device login ID
  bool showEmployeeField =
      false; // Flag to show employee input after device login
  bool deviceIdVerified = false; // To track if the device ID is correct
  bool employeeIdVerified = false; // To track if the employee ID is correct
  List<String> _suggestions = [];
  bool _isLoading = false;
  String _selectedEmployee = ''; // Track the selected employee
  String? _selectedBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ItemProvider>(context, listen: false).fetchDataIfNeeded();
      _showPinEntryDialog(
          context); // Show PIN entry dialog after everything is loaded
    });
    _fetchAndSaveEmployees(); // Fetch and save employee data in Hive
  }

  void _handleDialpadPress(String value) {
    setState(() {
      if (value == 'clear') {
        enteredDeviceId = '';
        deviceIdVerified = false; // Reset the device ID verification
      } else if (value == 'back') {
        if (enteredDeviceId.isNotEmpty) {
          enteredDeviceId =
              enteredDeviceId.substring(0, enteredDeviceId.length - 1);
        }
        deviceIdVerified = false; // Reset verification if text is modified
      } else {
        enteredDeviceId += value;
      }
      _deviceIdController.text = enteredDeviceId;
    });
  }

  // Fetch employee data from API and save it in Hive
  Future<void> _fetchAndSaveEmployees() async {
    const String apiUrl = 'https://yenerp.com/fastapi/employees/';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> employeeData = json.decode(response.body);

        // Open Hive box and store employee data
        var box = await Hive.openBox('employeeBox');
        await box.put('employees', employeeData);
      } else {}
    } catch (e) {}
  }

  // Function to fetch suggestions from FastAPI
  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
        'https://yenerp.com/fastapi/employees/search-by/?searchQuery=$query');
    final response = await http.get(url);
    developer.log(response.body);
    if (response.statusCode == 200) {
      setState(() {
        _suggestions = List<String>.from(json.decode(response.body));
        _isLoading = false;
      });
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final List<String> branchNames =
        Provider.of<ItemProvider>(context, listen: false).getBranchNames();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.signal_wifi_4_bar, color: Colors.green),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Online",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: RepaintBoundary(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/pos1.png"),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 30.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20.0),
                  // Show dialpad until the correct device ID is entered
                  // if (!showEmployeeField) const SizedBox(height: 30.0),
                  // Show the employee number input if the device ID is correct
                  if (!showEmployeeField)
                    Column(
                      children: [
                        TextField(
                          controller: _employeeIdController,
                          onChanged: (value) {
                            _fetchSuggestions(value);
                          },
                          decoration: InputDecoration(
                            labelText: 'Search Employee',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isLoading
                                ? const CircularProgressIndicator()
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _employeeIdController.clear();
                                      setState(() {
                                        _suggestions = [];
                                        _selectedEmployee =
                                            ''; // Reset employee
                                      });
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        RepaintBoundary(
                          child: ListTile(
                            title: Text(_selectedBranch ?? 'Select Branch'),
                            trailing: const Icon(Icons.arrow_drop_down),
                            onTap: _openBranchSelectDialog,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_suggestions.isNotEmpty)
                          SizedBox(
                            height: 200, // Adjust the height as needed
                            child: ListView.builder(
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(_suggestions[index]),
                                  onTap: () {
                                    setState(() {
                                      _selectedEmployee = _suggestions[index];
                                      _employeeIdController.text =
                                          _selectedEmployee;
                                      _suggestions = [];
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Enable button only when employee is selected
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 100, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _selectedEmployee.isNotEmpty
                              ? _handleEmployeeSubmit
                              : null, // Enable when employee is selected
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  // Log In button for Device ID (if employee number is not shown yet)
                  // if (!showEmployeeField)
                  //   ElevatedButton(
                  //     style: ElevatedButton.styleFrom(
                  //       foregroundColor: Colors.white,
                  //       backgroundColor: Colors.blue,
                  //       padding: const EdgeInsets.symmetric(
                  //           horizontal: 100, vertical: 20),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //       elevation: 4,
                  //     ),
                  //     onPressed: enteredDeviceId.isEmpty ? _handleSignIn : null,
                  //     child: const Text('Log In'),
                  //   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinEntryDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => Center(),
      barrierDismissible: false,
      barrierLabel: "Dismiss",
      transitionDuration: Duration(milliseconds: 350),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticInOut),
          child: Dialog(
            backgroundColor:
                Colors.white, // Adjust the background color as needed
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 12,
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 28, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text(
                        'Enter Device Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  PinEntryWidget(), // Your custom PIN entry widget
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Dismiss the dialog
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue, // Button color

                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                    ),
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Handle Device ID sign-in

  void _handleSignIn() async {
    if (enteredDeviceId == loginId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Device ID Verified. Please enter your Employee Number.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        deviceIdVerified = true; // Mark device ID as verified
        showEmployeeField = true; // Show the employee number field
      });
      await _openBranchSelectDialog(); // Make sure branch is selected
    } else {
      setState(() {
        deviceIdVerified = true; // Mark device ID as verified
        showEmployeeField = true; // Show the employee number field
      });
    }
  }

// Handle Employee ID submission
  void _handleEmployeeSubmit() async {
    if (_selectedBranch != null) {
      final aliasName = await Provider.of<ItemProvider>(context, listen: false)
          .getAliasName(_selectedBranch!);

      if (aliasName != null) {
        await Provider.of<ItemProvider>(context, listen: false)
            .fetchDataIfNeeded(branchAlias: aliasName);
      }
    }

    if (_selectedEmployee.isNotEmpty) {
      setState(() {
        employeeIdVerified = true; // Mark employee ID as verified
      });

      // Check shift status after selecting the employee and branch
      bool hasOpenShift = await _checkShiftStatusAndNavigate();

      // If there's no open shift, navigate to OpenShift
      if (!hasOpenShift) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => OpenShift(
                    key: widget.keyboardKey,
                  )),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid Employee ID.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openBranchSelectDialog() async {
    final List<String> branchNames =
        Provider.of<ItemProvider>(context, listen: false).getBranchNames();
    String? selectedBranch = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Select Branch'),
          content: ChangeNotifierProvider(
            create: (_) => BranchFilterProvider(branchNames),
            child: SearchableDropdown(
              onSelect: (selected) {
                Navigator.of(context).pop(selected);
              },
              branchNames: branchNames,
            ),
          ),
        );
      },
    );
    setState(() {
      _selectedBranch = selectedBranch;
    });
  }

  Future<bool> _checkShiftStatusAndNavigate() async {
    final branchName = globals.branchName;
    final todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final url = Uri.parse(
        'https://yenerp.com/fastapi/shifts/check-open-shift?branch_name=$branchName');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Store shiftId and shiftNumber in ValueNotifiers
        globals.shiftId.value = data['shiftId']?.toString() ?? '0';
        globals.shiftNumber.value = data['shiftNumber']?.toString() ?? '0';

        if (globals.shiftNumber.value != '0') {
          // Open shift found — navigate
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChooseModePage(
                keyboardKey: widget.keyboardKey,
              ),
            ),
          );
          return true;
        } else {
          // No open shift
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No open shift found for today.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch shift data.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return false;
  }
}




  // Custom Dialpad Widget
  // Widget buildDialPad() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 16.0),
  //     child: GridView.builder(
  //       shrinkWrap: true,
  //       physics: const NeverScrollableScrollPhysics(),
  //       itemCount: 12,
  //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //         crossAxisCount: 3,
  //         mainAxisSpacing: 8,
  //         crossAxisSpacing: 1,
  //         childAspectRatio: 3,
  //       ),
  //       itemBuilder: (context, index) {
  //         String buttonText;
  //         IconData? buttonIcon;
  //         bool isIcon = false;

  //         if (index < 9) {
  //           buttonText = (index + 1).toString();
  //         } else if (index == 9) {
  //           buttonText = 'Clear';
  //         } else if (index == 10) {
  //           buttonText = '0';
  //         } else {
  //           isIcon = true;
  //           buttonText = '<-';
  //           buttonIcon = Icons.backspace_outlined;
  //         }

  //         return ElevatedButton(
  //           onPressed: () {
  //             if (buttonText == 'Clear') {
  //               _handleDialpadPress('clear');
  //             } else if (buttonText == '<-') {
  //               _handleDialpadPress('back');
  //             } else {
  //               _handleDialpadPress(buttonText);
  //             }
  //           },
  //           style: ElevatedButton.styleFrom(
  //             minimumSize: const Size(50, 50),
  //             padding: const EdgeInsets.all(8),
  //             backgroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(6),
  //             ),
  //             elevation: 3,
  //           ),
  //           child: isIcon
  //               ? Icon(
  //                   buttonIcon,
  //                   size: 22,
  //                   color: Colors.blue,
  //                 )
  //               : Text(
  //                   buttonText,
  //                   style: const TextStyle(
  //                     fontSize: 20,
  //                     fontWeight: FontWeight.bold,
  //                     color: Colors.black,
  //                   ),
  //                 ),
  //         );
  //       },
  //     ),
  //   );
  // }





// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../Global/custom_sized_box.dart';
// import '../../connectivity/connectivity_internet.dart';
// import '../../services/branchwise_item_fetch.dart';
// import '../shift_managment_page/openshift/open_shift.dart';
// import 'provider/branch_select_provider.dart';
// import 'widgets/SearchableDropdown_widget.dart';

// class LogInScreen extends StatefulWidget {
//   const LogInScreen({super.key});

//   @override
//   _LogInScreenState createState() => _LogInScreenState();
// }

// class _LogInScreenState extends State<LogInScreen> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final bool _rememberMe = false;
//   String? _selectedBranch;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<ItemProvider>(context, listen: false).fetchDataIfNeeded();
//     });
//   }

//   void _openBranchSelectDialog() async {
//     final List<String> branchNames =
//         Provider.of<ItemProvider>(context, listen: false).getBranchNames();
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           title: const Text('Select Branch'),
//           content: ChangeNotifierProvider(
//             create: (_) => BranchFilterProvider(branchNames),
//             child: SearchableDropdown(
//               onSelect: (selected) {
//                 setState(() {
//                   _selectedBranch = selected;
//                 });
//                 Navigator.of(context).pop();
//               },
//               branchNames: branchNames,
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _handleSignIn() async {
//     if (_selectedBranch != null) {
//       final aliasName = await Provider.of<ItemProvider>(context, listen: false)
//           .getAliasName(_selectedBranch!);

//       if (aliasName != null) {
//         await Provider.of<ItemProvider>(context, listen: false)
//             .fetchDataIfNeeded(branchAlias: aliasName);
//       }
//     }
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const OpenShift(),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     List<ConnectivityResult> status =
//         Provider.of<ConnectivityProvider>(context).connectionStatus;
//     bool isOffline = status.contains(ConnectivityResult.none);
//     String connectionMessage = isOffline ? "Offline" : "Online";
//     IconData connectionIcon =
//         isOffline ? Icons.signal_wifi_off : Icons.signal_wifi_4_bar;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       // appBar: AppBar(
//       //   backgroundColor: Colors.white,
//       //   actions: [
//       //     Padding(
//       //       padding: const EdgeInsets.all(8.0),
//       //       child: Row(
//       //         children: [
//       //           Icon(connectionIcon,
//       //               color: isOffline ? Colors.red : Colors.green),
//       //           const SizedBox(width: 8),
//       //           Container(
//       //             padding:
//       //                 const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       //             decoration: BoxDecoration(
//       //               color: isOffline ? Colors.red : Colors.green,
//       //               borderRadius: BorderRadius.circular(12),
//       //             ),
//       //             child: Text(
//       //               connectionMessage,
//       //               style: const TextStyle(color: Colors.white, fontSize: 12),
//       //             ),
//       //           ),
//       //         ],
//       //       ),
//       //     ),
//       //   ],
//       // ),
//       body: Row(
//         children: <Widget>[
//           Expanded(
//             flex: 1,
//             child: RepaintBoundary(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage("assets/pos1.png"),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(32.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: <Widget>[
//                   const Text(
//                     'Log In',
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 30.0,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const CustomSizedBox(height: 40.0),
//                   RepaintBoundary(
//                     child: TextField(
//                       controller: _emailController,
//                       decoration: InputDecoration(
//                         labelText: 'Device Id',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 20, vertical: 18),
//                       ),
//                     ),
//                   ),
//                   const CustomSizedBox(height: 20.0),
//                   RepaintBoundary(
//                     child: TextField(
//                       controller: _passwordController,
//                       decoration: InputDecoration(
//                         labelText: 'Login Id',
//                         hintText: 'example@gmail.com',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 20, vertical: 18),
//                       ),
//                     ),
//                   ),
//                   const CustomSizedBox(height: 20.0),
//                   RepaintBoundary(
//                     child: ListTile(
//                       title: Text(_selectedBranch ?? 'Select Branch'),
//                       trailing: const Icon(Icons.arrow_drop_down),
//                       onTap: _openBranchSelectDialog,
//                     ),
//                   ),
//                   const CustomSizedBox(height: 30.0),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       foregroundColor: Colors.white,
//                       backgroundColor: Colors.blue,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 100, vertical: 20),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       elevation: 4,
//                     ),
//                     onPressed: _handleSignIn,
//                     child: const Text('Log In'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
