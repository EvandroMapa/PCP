import 'package:flutter/material.dart';

class Separator extends StatelessWidget {
  final bool isLast;
  final Widget child;

  const Separator(this.isLast, {required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: child,
    );
  }
}
