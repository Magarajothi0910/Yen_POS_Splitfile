import 'package:flutter/material.dart';
import 'package:yenpos/Mode_page/Express_mode/bottom_navigaton_bar_for_expressMode.dart';
import '../Global/Widget/custom_sized_box.dart';

class ChooseModePage extends StatelessWidget {
  const ChooseModePage({super.key});

  @override
  Widget build(BuildContext context) {
    print("🟩 [ChooseModePage] Widget built successfully");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: const BoxDecoration(color: Colors.white),
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
                  // EXPRESS MODE BUTTON
                  OutlinedButton(
                    onPressed: () {
                      print("⚡ [ChooseModePage] Express Mode button clicked");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            print(
                              "➡️ [ChooseModePage] Navigating to Express Mode screen...",
                            );
                            return BottomNavigationPageExpressModeScreen();
                          },
                        ),
                      ).then((_) {
                        print(
                          "⬅️ [ChooseModePage] Returned from Express Mode screen",
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
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
                    ),
                    child: const Text(
                      'Express  Mode',
                      style: TextStyle(fontSize: 20, letterSpacing: 1),
                    ),
                  ),
                  const CustomSizedBox(width: 20),
                  // REGULAR MODE BUTTON
                  OutlinedButton(
                    onPressed: () {
                      print("🕓 [ChooseModePage] Regular Mode button clicked");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            print(
                              "➡️ [ChooseModePage] Navigating to Regular Mode screen...",
                            );
                            return BottomNavigationPageExpressModeScreen();
                          },
                        ),
                      ).then((_) {
                        print(
                          "⬅️ [ChooseModePage] Returned from Regular Mode screen",
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
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
