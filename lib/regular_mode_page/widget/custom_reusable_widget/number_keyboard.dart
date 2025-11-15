// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';

class CalculatorUI extends StatefulWidget {
  final ValueChanged<String> onValueEntered;
  String? uom;

  CalculatorUI({super.key, required this.onValueEntered, this.uom});

  @override
  _CalculatorUIState createState() => _CalculatorUIState();
}

class _CalculatorUIState extends State<CalculatorUI> {
  String _output = "0";
  String _tempOutput = "0";
  double _num1 = 0;
  double _num2 = 0;
  String _operator = "";
  // ignore: unused_field
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
        if (!_tempOutput.contains(".") && widget.uom!.toLowerCase() != 'pcs') {
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
        if (_tempOutput.length > 1) {
          _tempOutput = _tempOutput.substring(0, _tempOutput.length - 1);
        } else {
          _tempOutput = "0";
        }
        _output = _tempOutput;
      } else {
        _tempOutput =
            _tempOutput == "0" ? buttonText : _tempOutput + buttonText;
        _output = _tempOutput;
      }

      widget.onValueEntered(_output);
      _valueNotifier.value = _output;
    });
  }

  Widget buildButton(String buttonText) {
    bool shouldShowButton = buttonText != '.' ||
        widget.uom!.toLowerCase() != 'pcs' &&
            widget.uom!.toLowerCase() != 'pkt';

    return shouldShowButton
        ? Expanded(
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
                  style: const TextStyle(
                      fontSize: 24.0, fontWeight: FontWeight.bold),
                ),
                onPressed: () => buttonPressed(buttonText),
              ),
            ),
          )
        : const Spacer(); // Return a spacer if '.' should not be displayed for 'pcs'
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: _output,
            hintStyle:
                const TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold),
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
              Row(
                children: <Widget>[
                  buildButton("C"),
                  buildButton("<"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
