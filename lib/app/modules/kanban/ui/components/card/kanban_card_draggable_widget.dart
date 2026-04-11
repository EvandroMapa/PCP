import 'dart:math';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/enums/widget_view_mode.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_mouse_region_widget.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/material.dart';

class KanbanCardDraggableWidget extends StatelessWidget {
  final PedidoModel pedido;
  const KanbanCardDraggableWidget(this.pedido, {super.key});

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<PedidoModel>(
      onDragStarted: () {
        kanbanCtrl.startDrag();
      },
      onDragUpdate: (details) {
        kanbanCtrl.onListenerSrollEnd(context, details.localPosition);
      },
      onDragEnd: (details) {
        kanbanCtrl.utils.cancelTimer();
        kanbanCtrl.endDrag();
      },
      onDragCompleted: () {
        kanbanCtrl.utils.cancelTimer();
        kanbanCtrl.endDrag();
      },
      onDraggableCanceled: (_, __) {
        kanbanCtrl.endDrag();
      },
      delay: const Duration(milliseconds: 180),
      data: pedido,
      childWhenDragging: SizedBox(
        width: PreferencesService.kanbanColumnWidth.value - 10,
        child: Opacity(
          opacity: 0.2,
          child: KanbanCardMouseRegionWidget(pedido),
        ),
      ),
      feedback: _feedbackPedidoWidget(pedido),
      child: KanbanCardMouseRegionWidget(pedido),
    );
  }

  Widget _feedbackPedidoWidget(PedidoModel pedido) {
    return Transform.rotate(
      angle: -pi / 200 * -5,
      child: Opacity(
        opacity: 0.8,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: PreferencesService.kanbanColumnWidth.value - 10,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: KanbanCardMouseRegionWidget(
                pedido,
                viewMode: WidgetViewMode.minified,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
