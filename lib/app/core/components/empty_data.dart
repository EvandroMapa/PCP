import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

class EmptyData extends StatelessWidget {
  final String? message;
  const EmptyData({this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.drafts, color: Colors.black, size: 48),
        const H(16),
        Text(message ?? 'Nenhum dado encontrado', style: AppCss.mediumRegular),
      ],
    );
  }
}
