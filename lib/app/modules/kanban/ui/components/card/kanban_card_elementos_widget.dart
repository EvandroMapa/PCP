import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:flutter/material.dart';

/// Mini barra de progresso tricolor para status dos elementos de armação.
/// Aparece somente em pedidos CDA com armacaoResumo preenchido.
class KanbanCardElementosWidget extends StatelessWidget {
  final PedidoModel pedido;
  const KanbanCardElementosWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    // Só exibe para CDA com resumo preenchido
    if (pedido.tipo != PedidoTipo.cda) return const SizedBox.shrink();

    final resumo = pedido.armacaoResumo;
    final totalQtd = (resumo['total_qtd'] ?? 0) as num;
    if (totalQtd <= 0) return const SizedBox.shrink();

    final details = resumo['details'] as Map<String, dynamic>? ?? {};
    final aguardando = (details['aguardando']?['qtd'] ?? 0) as num;
    final armando = (details['armando']?['qtd'] ?? 0) as num;
    final pronto = (details['pronto']?['qtd'] ?? 0) as num;

    final pAguardando = aguardando / totalQtd;
    final pArmando = armando / totalQtd;
    final pPronto = pronto / totalQtd;

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
                      child: Container(color: Colors.green[600]),
                    ),
                  if (pArmando > 0)
                    Flexible(
                      flex: (pArmando * 1000).toInt().clamp(1, 1000),
                      child: Container(color: Colors.yellow[700]),
                    ),
                  if (pAguardando > 0)
                    Flexible(
                      flex: (pAguardando * 1000).toInt().clamp(1, 1000),
                      child: Container(color: Colors.grey[300]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          // ── Label ──
          Row(
            children: [
              Icon(Icons.construction_rounded, size: 10, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  'Pronto ${pronto.toInt()}, Armando ${armando.toInt()}, Aguardando ${aguardando.toInt()}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: pronto == totalQtd
                        ? Colors.green[700]
                        : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
