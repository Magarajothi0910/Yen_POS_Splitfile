import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showInitialPopup(BuildContext context, String tableNumber,
    String seat, Function(String) onPhoneNumberEntered,
    {String initialPhoneNumber = ""}) async {
  // Accepts initial phone number

  TextEditingController mobileController =
      TextEditingController(text: initialPhoneNumber);
  String? errorMessage;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            titlePadding: EdgeInsets.zero,
            title: Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Text(
                    "    You are currently managing \n   orders for $tableNumber - Seat $seat",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Enter Customer Mobile Numbers",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter
                        .digitsOnly, // ✅ Allows only numbers
                  ],
                  decoration: InputDecoration(
                    hintText: "Enter valid 10-digit mobile number",
                    prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    errorText: errorMessage,
                  ),
                  onChanged: (value) {
                    setStateDialog(() {
                      errorMessage = null; // Reset error on typing
                    });
                  },
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    String enteredNumber = mobileController.text;

                    // ✅ Validation: Ensure exactly 10 digits and starts with 6-9
                    if (enteredNumber.length != 10) {
                      setStateDialog(() {
                        errorMessage = "Number must be exactly 10 digits";
                      });
                      return;
                    }

                    if (!RegExp(r"^[6-9]\d{9}$").hasMatch(enteredNumber)) {
                      setStateDialog(() {
                        errorMessage =
                            "Enter a valid mobile number (Starts with 6-9)";
                      });
                      return;
                    }

                    onPhoneNumberEntered(
                        enteredNumber); // ✅ Save valid phone number
                    Navigator.of(context).pop(); // Close popup
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[300],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                  ),
                  child: const Text("Confirm",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
