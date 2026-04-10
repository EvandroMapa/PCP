import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/step/kanban_step_body_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/step/kanban_step_title_widget.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:flutter/material.dart';

class KanbanStepWidget extends StatelessWidget {
  final KanbanUtils utils;
  final StepModel step;
  final List<PedidoModel> pedidos;
  const KanbanStepWidget(this.utils, this.step, this.pedidos, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOut<double>(
      stream: PreferencesService.kanbanColumnWidth.listen,
      builder: (_, width) => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Container(
          width: width,
        decoration: BoxDecoration(
          color: AppColors.neutralLightest.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KanbanStepTitleWidget(utils, step, pedidos),
            Expanded(child: KanbanStepBodyWidget(utils, step, pedidos)),
          ],
        ),
        ),
      ),
    );
  }
}
