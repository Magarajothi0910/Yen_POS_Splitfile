import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class PinEntryWidget extends StatefulWidget {
  @override
  _PinEntryWidgetState createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: PinCodeTextField(
        appContext: context,
        length: 12, // Set the length of the PIN code
        controller: _controller,
        keyboardType: TextInputType.text,
        onChanged: (value) {
          // Optional: handle any action as the code is typed/pasted
        },

        onCompleted: (value) {
          // Triggered when all 12 fields are filled
        },
        textStyle: TextStyle(fontSize: 24),
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 60,
          fieldWidth: 60,
          activeFillColor: Colors.white,
        ),
      ),
    );
  }
}
