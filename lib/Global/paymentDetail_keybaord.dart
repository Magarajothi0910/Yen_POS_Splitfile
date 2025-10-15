import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/sales_order/globals.dart';

class PaymentDetailKeyboardProvider with ChangeNotifier {
  bool isNumeric = ActiveField.isNumeric.value;
  bool isUpperCase = true;
  String? pressedKey;

  int _activeIndex = -1; // currently focused index
  final List<TextEditingController> controllers = [];
  final List<String> inputTypes = []; // e.g., 'numeric', 'text', 'alphanumeric'

  int get activeIndex => _activeIndex;

  void registerController(TextEditingController controller,
      {String inputType = 'text'}) {
    if (!controllers.contains(controller)) {
      controllers.add(controller);
      inputTypes.add(inputType);
    }
  }

  void focusController(TextEditingController controller) {
    final index = controllers.indexOf(controller);
    if (index != -1) {
      _activeIndex = index;
      notifyListeners();
    }
  }

  void setIndex(int index) {
    if (index < 0 || index >= controllers.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  TextEditingController? get activeController {
    if (_activeIndex == -1) return null;
    return controllers[_activeIndex];
  }

  String get activeInputType {
    if (_activeIndex == -1) return 'text';
    return inputTypes[_activeIndex];
  }

  void toggleCase() {
    isUpperCase = !isUpperCase;
    notifyListeners();
  }

  void setNumeric(bool val) {
    isNumeric = val;
    ActiveField.isNumeric.value = val;
    notifyListeners();
  }

  void setPressedKey(String? key) {
    pressedKey = key;
    notifyListeners();
  }
}

class PaymentDetailCustomKeyboardWidgetAll2 extends StatelessWidget {
  const PaymentDetailCustomKeyboardWidgetAll2({
    super.key,
    required this.controller,
    this.onClose,
    this.onChanged,
    this.isDiscount = false,
  });

  final TextEditingController controller;
  final VoidCallback? onClose;
  final bool isDiscount;
  final VoidCallback? onChanged;

  void _insert(BuildContext context, String txt) {
    final newText = controller.text + txt;

    if (ActiveField.isDiscount.value) {
      final value = double.tryParse(newText);
      if (value != null && (value > 100 || value <= 0)) {
        controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Discount must be between 1 and 100"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (ActiveField.isCustomCharge.value) {
      if (newText.length > 5) return;
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _backspace() {
    if (controller.text.isEmpty) return;
    final newText = controller.text.substring(0, controller.text.length - 1);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _handleKey(BuildContext context, String k) {
    final provider = context.read<PaymentDetailKeyboardProvider>();
    if (ActiveField.isNumeric.value && (k == 'ABC' || k == '⇧')) return;

    switch (k) {
      case '⌫':
        _backspace();
        break;
      case '✖':
        onClose?.call();
        break;
      case 'SPACE':
        _insert(context, ' ');
        break;
      case '123':
        provider.setNumeric(true);
        break;
      case 'ABC':
        provider.setNumeric(false);
        break;
      case '⇧':
        provider.toggleCase();
        break;
      default:
        _insert(context, k);
    }
  }

  List<List<String>> get _numeric => [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['.', '0', '⌫'],
      ];

  List<List<String>> get _numericLocked => [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['0', '⌫'],
      ];

  List<List<String>> _alpha(bool upper) {
    const base = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
      ['123', 'SPACE'],
    ];
    return base
        .map((row) => row
            .map((k) => RegExp(r'^[a-zA-Z]$').hasMatch(k) && upper
                ? k.toUpperCase()
                : k)
            .toList())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentDetailKeyboardProvider>(
      builder: (context, provider, _) {
        final layout = ActiveField.isNumeric.value
            ? _numericLocked
            : _alpha(provider.isUpperCase);

        return Column(
          children: [
            for (final row in layout)
              Expanded(
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            provider.setPressedKey(key);
                            _handleKey(context, key);
                            Future.delayed(
                              const Duration(milliseconds: 80),
                              () => provider.setPressedKey(null),
                            );
                          },
                          onLongPress:
                              key == '⌫' ? () => controller.clear() : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.all(6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: provider.pressedKey == key
                                  ? LinearGradient(
                                      colors: [
                                        Colors.blue.shade200,
                                        Colors.blue.shade400,
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.grey.shade300,
                                        Colors.grey.shade100,
                                      ],
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildLabel(key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(String k) {
    switch (k) {
      case '⌫':
        return const Icon(Icons.backspace, color: Colors.black87, size: 22);
      case '✖':
        return const Icon(Icons.close, color: Colors.redAccent, size: 22);
      case 'SPACE':
        return const Icon(Icons.space_bar, color: Colors.black54, size: 22);
      case '⇧':
        return const Icon(Icons.arrow_upward, color: Colors.black87, size: 22);
      default:
        return Text(
          k,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        );
    }
  }
}
