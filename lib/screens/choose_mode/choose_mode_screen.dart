import 'package:flutter/material.dart';
import '../../Global/custom_sized_box.dart';
import '../bottomNavigation_Regular_Page/widgets/bottom_navigaton_bar_for_expressMode.dart';

class ChooseModePage extends StatelessWidget {
  final GlobalKey keyboardKey;
  const ChooseModePage({super.key, required this.keyboardKey});

  @override
  Widget build(BuildContext context) {
    // List<ConnectivityResult> status =
    //     Provider.of<ConnectivityProvider>(context).connectionStatus;

    // // Determine connection status message
    // String connectionMessage =
    //     status.contains(ConnectivityResult.none) ? "Offline" : "Online";
    // print(connectionMessage); // Print to console
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
              const Text(
                'Choose Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const CustomSizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BottomNavigationPageExpressModeScreen(
                              keyboardKey: keyboardKey,
                            ),
                          ));
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
                    child: const Text(
                      'Express  Mode',
                      style: TextStyle(fontSize: 20, letterSpacing: 1),
                    ),
                  ),
                  const CustomSizedBox(width: 20),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BottomNavigationPageExpressModeScreen(
                              keyboardKey: keyboardKey,
                            ),
                          ));
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
                    child: const Text(
                      'Regular  Mode',
                      style: TextStyle(fontSize: 20, letterSpacing: 1),
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
}
