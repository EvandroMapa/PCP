import 'package:flutter/material.dart';

class KanbanBackgroundWidget extends StatelessWidget {
  final Widget? child;
  const KanbanBackgroundWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      // Cinza-aço claro: separa as colunas sem o peso do fundo escuro
      decoration: const BoxDecoration(color: Color(0xFFC9D1DB)),
      child: child,
    );
  }
}
