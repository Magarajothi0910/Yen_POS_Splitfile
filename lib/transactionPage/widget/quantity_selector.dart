import 'package:flutter/material.dart';

class QuantitySelector extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final Function(int) onQuantityChanged;

  const QuantitySelector({
    Key? key,
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  _QuantitySelectorState createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late TextEditingController _controller;
  late int currentQuantity;

  @override
  void initState() {
    super.initState();
    currentQuantity = widget.initialQuantity;
    _controller = TextEditingController(text: currentQuantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    if (currentQuantity < widget.maxQuantity) {
      setState(() {
        currentQuantity++;
        _controller.text = currentQuantity.toString();
        widget.onQuantityChanged(currentQuantity);
      });
    }
  }

  void _decrement() {
    if (currentQuantity > 0) {
      setState(() {
        currentQuantity--;
        _controller.text = currentQuantity.toString();
        widget.onQuantityChanged(currentQuantity);
      });
    }
  }

  void _onChanged(String value) {
    int? newQuantity = int.tryParse(value);
    if (newQuantity == null || newQuantity < 0) {
      newQuantity = 0; // Ensure non-negative input
    } else if (newQuantity > widget.maxQuantity) {
      newQuantity =
          widget.maxQuantity; // Ensure quantity does not exceed maximum
    }

    setState(() {
      currentQuantity = newQuantity!;
      _controller.text = currentQuantity
          .toString(); // Update the text field with corrected value
      widget.onQuantityChanged(currentQuantity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.remove), onPressed: _decrement),
        Expanded(
          child: TextField(
            textAlign: TextAlign.center,
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8.0),
            ),
            onChanged: _onChanged,
            onTap: () {
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            },
          ),
        ),
        IconButton(icon: const Icon(Icons.add), onPressed: _increment),
      ],
    );
  }
}
