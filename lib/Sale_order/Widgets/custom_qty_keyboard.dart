import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';

class QtyKeyboardProvider with ChangeNotifier {
  bool isNumeric = ActiveField.isNumeric.value;
  bool isUpperCase = true;
  String? pressedKey;

  int _activeIndex = -1;
  final List<TextEditingController> controllers = [];
  final List<String> inputTypes = [];

  int get activeIndex => _activeIndex;

  void registerController(
    TextEditingController controller, {
    String inputType = 'text',
  }) {
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

class QtyCustomKeyboardWidgetAll2 extends StatelessWidget {
  const QtyCustomKeyboardWidgetAll2({
    super.key,
    required this.controller,
    this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback? onClose;

  void _insert(BuildContext context, String txt) {
    final provider = context.read<QtyKeyboardProvider>();
    if (provider.isNumeric) {
      // Remove non-digit characters for counting
      final digitsOnly = (controller.text + txt).replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      // ✅ Max 5 digits
      if (digitsOnly.length > 5) return;

      // ✅ Prevent starting with 0
      if (controller.text.isEmpty && txt == '0') return;
    }

    final newText = controller.text + txt;
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
    final provider = context.read<QtyKeyboardProvider>();
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
    ['0', '⌫'], // added ABC toggle
  ];

  List<List<String>> _alpha(bool upper) {
    const base = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
      ['123', 'SPACE'], // numeric toggle
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

  Widget _buildKeyContainer(
    BuildContext context,
    String keyLabel,
    bool isPressed,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isPressed
            ? LinearGradient(
                colors: [Colors.blue.shade300, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isPressed ? 0.2 : 0.1),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: _buildLabelPremium(keyLabel),
    );
  }

  Widget _buildLabelPremium(String k) {
    switch (k) {
      case '⌫':
        return const Icon(Icons.backspace, color: Colors.black87, size: 24);
      case '✖':
        return const Icon(Icons.close, color: Colors.black87, size: 24);
      case 'SPACE':
        return const Icon(Icons.space_bar, color: Colors.black87, size: 24);
      case '⇧':
        return const Icon(Icons.arrow_upward, color: Colors.black87, size: 24);
      default:
        return Text(
          k,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: 0.8,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QtyKeyboardProvider>(
      builder: (context, provider, _) {
        final layout = provider.isNumeric
            ? _numeric
            : _alpha(provider.isUpperCase);
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
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
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
