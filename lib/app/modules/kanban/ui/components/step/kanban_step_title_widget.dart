import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/sort_step_type.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:flutter/material.dart';

class KanbanStepTitleWidget extends StatelessWidget {
  final KanbanUtils utils;
  final StepModel step;
  final List<PedidoModel> pedidos;
  const KanbanStepTitleWidget(this.utils, this.step, this.pedidos, {super.key});

  @override
  Widget build(BuildContext context) {
    final visiveis =
        pedidos.where((e) => utils.isPedidoVisibleFiltered(e)).toList();
    final double kgsTotal =
        visiveis.map((e) => e.getQtdeTotal()).fold(.0, (a, b) => a + b);

    final corEtapa =
        step.color == Colors.transparent ? AppColors.primaryMain : step.color;
    // Fundo do cabeçalho: um tom suave da cor da etapa sobre o branco,
    // para não se confundir com os cartões brancos
    final fundo = Color.alphaBlend(
        corEtapa.withValues(alpha: 0.12), Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: fundo,
        border: Border(
          top: BorderSide(color: corEtapa, width: 4),
          bottom: BorderSide(color: corEtapa.withValues(alpha: 0.35)),
        ),
      ),
      // Cabeçalho simples (antes era um ExpansionTile sem filhos, que
      // reservava espaço à direita e empurrava o botão de ordenar)
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Column(
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
                    style: AppCss.minimumBold
                        .setSize(13.5)
                        .setColor(AppColors.primaryMain),
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
                  Icon(Icons.lock, color: AppColors.error, size: 14),
                  const W(4),
                ],
                Text(
                  kgsTotal.toKg(),
                  style: AppCss.minimumBold
                      .setSize(15.0)
                      .setWeight(FontWeight.w800) // Mais negrito (negritop)
                      .setColor(AppColors.neutralDark),
                ),
                const W(8),
                // Quantidade de pedidos na coluna (respeita os filtros)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.neutralLightest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    visiveis.length == 1
                        ? '1 pedido'
                        : '${visiveis.length} pedidos',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(AppColors.neutralDark),
                  ),
                ),
                const Spacer(),
                // Ordenar os cartões desta etapa
                PopupMenuButton<SortStepType?>(
                  tooltip: 'Ordenar cartões',
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.under,
                  surfaceTintColor: Colors.white,
                  color: Colors.white,
                  onSelected: (e) => kanbanCtrl.onOrderPedidos(e, pedidos),
                  constraints:
                      const BoxConstraints(minWidth: 230, maxWidth: 260),
                  itemBuilder: (context) {
                    // Grupo (rótulo em maiúsculas, não clicável)
                    PopupMenuItem<SortStepType?> grupo(String texto) =>
                        PopupMenuItem<SortStepType?>(
                          enabled: false,
                          height: 26,
                          child: Text(
                            texto,
                            style: AppCss.minimumBold
                                .setSize(10.5)
                                .setColor(AppColors.neutralMedium)
                                .copyWith(letterSpacing: 0.6),
                          ),
                        );
                    PopupMenuItem<SortStepType?> opcao(
                            SortStepType tipo, IconData icon, String texto) =>
                        PopupMenuItem<SortStepType?>(
                          height: 36,
                          value: tipo,
                          child: Row(
                            children: [
                              Icon(icon,
                                  size: 17, color: AppColors.neutralDark),
                              const W(10),
                              Expanded(
                                child: Text(
                                  texto,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppCss.minimumRegular.setSize(13),
                                ),
                              ),
                            ],
                          ),
                        );
                    return [
                      PopupMenuItem<SortStepType?>(
                        enabled: false,
                        height: 32,
                        child: Text(
                          'Ordenar cartões desta etapa',
                          style: AppCss.minimumBold
                              .setSize(12.5)
                              .setColor(AppColors.black),
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      grupo('DATA DE ENTREGA'),
                      opcao(SortStepType.deliveryAtAsc, Icons.arrow_upward,
                          'Mais cedo primeiro'),
                      opcao(SortStepType.deliveryAtDesc, Icons.arrow_downward,
                          'Mais tarde primeiro'),
                      grupo('DATA DE CRIAÇÃO'),
                      opcao(SortStepType.createdAtDesc, Icons.arrow_downward,
                          'Mais recentes primeiro'),
                      opcao(SortStepType.createdAtAsc, Icons.arrow_upward,
                          'Mais antigos primeiro'),
                      const PopupMenuDivider(height: 1),
                      opcao(SortStepType.localizador, Icons.sort_by_alpha,
                          'Nome do cartão (A a Z)'),
                    ];
                  },
                  // Ícone sem fundo (o "icon:" pegava o quadrado escuro do tema)
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: Icon(Icons.sort,
                        size: 18, color: AppColors.neutralDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
