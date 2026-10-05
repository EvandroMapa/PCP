import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';

class KanbanBackgroundWidget extends StatelessWidget {
  final Widget? child;
  const KanbanBackgroundWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      decoration: BoxDecoration(color: AppColors.primaryDark),
      child: child,
    );
  }
}
