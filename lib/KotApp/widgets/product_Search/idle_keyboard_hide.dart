import 'dart:async';
import 'package:flutter/material.dart';

class IdleKeyboardHide extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final Duration idleDuration;

  const IdleKeyboardHide({
    Key? key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.idleDuration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  _IdleKeyboardHideState createState() => _IdleKeyboardHideState();
}

class _IdleKeyboardHideState extends State<IdleKeyboardHide> {
  late FocusNode _focusNode;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Listen to focus changes
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _startIdleTimer();
      } else {
        _cancelIdleTimer();
      }
    });

    // Listen to user typing to reset the timer
    widget.controller.addListener(() {
      _startIdleTimer();
    });
  }

  void _startIdleTimer() {
    _cancelIdleTimer(); // Reset the timer
    _idleTimer = Timer(widget.idleDuration, () {
      if (mounted && _focusNode.hasFocus) {
        FocusScope.of(context).unfocus(); // Hide the keyboard
      
      }
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
    );
  }
}
