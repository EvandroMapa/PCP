import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/sort_step_type.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_import_pdf_dialog.dart';
import 'package:flutter/material.dart';

class KanbanStepTitleWidget extends StatelessWidget {
  final KanbanUtils utils;
  final StepModel step;
  final List<PedidoModel> pedidos;
  const KanbanStepTitleWidget(this.utils, this.step, this.pedidos, {super.key});

  @override
  Widget build(BuildContext context) {
    final double kgsTotal = pedidos
        .where((e) => utils.isPedidoVisibleFiltered(e))
        .map((e) => e.getQtdeTotal())
        .fold(.0, (a, b) => a + b);

    return ExpansionTile(
      dense: false,
      minTileHeight: 46,
      tilePadding: const EdgeInsets.only(left: 8, right: 4),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
      trailing: const SizedBox.shrink(),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Nome da etapa
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  step.name,
                  style: AppCss.minimumBold,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const H(4),
          // Linha 2: lock + kgs + botões
          Row(
            children: [
              if (!step.isEnable) ...[
                const Icon(Icons.lock, color: Colors.red, size: 12),
                const W(4),
              ],
              Text(
                kgsTotal.toKg(),
                style: AppCss.minimumBold.setSize(11).setColor(AppColors.neutralDark),
              ),
              const Spacer(),
              // Botão adicionar
              PopupMenuButton<int>(
                tooltip: 'Criar Cartão',
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  fixedSize: WidgetStateProperty.all(const Size(22, 22)),
                  minimumSize: WidgetStateProperty.all(const Size(22, 22)),
                ),
                icon: const Icon(Icons.add, color: Colors.blue, size: 18),
                padding: EdgeInsets.zero,
                offset: const Offset(0, 36),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 1,
                    height: 32,
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 16, color: Colors.blue),
                        const W(8),
                        Text(
                          'Criar cartão baseado em pedido',
                          style: AppCss.minimumRegular.setSize(12),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 1) {
                    await showPedidoImportPdfDialog(initialStep: step);
                  }
                },
              ),
              // Botão ordenação
              PopupMenuButton<SortStepType?>(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  fixedSize: WidgetStateProperty.all(const Size(22, 22)),
                  minimumSize: WidgetStateProperty.all(const Size(22, 22)),
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 16),
                surfaceTintColor: Colors.white,
                color: Colors.white,
                onSelected: (e) => kanbanCtrl.onOrderPedidos(e, pedidos),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ordenação',
                            style: AppCss.minimumBold.setSize(14),
                          ),
                        ),
                        const Icon(Icons.close, color: Colors.black, size: 14),
                      ],
                    ),
                  ),
                  ...SortStepType.values.map(
                    (e) => PopupMenuItem(
                      height: 32,
                      value: e,
                      child: Text(
                        e.label,
                        style: AppCss.minimumRegular.setSize(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      onExpansionChanged: (e) {},
      children: const <Widget>[],
    );
  }
}
