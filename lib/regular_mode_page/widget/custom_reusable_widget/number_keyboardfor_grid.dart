import 'package:flutter/material.dart';
import 'package:yen_pos/Global/Widget/custom_sized_box.dart';

class CalculatorUI1 extends StatefulWidget {
  final ValueChanged<String> onValueEntered;

  const CalculatorUI1({super.key, required this.onValueEntered});

  @override
  _CalculatorUI1State createState() => _CalculatorUI1State();
}

class _CalculatorUI1State extends State<CalculatorUI1> {
  String _output = "0";
  String _tempOutput = "0";
  double _num1 = 0;
  double _num2 = 0;
  String _operator = "";
  bool _isOperatorPressed = false;
  final _valueNotifier = ValueNotifier<String>("");
  void buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "C") {
        _output = "0";
        _tempOutput = "0";
        _num1 = 0;
        _num2 = 0;
        _operator = "";
        _isOperatorPressed = false;
      } else if (buttonText == "+" ||
          buttonText == "-" ||
          buttonText == "*" ||
          buttonText == "/") {
        _num1 = double.parse(_output);
        _operator = buttonText;
        _tempOutput = "0";
        _isOperatorPressed = true;
      } else if (buttonText == ".") {
        if (!_tempOutput.contains(".")) {
          _tempOutput = _tempOutput + buttonText;
        }
      } else if (buttonText == "=") {
        _num2 = double.parse(_output);

        if (_operator == "+") {
          _output = (_num1 + _num2).toString();
        } else if (_operator == "-") {
          _output = (_num1 - _num2).toString();
        } else if (_operator == "*") {
          _output = (_num1 * _num2).toString();
        } else if (_operator == "/") {
          _output = (_num1 / _num2).toString();
        }

        _num1 = 0;
        _num2 = 0;
        _operator = "";
        _isOperatorPressed = false;
      } else if (buttonText == "<") {
        // Clear the last digit one by one
        if (_tempOutput.length > 1) {
          _tempOutput = _tempOutput.substring(0, _tempOutput.length - 1);
        } else {
          _tempOutput = "0"; // If only one digit is left, reset to "0"
        }
        _output = _tempOutput;
      } else {
        if (_isOperatorPressed) {
          _tempOutput = _tempOutput == "0"
              ? buttonText
              : _tempOutput + buttonText;
        } else {
          _tempOutput = _tempOutput == "0"
              ? buttonText
              : _tempOutput + buttonText;
        }
        _output = _tempOutput;
      }

      // Pass the output to the parent widget
      widget.onValueEntered(_output);
    });
    setState(() {
      //...
      widget.onValueEntered(_output);
      _valueNotifier.value = _output;
    });
  }

  Widget buildButton(String buttonText) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(15.0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          ),
          onPressed: () => buttonPressed(buttonText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: _output,
            hintStyle: const TextStyle(
              fontSize: 36.0,
              fontWeight: FontWeight.bold,
            ),
            border: const OutlineInputBorder(),
          ),
          textAlign: TextAlign.right,
        ),
        const CustomSizedBox(height: 10),
        Expanded(
          child: Column(
            children: [
              Row(
                children: <Widget>[
                  buildButton("7"),
                  buildButton("8"),
                  buildButton("9"),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton("4"),
                  buildButton("5"),
                  buildButton("6"),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton("1"),
                  buildButton("2"),
                  buildButton("3"),
                ],
              ),
              Row(
                children: <Widget>[
                  buildButton("0"),
                  buildButton("."),
                  buildButton("00"),
                ],
              ),
              Row(children: <Widget>[buildButton("C"), buildButton("<")]),
            ],
          ),
        ),
      ],
    );
  }
}
