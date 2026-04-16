import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:flutter/material.dart';

/// Barra de progresso CDA com contagem de elementos posicionados esquerda/centro/direita.
/// Só aparece para pedidos CDA quando a etapa tem isExibirGraficoCDA = true.
class KanbanCardElementosWidget extends StatelessWidget {
  final PedidoModel pedido;
  const KanbanCardElementosWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    // Só exibe para CDA
    if (pedido.tipo != PedidoTipo.cda) return const SizedBox.shrink();

    // Respeita a configuração da etapa atual: só exibe se isExibirGraficoCDA == true
    if (!pedido.step.isExibirGraficoCDA) return const SizedBox.shrink();

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
      padding: const EdgeInsets.only(top: 4),
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
          const SizedBox(height: 4),
          // ── Contagem de elementos: Ag. | Armando | Pronto ──
          Row(
            children: [
              _countLabel(aguardando.toInt(), pAguardando, Colors.grey[500]!, 'Ag.'),
              const Spacer(),
              _countLabel(armando.toInt(), pArmando, Colors.amber[700]!, 'Armando'),
              const Spacer(),
              _countLabel(pronto.toInt(), pPronto, Colors.green[600]!, 'Pronto'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countLabel(int count, double pct, Color color, String label) {
    final pctStr = '${(pct * 100).toStringAsFixed(0)}%';
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$count ($pctStr)',
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
