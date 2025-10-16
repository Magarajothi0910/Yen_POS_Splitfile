import 'package:flutter/material.dart';

class DisposableBuilder extends StatelessWidget {
  final VoidCallback onDispose;
  final Widget? child;

  const DisposableBuilder({Key? key, required this.onDispose, this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child ?? SizedBox.shrink();
  }

  @override
  void dispose() {
    onDispose();
    // super.dispose();
  }
}
