import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';

/// Enhanced keyboard provider with word suggestions
class KeyboardProvider with ChangeNotifier {
  bool isNumeric = ActiveField.isNumeric.value;
  bool isUpperCase = true;
  bool isSymbolMode = false;
  String? pressedKey;

  int _activeIndex = -1;
  final List<TextEditingController> controllers = [];

  // Word suggestions based on input
  List<String> wordSuggestions = [];
  final Map<String, List<String>> _suggestionDictionary = {
    'th': ['the', 'this', 'that', 'they', 'then'],
    'he': ['hello', 'help', 'here', 'head', 'heart'],
    'yo': ['you', 'your', 'young', 'youth', 'yesterday'],
    'go': ['good', 'go', 'going', 'gold', 'google'],
    'ca': ['can', 'call', 'car', 'cash', 'case'],
    'an': ['and', 'any', 'another', 'answer', 'animal'],
    'in': ['in', 'inside', 'information', 'internet', 'industry'],
    'pr': ['product', 'price', 'print', 'process', 'program'],
    'st': ['start', 'stop', 'store', 'stock', 'status'],
    'se': ['search', 'sell', 'send', 'service', 'set'],
    'cu': ['customer', 'current', 'custom', 'currency', 'cut'],
    'tr': ['transaction', 'transfer', 'track', 'trade', 'try'],
  };

  KeyboardProvider() {
    // Initialize with current value
    isNumeric = ActiveField.isNumeric.value;

    // Listen for changes
    ActiveField.isNumeric.addListener(() {
      isNumeric = ActiveField.isNumeric.value;
      notifyListeners();
    });
  }

  void setIndex(int index) {
    _activeIndex = index;
    _updateSuggestions();
    notifyListeners();
  }

  TextEditingController? get activeController =>
      _activeIndex >= 0 && _activeIndex < controllers.length
      ? controllers[_activeIndex]
      : null;

  void registerController(TextEditingController controller) {
    if (!controllers.contains(controller)) {
      controllers.add(controller);

      // Add listener to controller to update suggestions on text change
      controller.addListener(() {
        _updateSuggestions();
      });

      notifyListeners();
    }
  }

  void toggleCase() {
    isUpperCase = !isUpperCase;
    notifyListeners();
  }

  void toggleSymbolMode() {
    isSymbolMode = !isSymbolMode;
    notifyListeners();
  }

  void setNumeric(bool val) {
    isNumeric = val;
    isSymbolMode = false;
    ActiveField.isNumeric.value = val;
    notifyListeners();
  }

  void setPressedKey(String? key) {
    pressedKey = key;
    notifyListeners();
  }

  void _updateSuggestions() {
    final activeCtrl = activeController;
    if (activeCtrl == null) {
      wordSuggestions = [];
      notifyListeners();
      return;
    }

    final text = activeCtrl.text.toLowerCase();

    // If text is empty or too short, clear suggestions
    if (text.isEmpty || text.length < 2) {
      wordSuggestions = [];
      notifyListeners();
      return;
    }

    // Get the last word being typed
    final lastWord = text.split(' ').last;

    if (lastWord.length >= 2) {
      final prefix = lastWord.substring(0, 2);

      // Filter suggestions that start with the typed prefix
      final possibleMatches = _suggestionDictionary[prefix] ?? [];
      wordSuggestions = possibleMatches
          .where(
            (word) => word.toLowerCase().startsWith(lastWord.toLowerCase()),
          )
          .toList();
    } else {
      wordSuggestions = [];
    }

    // Limit to 5 suggestions
    wordSuggestions = wordSuggestions.take(5).toList();
    notifyListeners();
  }

  void updateSuggestions(String text) {
    if (text.isEmpty || text.length < 2) {
      wordSuggestions = [];
      notifyListeners();
      return;
    }

    final lastWord = text.toLowerCase().split(' ').last;

    if (lastWord.length >= 2) {
      final prefix = lastWord.substring(0, 2);

      // Filter suggestions that start with the typed prefix
      final possibleMatches = _suggestionDictionary[prefix] ?? [];
      wordSuggestions = possibleMatches
          .where(
            (word) => word.toLowerCase().startsWith(lastWord.toLowerCase()),
          )
          .toList();
    } else {
      wordSuggestions = [];
    }

    wordSuggestions = wordSuggestions.take(5).toList();
    notifyListeners();
  }

  // Clear suggestions
  void clearSuggestions() {
    wordSuggestions = [];
    notifyListeners();
  }
}

/// Premium Custom Keyboard Widget
class CustomKeyboardWidgetAll2 extends StatefulWidget {
  const CustomKeyboardWidgetAll2({
    super.key,
    required this.controller,
    this.onClose,
    this.height = 320,
  });

  final TextEditingController controller;
  final VoidCallback? onClose;
  final double height;

  @override
  State<CustomKeyboardWidgetAll2> createState() =>
      _CustomKeyboardWidgetAll2State();
}

class _CustomKeyboardWidgetAll2State extends State<CustomKeyboardWidgetAll2> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<KeyboardProvider>();
      provider.registerController(_controller);

      // Add listener to controller to update suggestions
      _controller.addListener(_onTextChanged);
    });
  }

  void _onTextChanged() {
    final provider = context.read<KeyboardProvider>();
    provider.updateSuggestions(_controller.text);
  }

  @override
  void didUpdateWidget(covariant CustomKeyboardWidgetAll2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // Remove old listener
      _controller.removeListener(_onTextChanged);

      _controller = widget.controller;

      // Add new listener
      _controller.addListener(_onTextChanged);

      final provider = context.read<KeyboardProvider>();
      provider.registerController(_controller);

      // Update suggestions for new controller
      provider.updateSuggestions(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _insert(String txt) {
    final provider = context.read<KeyboardProvider>();
    final text = _controller.text;
    final selection = _controller.selection;

    final int start = selection.start;
    final int end = selection.end;

    if (start < 0 || end < 0) {
      final newText = text + txt;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else {
      final newText = text.replaceRange(start, end, txt);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + txt.length),
      );
    }

    // Suggestions will be updated via the controller listener
  }

  void _backspace() {
    final provider = context.read<KeyboardProvider>();
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.start <= 0 && selection.end <= 0) return;

    if (selection.start != selection.end) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else {
      final newStart = selection.start - 1;
      final newText = text.replaceRange(newStart, selection.start, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newStart),
      );
    }

    // If text is now empty, clear suggestions
    if (_controller.text.isEmpty) {
      provider.clearSuggestions();
    }
  }

  void _handleKey(String k) {
    final provider = context.read<KeyboardProvider>();

    switch (k) {
      case '⌫':
        _backspace();
        break;
      case '✖':
        widget.onClose?.call();
        break;
      case 'SPACE':
        _insert(' ');
        provider.clearSuggestions(); // Clear suggestions after space
        break;
      case '123':
        provider.setNumeric(true);
        break;
      case 'ABC':
        provider.setNumeric(false);
        break;
      case '#+=':
        provider.toggleSymbolMode();
        break;
      case '⇧':
        provider.toggleCase();
        break;
      case '↵':
        // Enter key - you can handle this as needed
        widget.onClose?.call();
        break;
      default:
        _insert(k);
    }
  }

  /// Layout definitions
  List<List<String>> get _numericLayout => [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '/', ':', ';', '(', ')', '\$', '&', '@', '"'],
    ['#+=', '.', ',', '?', '!', "'", '⌫'],
    ['ABC', 'SPACE', '.', '↵'],
  ];

  List<List<String>> get _symbolLayout => [
    ['[', ']', '{', '}', '#', '%', '^', '*', '+', '='],
    ['_', '\\', '|', '~', '<', '>', '€', '£', '¥', '•'],
    ['123', '.', ',', '?', '!', "'", '⌫'],
    ['ABC', 'SPACE', '.', '↵'],
  ];

  List<List<String>> _alphaLayout(bool upper) {
    const base = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
      ['123', 'SPACE', '.', '↵'],
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

  Widget _buildKeyContainer(String keyLabel, bool isPressed, bool isSpecial) {
    final bool isActionKey = [
      '⌫',
      '⇧',
      '↵',
      '✖',
      'SPACE',
      '123',
      'ABC',
      '#+=',
    ].contains(keyLabel);
    final bool isLetter = RegExp(r'^[a-zA-Z]$').hasMatch(keyLabel);

    Color backgroundColor;
    Color textColor;

    if (isPressed) {
      backgroundColor = Colors.blueAccent;
      textColor = Colors.white;
    } else if (isActionKey) {
      backgroundColor = Colors.grey.shade300.withOpacity(0.7);
      textColor = Colors.blueGrey.shade800;
    } else if (isLetter) {
      backgroundColor = Colors.white;
      textColor = Colors.black87;
    } else {
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.black87;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
      ),
      child: Center(child: _buildLabel(keyLabel, textColor)),
    );
  }

  Widget _buildLabel(String k, Color color) {
    final iconSize = 22.0;

    switch (k) {
      case '⌫':
        return Icon(Icons.backspace_outlined, color: color, size: iconSize);
      case '✖':
        return Icon(Icons.close, color: color, size: iconSize);
      case 'SPACE':
        return Icon(Icons.space_bar, color: color, size: iconSize);
      case '⇧':
        return Icon(Icons.keyboard_arrow_up, color: color, size: iconSize);
      case '↵':
        return Icon(Icons.keyboard_return, color: color, size: iconSize);
      case '123':
      case 'ABC':
      case '#+=':
        return Text(
          k,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
      default:
        return Text(
          k,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        );
    }
  }

  Widget _buildSuggestionChip(String word) {
    return GestureDetector(
      onTap: () {
        final provider = context.read<KeyboardProvider>();
        final text = _controller.text;
        final words = text.split(' ');

        if (words.isNotEmpty) {
          // Get the current word being typed
          final currentWord = words.last;

          // Replace current word with selected suggestion
          final newText =
              text.substring(0, text.length - currentWord.length) + word + ' ';

          _controller.text = newText;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );

          // Clear suggestions after selection
          provider.clearSuggestions();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KeyboardProvider>(
      builder: (context, provider, _) {
        final layout = provider.isNumeric
            ? (provider.isSymbolMode ? _symbolLayout : _numericLayout)
            : _alphaLayout(provider.isUpperCase);

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade100, Colors.grey.shade200],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Suggestions Bar - More visible now
              if (provider.wordSuggestions.isNotEmpty)
                Container(
                  height: 60, // Increased height for better visibility
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: provider.wordSuggestions
                              .map((word) => _buildSuggestionChip(word))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Keyboard Layout
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      for (
                        int rowIndex = 0;
                        rowIndex < layout.length;
                        rowIndex++
                      )
                        Expanded(
                          child: Row(
                            children: [
                              // Add spacer for second and third rows in alpha layout
                              if (!provider.isNumeric && rowIndex == 1)
                                const SizedBox(width: 15),
                              if (!provider.isNumeric && rowIndex == 2)
                                const SizedBox(width: 15),

                              for (final key in layout[rowIndex])
                                Expanded(
                                  flex: key == 'SPACE' ? 4 : 1,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) {
                                      provider.setPressedKey(key);
                                    },
                                    onTapUp: (_) {
                                      _handleKey(key);
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          provider.setPressedKey(null);
                                        },
                                      );
                                    },
                                    onTapCancel: () {
                                      provider.setPressedKey(null);
                                    },
                                    onLongPress: key == '⌫'
                                        ? () {
                                            _controller.clear();
                                            provider.clearSuggestions();
                                          }
                                        : null,
                                    child: _buildKeyContainer(
                                      key,
                                      provider.pressedKey == key,
                                      false,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Usage example:
/* 
// In your main.dart or where you set up providers:
ChangeNotifierProvider(
  create: (_) => KeyboardProvider(),
  child: YourApp(),
),

// In your screen:
Consumer<KeyboardProvider>(
  builder: (context, provider, child) {
    return Column(
      children: [
        // Your text fields
        TextField(
          controller: myController,
          onTap: () {
            // Set this controller as active
            provider.setIndex(0); // Use appropriate index
          },
        ),
        
        // Keyboard at the bottom
        Expanded(child: SizedBox()),
        CustomKeyboardWidgetAll2(
          controller: myController,
        ),
      ],
    );
  },
)
*/
