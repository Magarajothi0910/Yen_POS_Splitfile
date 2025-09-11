// import 'package:flutter/material.dart';
// import '../../../../Global/custom_colors.dart';

// class CustomKeyboard extends StatefulWidget {
//   final Function(String) onTextInput;
//   final Function onBackspace;
//   final Function onClose;

//   const CustomKeyboard({
//     required this.onTextInput,
//     required this.onBackspace,
//     required this.onClose,
//     super.key,
//   });

//   @override
//   _CustomKeyboardState createState() => _CustomKeyboardState();
// }

// class _CustomKeyboardState extends State<CustomKeyboard> {
//   bool _isUppercase = true;

//   void _toggleCase() {
//     setState(() {
//       _isUppercase = !_isUppercase;
//     });
//   }

//   void _textInputHandler(String text) => widget.onTextInput.call(text);

//   void _backspaceHandler() => widget.onBackspace.call();

//   void _closeHandler() => widget.onClose.call();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 520,
//       height: 220,
//       color: CustomColors.whiteColor,
//       padding: const EdgeInsets.symmetric(vertical: 20),
//       child: Column(
//         children: [
//           Expanded(
//             child: _buildRow('1234567890'),
//           ),
//           Expanded(
//             child: _buildRow('QWERTYUIOP'),
//           ),
//           Expanded(
//             child: _buildRow('ASDFGHJKL'),
//           ),
//           Expanded(
//             child: _buildRow('ZXCVBNM'),
//           ),
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _buildKey(
//                     _isUppercase
//                         ? 'Caps'
//                         : 'caps', // Toggle between Caps and caps
//                     _toggleCase,
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: _buildKey(
//                     'Space',
//                     () => _textInputHandler(' '),
//                   ),
//                 ),
//                 Expanded(
//                   child: _buildKey(
//                     '.',
//                     () => _textInputHandler('.'),
//                   ),
//                 ),
//                 Expanded(
//                   child: _buildKey(
//                     '<-',
//                     _backspaceHandler,
//                   ),
//                 ),
//                 Expanded(
//                   child: _buildKey(
//                     'close',
//                     _closeHandler,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRow(String letters) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: letters.split('').map((letter) {
//         return Expanded(
//           child: _buildKey(
//             _isUppercase ? letter : letter.toLowerCase(),
//             () =>
//                 _textInputHandler(_isUppercase ? letter : letter.toLowerCase()),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildKey(String label, VoidCallback onPressed) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         margin: const EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: CustomColors.whiteColor,
//           border: Border.all(color: CustomColors.grey),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Center(
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

class CustomKeyboard extends StatefulWidget {
  final Function(String) onTextInput;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final VoidCallback onClose;

  const CustomKeyboard({
    required this.onTextInput,
    required this.onBackspace,
    required this.onEnter,
    required this.onClose,
    super.key,
  });

  @override
  _CustomKeyboardState createState() => _CustomKeyboardState();
}

class _CustomKeyboardState extends State<CustomKeyboard> {
  bool _isShiftEnabled = false;
  bool _isNumberMode = false;
  Offset position = Offset(20, 400); // Initial position on screen

  // Superscript numbers for top-left of letters
  static const Map<String, String> superscriptNumbers = {
    'q': '1',
    'w': '2',
    'e': '3',
    'r': '4',
    't': '5',
    'y': '6',
    'u': '7',
    'i': '8',
    'o': '9',
    'p': '0',
  };

  void _toggleShift() {
    setState(() {
      _isShiftEnabled = !_isShiftEnabled;
    });
  }

  void _toggleNumberMode() {
    setState(() {
      _isNumberMode = !_isNumberMode;
      _isShiftEnabled = false; // reset shift when toggling mode
    });
  }

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
    double widthFactor = 1,
    bool isBlue = false,
  }) {
    return Expanded(
      flex: (widthFactor * 10).toInt(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          splashColor: Colors.blue.withOpacity(0.3),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isBlue ? Colors.blue.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  offset: const Offset(0, 1),
                  blurRadius: 1.5,
                ),
                BoxShadow(
                  color: Colors.grey.shade100,
                  offset: const Offset(0, -1),
                  blurRadius: 1,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildLetterKey(String letter) {
    final displayLetter =
        _isShiftEnabled ? letter.toUpperCase() : letter.toLowerCase();
    final superscript = superscriptNumbers[letter.toLowerCase()];

    return _buildKey(
      onTap: () => widget.onTextInput(displayLetter),
      child: Stack(
        children: [
          Center(
            child: Text(
              displayLetter,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          if (superscript != null)
            Positioned(
              top: 6,
              left: 6,
              child: Text(
                superscript,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberKey(String number) {
    return _buildKey(
      onTap: () => widget.onTextInput(number),
      child: Text(
        number,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        _buildKey(
          widthFactor: 1.5,
          onTap: _toggleNumberMode,
          child: Text(
            _isNumberMode ? 'ABC' : '?123',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800),
          ),
        ),
        _buildKey(
          onTap: () => widget.onTextInput(','),
          child: const Text(
            ',',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        // You can add emoji key here if needed
        // _buildKey(
        //   onTap: () {},
        //   child: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
        // ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => widget.onTextInput(' '),
              splashColor: Colors.blue.withOpacity(0.3),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      offset: const Offset(0, 1),
                      blurRadius: 1.5,
                    ),
                    BoxShadow(
                      color: Colors.grey.shade100,
                      offset: const Offset(0, -1),
                      blurRadius: 1,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    'space',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildKey(
          onTap: () => widget.onTextInput('.'),
          child: const Text(
            '.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        _buildKey(
          onTap: widget.onEnter,
          child: const Icon(
            Icons.keyboard_return,
            size: 24,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLetterKeyboard() {
    final row1 = 'qwertyuiop';
    final row2 = 'asdfghjkl';
    final row3 = 'zxcvbnm';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: row1.split('').map(_buildLetterKey).toList(),
        ),
        Row(
          children: [
            const Spacer(flex: 1),
            ...row2.split('').map(_buildLetterKey).toList(),
            const Spacer(flex: 1),
          ],
        ),
        Row(
          children: [
            _buildKey(
              onTap: _toggleShift,
              isBlue: _isShiftEnabled,
              child: Icon(
                Icons.arrow_upward,
                color: _isShiftEnabled ? Colors.white : Colors.grey.shade800,
              ),
            ),
            ...row3.split('').map(_buildLetterKey).toList(),
            _buildKey(
              onTap: widget.onBackspace,
              isBlue: true,
              child: const Icon(Icons.backspace_outlined, color: Colors.white),
            ),
          ],
        ),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildNumberKeyboard() {
    final row1 = '1234567890';
    final row2 = '-/:;()&@"\$';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: row1
              .split('')
              .map((n) => _buildNumberKey(n))
              .toList(growable: false),
        ),
        Row(
          children: row2
              .split('')
              .map((n) => _buildNumberKey(n))
              .toList(growable: false),
        ),
        Row(
          children: [
            _buildKey(
              widthFactor: 2,
              onTap: _toggleNumberMode,
              child: const Text(
                'ABC',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildKey(
              widthFactor: 2,
              onTap: widget.onBackspace,
              isBlue: true,
              child: const Icon(Icons.backspace_outlined, color: Colors.white),
            ),
            _buildKey(
              widthFactor: 3,
              onTap: () => widget.onTextInput(' '),
              child: const Text('space'),
            ),
            _buildKey(
              widthFactor: 1.5,
              onTap: widget.onEnter,
              child: const Icon(Icons.keyboard_return),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        height: 280,
        child: _isNumberMode ? _buildNumberKeyboard() : _buildLetterKeyboard(),
      ),
    );
  }
}
