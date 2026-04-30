import 'package:flutter/material.dart';

class KanbanBackgroundWidget extends StatelessWidget {
  final Widget? child;
  const KanbanBackgroundWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A5568),
            Color(0xFF3D4A5C),
            Color(0xFF354152),
          ],
        ),
      ),
      child: child,
    );
  }
}
