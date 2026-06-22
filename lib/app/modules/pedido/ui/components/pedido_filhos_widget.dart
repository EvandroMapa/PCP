import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_create_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:flutter/material.dart';

class PedidoFilhosWidget extends StatelessWidget {
  final PedidoModel pedido;
  final List<PedidoModel> filhos;
  const PedidoFilhosWidget({
    super.key,
    required this.pedido,
    required this.filhos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho ──
        Row(
          children: [
            Expanded(
              child: Text('Informações Gerais',
                  style: AppCss.smallBold.setSize(13)),
            ),
            InkWell(
              onTap: () => pedidoCtrl.onGeneratePDF(pedido),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.redAccent, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Recalcular Saldo',
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 300),
              child: InkWell(
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  await pedidoCtrl.recalcularSaldo(pedido);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calculate_outlined,
                      color: Colors.orange, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async => push(context, PedidoCreatePage(pai: pedido)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Grid de cards ──
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filhos
              .map((filho) => _ParcialCard(
                    mestre: pedido,
                    filho: filho,
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// Card compacto estilo armação: tarja preta + badge CD/CDA + hover produtos.
class _ParcialCard extends StatefulWidget {
  final PedidoModel mestre;
  final PedidoModel filho;

  const _ParcialCard({required this.mestre, required this.filho});

  @override
  State<_ParcialCard> createState() => _ParcialCardState();
}

class _ParcialCardState extends State<_ParcialCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final filho = widget.filho;
    final isArquivado = filho.isArchived;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 264,
      decoration: BoxDecoration(
        color: isArquivado ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isArquivado
              ? const Color(0xFFCBD5E1)
              : Colors.black,
          width: isArquivado ? 1.0 : 1.5,
        ),
        boxShadow: isArquivado
            ? []
            : [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: _isHovered ? 0.15 : 0.06),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 6 : 3),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tarja (preta se ativo, cinza se arquivado) ──
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isArquivado
                  ? const Color(0xFF64748B)
                  : Colors.black,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                if (isArquivado) ...[
                  const Icon(Icons.archive_outlined,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    filho.localizador,
                    style: AppCss.mediumBold
                        .setSize(13)
                        .setColor(isArquivado
                            ? Colors.white70
                            : Colors.white)
                        .copyWith(letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Badge CD/CDA ou ARQUIVADO
                if (isArquivado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.5),
                    ),
                    child: Text(
                      'ARQUIVADO',
                      style: AppCss.minimumBold.copyWith(
                          fontSize: 9, color: Colors.white70),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.5),
                    ),
                    child: Text(
                      filho.tipo.name.toUpperCase(),
                      style: AppCss.minimumBold.copyWith(
                          fontSize: 9, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Botão excluir — oculto para arquivados
                  InkWell(
                    onTap: () async {
                      final confirm = await showConfirmDialog(
                        'Excluir Parcial',
                        'Deseja excluir "${filho.localizador}"? O saldo será devolvido ao Mestre.',
                      );
                      if (confirm && context.mounted) {
                        final excluiu = await pedidoCtrl.onDelete(
                          context,
                          filho,
                          isPedido: false,
                        );
                        if (excluiu) {
                          final mestreAtualizado =
                              FirestoreClient.pedidos.getById(widget.mestre.id);
                          pedidoCtrl.pedidoStream.add(mestreAtualizado);
                        }
                      }
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 13, color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Corpo: cliente + total ──
          Opacity(
            opacity: isArquivado ? 0.6 : 1.0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filho.descricao.isNotEmpty
                        ? filho.descricao
                        : 'Sem descrição',
                    style: AppCss.minimumRegular.copyWith(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: filho.descricao.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.scale_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        filho.getQtdeTotal().toKg(),
                        style: AppCss.minimumBold.copyWith(fontSize: 13),
                      ),
                      const Spacer(),
                      if (!isArquivado)
                        Icon(Icons.chevron_right,
                            size: 16, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Produtos (hover) — não exibe para arquivados ──
          if (!isArquivado)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in filho.produtos)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.produto.nome,
                                style: AppCss.minimumRegular
                                    .copyWith(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              p.qtde.toKg(),
                              style: AppCss.minimumBold.copyWith(
                                  fontSize: 10,
                                  color: const Color(0xFF374151)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: _isHovered
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );

    // Arquivados: só visual, sem clique
    if (isArquivado) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () async {
          await push(
            context,
            PedidoPage(pedido: filho, reason: PedidoInitReason.page),
          );
          final mestreAtualizado =
              FirestoreClient.pedidos.getById(widget.mestre.id);
          pedidoCtrl.pedidoStream.add(mestreAtualizado);
        },
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}
