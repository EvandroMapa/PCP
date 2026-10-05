import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/widget_view_mode.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_comments_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_details_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_notificao_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_products_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_tags_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_users_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_cd_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_elementos_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_vinculados_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_patio_widget.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class KanbanCardPedidoWidget extends StatelessWidget {
  final PedidoModel pedido;
  final WidgetViewMode viewMode;
  const KanbanCardPedidoWidget(
    this.pedido, {
    this.viewMode = WidgetViewMode.normal,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final notificacoes = notificacaoCtrl.getNotificaoByUsuarioPedido(
      FirestoreClient.notificacoes.data,
      usuarioCtrl.usuario!,
      pedido,
    );
    final stripeColor = _getStripeColor(pedido);
    return InkWell(
      onTap: () => kanbanCtrl.setPedido(pedido),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getColor(pedido),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: stripeColor != null
              ? Border(
                  left: BorderSide(color: stripeColor, width: 4),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.12),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comentário fixado: faixa âmbar no topo (antes pintava o cartão)
            if (pedido.comments.any((e) => e.isFixed)) ...[
              Container(
                width: double.maxFinite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin,
                        size: 13, color: Color(0xFFB45309)),
                    const W(4),
                    Text(
                      'Comentário fixado',
                      style: AppCss.minimumBold
                          .setSize(10.5)
                          .setColor(const Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
              const H(6),
            ],
            Row(
              children: [
                if (pedido.tags.isNotEmpty) ...[
                  Expanded(
                    child: KanbanCardTagsWidget(
                      pedido: pedido,
                      viewMode: viewMode,
                    ),
                  ),
                ] else
                  const Spacer(),
                const W(8),
                if (pedido.pedidosVinculados.isNotEmpty) ...[
                  Icon(Icons.link, color: Colors.grey[700], size: 16),
                  const W(8),
                ],
                Text(
                  pedido.getQtdeTotal().toKg(),
                  style: AppCss.minimumBold.setSize(14),
                ),
                if (notificacoes.isNotEmpty) ...[
                  const W(8),
                  KanbanCardNotificacaoWidget(),
                ],
              ],
            ),
            const H(8),
            // ── Localizador + badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    pedido.localizador,
                    style: AppCss.mediumBold.setSize(13.5),
                  ),
                ),
                if (pedido.isMestre) ...[
                  const W(6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'MESTRE',
                      style: AppCss.minimumBold.copyWith(
                          fontSize: 10, color: const Color(0xFFB45309)),
                    ),
                  ),
                  if (pedido.todosFilhosArquivados) ...[
                    const W(4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F5EC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.archive_outlined,
                              size: 11, color: AppColors.statusPronto),
                          const W(2),
                          Text(
                            'ARQUIVADOS',
                            style: AppCss.minimumBold.copyWith(
                                fontSize: 10, color: AppColors.statusPronto),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (pedido.isParcial) ...[
                  const W(6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFFE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PARCIAL',
                      style: AppCss.minimumBold.copyWith(
                          fontSize: 10, color: const Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ],
            ),
            const H(8),
            Row(
              children: [
                Expanded(child: KanbanCardDetailsWidget(pedido)),
                KanbanCardUsersWidget(pedido, viewMode: viewMode),
              ],
            ),
            // ── Barra de Produção CD ──
            KanbanCardCDWidget(pedido: pedido),
            // ── Barra de Armação CDA ──
            KanbanCardElementosWidget(pedido: pedido),
            if (viewMode == WidgetViewMode.expanded) ...[
              KanbanCardProductsWidget(pedido: pedido),
              Builder(
                builder: (context) {
                  final comments =
                      pedido.comments.where((e) => e.isFixed).toList();
                  if (comments.isEmpty) return const SizedBox();
                  return KanbanCardCommentsWidget(comments: comments);
                },
              ),
              KanbanCardVinculadosWidget(pedido: pedido),
              KanbanCardPatioWidget(pedido: pedido),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColor(PedidoModel pedido) {
    if (pedido.todosFilhosArquivados) return const Color(0xFFF3FAF5);
    return const Color(0xFFFFFFFF);
  }

  /// Cor da borda lateral (stripe): verde p/ todos arquivados, âmbar p/ mestre, azul p/ parcial
  Color? _getStripeColor(PedidoModel pedido) {
    if (pedido.todosFilhosArquivados) return AppColors.statusPronto;
    if (pedido.isMestre) return AppColors.statusAtencao;
    if (pedido.isParcial) return AppColors.statusProduzindo;
    if (_isAtrasado(pedido)) return AppColors.statusCritico;
    return null;
  }

  bool _isAtrasado(PedidoModel pedido) {
    final entrega = pedido.deliveryAt;
    if (entrega == null || pedido.isEntregue) return false;
    final hoje = DateTime.now();
    return DateTime(entrega.year, entrega.month, entrega.day)
        .isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }
}
