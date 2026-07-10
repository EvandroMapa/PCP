import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class KanbanPedidoSelectedWidget extends StatelessWidget {
  final KanbanUtils utils;
  const KanbanPedidoSelectedWidget(this.utils, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: utils.isPedidoSelected ? 1 : 0,
      child: !utils.isPedidoSelected
          ? const SizedBox()
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Container(
                  padding: EdgeInsets.all(isMobile ? 0 : 16),
                  constraints:
                      isMobile ? null : const BoxConstraints(maxWidth: 800),
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(isMobile ? 0 : 8),
                    child: PedidoPage(
                      pedido: utils.pedido!,
                      reason: PedidoInitReason.kanban,
                      onDelete: () => kanbanCtrl.setPedido(null),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
