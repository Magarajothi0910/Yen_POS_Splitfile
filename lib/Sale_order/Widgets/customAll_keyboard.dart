import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';

/// PROVIDER: Handles active keyboard state
/// PROVIDER: Handles active keyboard state & controller mapping
class KeyboardProvider with ChangeNotifier {
  bool isNumeric = ActiveField.isNumeric.value;
  bool isUpperCase = true;
  String? pressedKey;

  int _activeIndex = -1;
  final List<TextEditingController> controllers = [];

  KeyboardProvider() {
    // 👇 Sync whenever ActiveField changes
    ActiveField.isNumeric.addListener(() {
      isNumeric = ActiveField.isNumeric.value;
      notifyListeners();
    });
  }

  void setIndex(int index) {
    _activeIndex = index;
    notifyListeners();
  }

  TextEditingController? get activeController =>
      _activeIndex >= 0 && _activeIndex < controllers.length
      ? controllers[_activeIndex]
      : null;

  void registerController(TextEditingController controller) {
    if (!controllers.contains(controller)) {
      controllers.add(controller);
    }
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

/// MAIN CUSTOM KEYBOARD WIDGET
class CustomKeyboardWidgetAll2 extends StatelessWidget {
  const CustomKeyboardWidgetAll2({
    super.key,
    required this.controller,
    this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback? onClose;

  /// Insert text into the controller
  void _insert(BuildContext context, String txt) {
    final newText = controller.text + txt;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  /// Remove last character
  void _backspace() {
    if (controller.text.isEmpty) return;
    final newText = controller.text.substring(0, controller.text.length - 1);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  /// Handle key tap logic
  void _handleKey(BuildContext context, String k) {
    final provider = context.read<KeyboardProvider>();

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

  /// Numeric / Special Keyboard Layout
  List<List<String>> get _numericLayout => [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['@', '#', '\$', '%', '&', '*', '-', '+', '(', ')'],
    ['ABC', '.', ',', '?', '!', '⌫'],
  ];

  /// Alphabetic Keyboard Layout
  List<List<String>> _alphaLayout(bool upper) {
    const base = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
      ['123', 'SPACE', '.', ','],
    ];

    return base
        .map(
          (row) => row
              .map(
                (k) => RegExp(r'^[a-zA-Z]$').hasMatch(k) && upper
                    ? k.toUpperCase()
                    : k,
              )
              .toList(),
        )
        .toList();
  }

  /// UI: Build single key
  Widget _buildKeyContainer(
    BuildContext context,
    String keyLabel,
    bool isPressed,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isPressed
            ? LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey.shade200, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(2, 2),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-2, -2),
            blurRadius: 3,
          ),
        ],
      ),
      child: _buildLabel(keyLabel, isPressed),
    );
  }

  /// UI: Label or icon for key
  Widget _buildLabel(String k, bool isPressed) {
    final color = isPressed ? Colors.white : Colors.black87;

    switch (k) {
      case '⌫':
        return Icon(Icons.backspace, color: color, size: 24);
      case '✖':
        return Icon(Icons.close, color: color, size: 24);
      case 'SPACE':
        return Icon(Icons.space_bar, color: color, size: 24);
      case '⇧':
        return Icon(Icons.arrow_upward, color: color, size: 24);
      default:
        return Text(
          k,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KeyboardProvider>(
      builder: (context, provider, _) {
        final layout = provider.isNumeric
            ? _numericLayout
            : _alphaLayout(provider.isUpperCase);

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade100, Colors.grey.shade200],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
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
                                () {
                                  provider.setPressedKey(null);
                                },
                              );
                            },
                            onLongPress: key == '⌫'
                                ? () => controller.clear()
                                : null,
                            child: _buildKeyContainer(
                              context,
                              key,
                              provider.pressedKey == key,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
