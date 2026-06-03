import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';

class PaiPedidoProdutoWidget extends StatefulWidget {
  final PedidoModel pedido;
  final PedidoBitolaModel produto;
  const PaiPedidoProdutoWidget(this.pedido, this.produto, {super.key});

  @override
  State<PaiPedidoProdutoWidget> createState() => _PaiPedidoProdutoWidgetState();
}

class _PaiPedidoProdutoWidgetState extends State<PaiPedidoProdutoWidget> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.pedido
        .getPedidoBitolaStatus(widget.produto)
        .getColorPedidoProdutoPai(isExpanded)
        .withValues(alpha: 0.1);
    return Column(
      children: [
        InkWell(
          onTap: widget.pedido.getPedidosFilhos().isEmpty
              ? null
              : () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
          child: Container(
            color: backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.produto.produto.nome} ${widget.produto.produto.descricao}',
                    style: AppCss.mediumBold,
                  ),
                ),
                Builder(
                  builder: (context) {
                    return Text(
                      '${widget.produto.qtdeOriginal.toKg()}',
                      style: AppCss.mediumBold,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final filho in widget.pedido.getPedidosFilhos().where(
                (e) => e.produtos.any(
                  (p) => p.produto.id == widget.produto.produto.id,
                ),
              ))
            _filhoWidget(filho, widget.produto),
        Builder(
          builder: (context) {
            if (widget.pedido.getQtdeDirecionada(widget.produto) <= 0) {
              return SizedBox.shrink();
            }
            return _restanteWidget(
              isExpanded,
              backgroundColor,
              widget.produto.qtde,
            );
          },
        ),
        const Divisor(),
      ],
    );
  }

  Widget _filhoWidget(PedidoModel filho, PedidoBitolaModel produto) {
    return InkWell(
      onTap: () async {
        await push(
          context,
          PedidoPage(pedido: filho, reason: PedidoInitReason.page),
        );
        pedidoCtrl.setPedido(filho);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filho.status.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(filho.localizador, style: AppCss.minimumRegular),
            ),
            Text(
              '-${filho.produtos.firstWhere((p) => p.produto.id == produto.produto.id).qtde.toKg()}',
              style: AppCss.minimumRegular.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restanteWidget(bool isExpanded, Color color, double qtde) {
    final double original = widget.produto.qtdeOriginal;
    final double saldo = qtde;
    final double consumido = original - saldo;
    final double percentualConsumido = original > 0 ? (consumido / original) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONSUMO DO LOTE',
                      style: AppCss.minimumBold.copyWith(
                        color: Colors.grey[600],
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentualConsumido,
                        minHeight: 8,
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentualConsumido > 0.9
                              ? Colors.red[700]!
                              : Colors.amber[700]!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SALDO ATUAL',
                    style: AppCss.minimumBold.copyWith(
                      color: Colors.green[700],
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${widget.produto.qtde.toKg()}',
                    style: AppCss.mediumBold.copyWith(
                      color: AppColors.primaryMain,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (consumido > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${(percentualConsumido * 100).toStringAsFixed(1)}% do total de ${original.toKg()} já distribuídos',
              style: AppCss.minimumRegular.copyWith(
                color: Colors.grey[600],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
