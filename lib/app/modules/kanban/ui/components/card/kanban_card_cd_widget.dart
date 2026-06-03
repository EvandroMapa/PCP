import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:flutter/material.dart';

/// Barra de progresso CD com percentuais posicionados esquerda/centro/direita.
class KanbanCardCDWidget extends StatelessWidget {
  final PedidoModel pedido;
  const KanbanCardCDWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    final total = pedido.getQtdeTotal();
    if (total <= 0) return const SizedBox.shrink();

    final produzindo = pedido.getQtdeProduzindo();
    final pronto = pedido.getQtdePronto();
    final aguardando = pedido.getQtdeAguardandoProducao();

    // Não exibe se nenhuma peça entrou em produção ainda
    if (produzindo == 0 && pronto == 0) return const SizedBox.shrink();

    final pAguardando = aguardando / total;
    final pProduzindo = produzindo / total;
    final pPronto = pronto / total;

    final pctAg = '${(pAguardando * 100).toStringAsFixed(0)}%';
    final pctProd = '${(pProduzindo * 100).toStringAsFixed(0)}%';
    final pctPronto = '${(pPronto * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra de progresso segmentada ──
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (pPronto > 0)
                    Flexible(
                      flex: (pPronto * 1000).toInt().clamp(1, 1000),
                      child: Container(color: PedidoBitolaStatus.pronto.color),
                    ),
                  if (pProduzindo > 0)
                    Flexible(
                      flex: (pProduzindo * 1000).toInt().clamp(1, 1000),
                      child: Container(
                          color: PedidoBitolaStatus.produzindo.color),
                    ),
                  if (pAguardando > 0)
                    Flexible(
                      flex: (pAguardando * 1000).toInt().clamp(1, 1000),
                      child: Container(
                        color: PedidoBitolaStatus.aguardandoProducao.color
                            .withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ── Percentuais: Ag. | Produzindo | Pronto ──
          Row(
            children: [
              _pctLabel(
                  pctAg,
                  PedidoBitolaStatus.aguardandoProducao.color
                      .withValues(alpha: 0.8),
                  'Ag.'),
              const Spacer(),
              _pctLabel(pctProd, PedidoBitolaStatus.produzindo.color, 'Prod.'),
              const Spacer(),
              _pctLabel(pctPronto, PedidoBitolaStatus.pronto.color, 'Pronto'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pctLabel(String pct, Color color, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: pct,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
