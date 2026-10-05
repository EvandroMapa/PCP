import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_notificao_widget.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

enum PedidoItemInfo { normal, minified, page }

class PedidoItemWidget extends StatelessWidget {
  final PedidoModel pedido;
  final Function(PedidoModel) onTap;
  final PedidoItemInfo info;

  /// true na Lista de pedidos: item em cartão branco com cantos arredondados.
  /// false (padrão) nos demais usos: linha com divisória inferior.
  final bool asCard;

  const PedidoItemWidget({
    super.key,
    required this.pedido,
    required this.onTap,
    this.info = PedidoItemInfo.normal,
    this.asCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final notificacoes = notificacaoCtrl.getNotificaoByUsuarioPedido(
      FirestoreClient.notificacoes.data,
      usuarioCtrl.usuario!,
      pedido,
    );
    final destaque = _corDestaque(pedido, notificacoes);
    final radius = asCard ? BorderRadius.circular(10) : null;

    final conteudo = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largo = constraints.maxWidth >= 720;
          final mostrarProducao = info != PedidoItemInfo.minified;
          final informacoes = _infoColumn(notificacoes);
          final producao = _producaoBlock(alignEnd: largo);
          final chevron = info != PedidoItemInfo.page
              ? Icon(Icons.chevron_right,
                  size: 20, color: AppColors.neutralMedium)
              : const SizedBox.shrink();

          if (largo || !mostrarProducao) {
            return Row(
              children: [
                Expanded(child: informacoes),
                if (mostrarProducao) ...[
                  const W(20),
                  SizedBox(width: 200, child: producao),
                ],
                const W(8),
                chevron,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [informacoes, const SizedBox(height: 12), producao],
                ),
              ),
              const W(8),
              chevron,
            ],
          );
        },
      ),
    );

    return Container(
      clipBehavior: asCard ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: asCard
            ? Border.all(color: AppColors.neutralLight)
            : Border(bottom: BorderSide(color: AppColors.neutralLight)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(pedido),
          child: Stack(
            children: [
              conteudo,
              // Faixa lateral de destaque (notificação / comentário fixado)
              if (destaque != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: destaque),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Coluna de informações ──────────────────────────────────────────────────

  Widget _infoColumn(List<NotificacaoModel> notificacoes) {
    final temComentarioFixado = pedido.comments.any((e) => e.isFixed);
    final subtitulo = [pedido.cliente.nome.trim(), pedido.obra.descricao.trim()]
        .where((e) => e.isNotEmpty)
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiquetas + localizador
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (notificacoes.isNotEmpty) KanbanCardNotificacaoWidget(),
            if (temComentarioFixado)
              Tooltip(
                message: 'Comentário fixado',
                child: Icon(Icons.push_pin,
                    size: 16, color: AppColors.statusAtencao),
              ),
            for (final tag in pedido.tags) _tagWidget(tag),
            Text(
              pedido.localizador.trim(),
              style: AppCss.mediumBold.setSize(16),
            ),
          ],
        ),
        if (subtitulo.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppCss.minimumRegular
                .setSize(13)
                .setColor(AppColors.neutralMedium),
          ),
        ],
        if (pedido.produtos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pedido.produtos.map(_bitolaChip).toList(),
          ),
        ],
        const SizedBox(height: 10),
        // Etapa + entrega
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (pedido.steps.isNotEmpty) _etapaChip(),
            if (pedido.deliveryAt != null) _entregaChip(pedido.deliveryAt!),
          ],
        ),
      ],
    );
  }

  Widget _tagWidget(TagModel tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag.nome,
        style: AppCss.minimumBold.setSize(10).setColor(
              tag.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            ),
      ),
    );
  }

  Widget _bitolaChip(PedidoBitolaModel produto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${produto.produto.nome}  ',
            style: AppCss.minimumBold
                .setSize(11.5)
                .setColor(AppColors.neutralDark),
          ),
          TextSpan(
            text: produto.qtde.toKg(),
            style: AppCss.minimumRegular
                .setSize(11.5)
                .setColor(AppColors.neutralMedium),
          ),
        ]),
      ),
    );
  }

  /// Etapa com o ponto na cor configurada pelo usuário
  Widget _etapaChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: pedido.step.color,
            shape: BoxShape.circle,
          ),
        ),
        const W(6),
        Text(
          pedido.steps.last.step.name,
          style:
              AppCss.minimumBold.setSize(12).setColor(AppColors.neutralDark),
        ),
      ],
    );
  }

  /// Entrega: cinza no prazo, âmbar hoje, vermelho atrasado (exceto entregues)
  Widget _entregaChip(DateTime entrega) {
    final hoje = DateTime.now();
    final dia = DateTime(entrega.year, entrega.month, entrega.day);
    final diasAtraso =
        DateTime(hoje.year, hoje.month, hoje.day).difference(dia).inDays;

    Color cor = AppColors.neutralMedium;
    Color? fundo;
    String texto = 'Entrega ${entrega.text()}';
    IconData icone = Icons.event_outlined;

    if (!pedido.isEntregue) {
      if (diasAtraso > 0) {
        cor = AppColors.statusCritico;
        fundo = const Color(0xFFFDECEA);
        icone = Icons.schedule;
        texto =
            'Entrega ${entrega.text()} · ${diasAtraso == 1 ? '1 dia' : '$diasAtraso dias'} de atraso';
      } else if (diasAtraso == 0) {
        cor = AppColors.pending;
        fundo = const Color(0xFFFEF3E2);
        icone = Icons.today;
        texto = 'Entrega hoje';
      }
    }

    return Container(
      padding: fundo != null
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : EdgeInsets.zero,
      decoration: fundo != null
          ? BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(20))
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const W(4),
          Text(
            texto,
            style: AppCss.minimumBold.setSize(12).setColor(cor),
          ),
        ],
      ),
    );
  }

  // ── Bloco de produção (peso + barra) ───────────────────────────────────────

  Widget _producaoBlock({required bool alignEnd}) {
    final pronto = pedido.getPrcntgPronto().clamp(0.0, 1.0);
    final produzindo = pedido.getPrcntgProduzindo().clamp(0.0, 1.0);
    final aguardandoEntrada = pedido.isAguardandoEntradaProducao();
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    String legenda;
    if (aguardandoEntrada) {
      legenda = 'Aguardando entrada na produção';
    } else if (pronto >= 1) {
      legenda = '100% pronto';
    } else {
      legenda =
          '${(pronto * 100).percent}% pronto · ${(produzindo * 100).percent}% produzindo';
    }

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pedido.getQtdeTotal().toKg(),
          style: AppCss.mediumBold.setSize(15),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Container(
              color: AppColors.neutralLight,
              child: Row(
                children: [
                  if (!aguardandoEntrada && pronto > 0)
                    Flexible(
                      flex: (pronto * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.statusPronto),
                    ),
                  if (!aguardandoEntrada && produzindo > 0)
                    Flexible(
                      flex: (produzindo * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.statusProduzindo),
                    ),
                  // Parte "aguardando" = fundo cinza da barra. Só entra se
                  // tiver tamanho: flex 0 quebrava o layout (barra toda cinza
                  // em pedidos 100% prontos).
                  if (aguardandoEntrada || pronto + produzindo < 0.999)
                    Flexible(
                      flex: aguardandoEntrada
                          ? 1000
                          : ((1 - pronto - produzindo) * 1000)
                              .round()
                              .clamp(1, 1000),
                      child: const SizedBox.expand(),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          legenda,
          style: AppCss.minimumRegular
              .setSize(11)
              .setColor(AppColors.neutralMedium),
        ),
      ],
    );
  }

  /// Faixa lateral: vermelho M2 para notificação, âmbar para comentário fixado
  Color? _corDestaque(PedidoModel pedido, List<NotificacaoModel> notificacoes) {
    if (notificacoes.isNotEmpty) return AppColors.brand;
    if (pedido.comments.any((e) => e.isFixed)) return AppColors.statusAtencao;
    return null;
  }
}
