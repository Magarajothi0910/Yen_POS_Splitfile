import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';

class CustomchargeKeyboardProvider with ChangeNotifier {
  bool isNumeric = ActiveField.isNumeric.value;
  bool isUpperCase = true;
  String? pressedKey;

  // Track active controller using a key (like chargeType)
  String? _activeControllerKey;
  TextEditingController? _activeController;

  // Store all controllers by their keys
  final Map<String, TextEditingController> _controllers = {};

  String? get activeControllerKey => _activeControllerKey;
  TextEditingController? get activeController => _activeController;

  void registerController(String key, TextEditingController controller) {
    _controllers[key] = controller;
  }

  void setActiveController(String key) {
    if (_controllers.containsKey(key)) {
      _activeControllerKey = key;
      _activeController = _controllers[key];
      notifyListeners();
    }
  }

  void clearActiveController() {
    _activeControllerKey = null;
    _activeController = null;
    notifyListeners();
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

class CustomchargeKeyboardWidgetAll2 extends StatelessWidget {
  const CustomchargeKeyboardWidgetAll2({
    super.key,
    required this.controller,
    required this.controllerKey, // Add this parameter
    this.onClose,
  });

  final TextEditingController controller;
  final String controllerKey; // Unique identifier for this controller
  final VoidCallback? onClose;

  void _insert(BuildContext context, String txt) {
    final provider = context.read<CustomchargeKeyboardProvider>();

    // Only insert if this is the active controller
    if (provider.activeControllerKey != controllerKey) {
      // Make this the active controller
      provider.setActiveController(controllerKey);
    }

    final activeCtrl = provider.activeController;
    if (activeCtrl != controller) return; // Not the active controller

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

  void _backspace(BuildContext context) {
    final provider = context.read<CustomchargeKeyboardProvider>();

    // Only backspace if this is the active controller
    if (provider.activeControllerKey != controllerKey) return;

    if (controller.text.isEmpty) return;
    final newText = controller.text.substring(0, controller.text.length - 1);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _handleKey(BuildContext context, String k) {
    final provider = context.read<CustomchargeKeyboardProvider>();

    // Ensure this controller is active
    if (provider.activeControllerKey != controllerKey) {
      provider.setActiveController(controllerKey);
    }

    switch (k) {
      case '⌫':
        _backspace(context);
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
    return Consumer<CustomchargeKeyboardProvider>(
      builder: (context, provider, _) {
        // Check if this keyboard's controller is active
        final isActive = provider.activeControllerKey == controllerKey;

        // Visual feedback for active/inactive keyboard
        return Opacity(
          opacity: isActive ? 1.0 : 0.7,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isActive ? Colors.blue.shade50 : Colors.grey.shade100,
                  isActive ? Colors.blue.shade100 : Colors.grey.shade200,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isActive ? 0.1 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: isActive ? Colors.blue.shade300 : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Header showing which charge this keyboard belongs to
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Adding: $controllerKey',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Keyboard layout
                Expanded(child: _buildKeyboardLayout(context, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyboardLayout(
    BuildContext context,
    CustomchargeKeyboardProvider provider,
  ) {
    final layout = provider.isNumeric ? _numeric : _alpha(provider.isUpperCase);

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
                        Future.delayed(const Duration(milliseconds: 80), () {
                          provider.setPressedKey(null);
                        });
                      },
                      onLongPress: key == '⌫'
                          ? () {
                              if (provider.activeControllerKey ==
                                  controllerKey) {
                                controller.clear();
                              }
                            }
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
    );
  }
}
