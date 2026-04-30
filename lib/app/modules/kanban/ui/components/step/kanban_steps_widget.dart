import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/step/kanban_step_widget.dart';
import 'package:flutter/material.dart';

class KanbanStepsWidget extends StatelessWidget {
  final KanbanUtils utils;
  const KanbanStepsWidget(this.utils, {super.key});

  @override
  Widget build(BuildContext context) {
    final steps = utils.kanban.keys.toList();
    return RawScrollbar(
      trackColor: Colors.grey[400],
      trackRadius: const Radius.circular(8),
      thumbColor: Colors.grey[700],
      interactive: true,
      radius: const Radius.circular(4),
      thickness: 8,
      controller: utils.scroll,
      trackVisibility: true,
      thumbVisibility: true,
      child: ListView.separated(
        controller: utils.scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: steps.length,
        scrollDirection: Axis.horizontal,
        cacheExtent: 500,
        separatorBuilder: (_, i) => const W(16),
        itemBuilder: (_, i) => KanbanStepWidget(
          utils,
          steps[i],
          utils.kanban[steps[i]]!,
        ),
      ),
    );
  }
}
