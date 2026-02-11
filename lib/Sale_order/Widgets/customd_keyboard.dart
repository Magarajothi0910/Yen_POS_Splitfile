import 'package:flutter/material.dart';

class NumericKeyboard extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final Function(String)? onTextInput;
  final VoidCallback? onBackspace;
  final VoidCallback? onOk;
  final bool isLastField;

  const NumericKeyboard({
    super.key,
    required this.focusNode,
    required this.controller,
    this.onTextInput,
    this.onBackspace,
    this.onOk,
    this.isLastField = false,
  });

  void _textInputHandler(String text) {
    if (onTextInput != null) {
      onTextInput!(text);
    } else {
      final currentText = controller.text;
      final newText = currentText + text;
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: newText.length);
    }
  }

  void _backspaceHandler() {
    if (onBackspace != null) {
      onBackspace!();
    } else {
      final currentText = controller.text;
      if (currentText.isNotEmpty) {
        final newText = currentText.substring(0, currentText.length - 1);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7', () => _textInputHandler('7')),
            _buildKey('8', () => _textInputHandler('8')),
            _buildKey('9', () => _textInputHandler('9')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4', () => _textInputHandler('4')),
            _buildKey('5', () => _textInputHandler('5')),
            _buildKey('6', () => _textInputHandler('6')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('1', () => _textInputHandler('1')),
            _buildKey('2', () => _textInputHandler('2')),
            _buildKey('3', () => _textInputHandler('3')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('0', () => _textInputHandler('0'), flex: 2),
            _buildKey('⌫', _backspaceHandler, flex: 2),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('OK', onOk!,
                isAction: true, isEnabled: onOk != null, flex: 1),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, VoidCallback onPressed,
      {int flex = 1, bool isAction = false, bool isEnabled = true}) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isAction ? Colors.blue : Colors.white,
            foregroundColor: isAction ? Colors.white : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[400],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
