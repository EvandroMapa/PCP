import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:flutter/material.dart';

class OrdemPedidoStatusOperatorWidget extends StatelessWidget {
  final PedidoProdutoModel produto;
  final OrdemModel ordem;
  const OrdemPedidoStatusOperatorWidget({
    super.key,
    required this.produto,
    required this.ordem,
  });

  IconData _iconFor(PedidoProdutoStatus status) {
    switch (status) {
      case PedidoProdutoStatus.aguardandoProducao:
        return Icons.hourglass_empty_rounded;
      case PedidoProdutoStatus.produzindo:
        return Icons.construction_rounded;
      case PedidoProdutoStatus.pronto:
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      PedidoProdutoStatus.aguardandoProducao,
      PedidoProdutoStatus.produzindo,
      PedidoProdutoStatus.pronto,
    ];

    return IgnorePointer(
      ignoring: produto.isPaused,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: statuses.map((status) {
          final isActive = status == produto.status.status;
          final color = status.color;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Tooltip(
              message: isActive
                  ? 'Status atual: ${status.label}'
                  : 'Alterar para ${status.label}',
              child: InkWell(
                onTap: isActive
                    ? null
                    : () => ordemCtrl.onSelectProdutoStatus(ordem, produto, status),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isActive ? 12 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isActive ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.withValues(alpha: isActive ? 1.0 : 0.55),
                      width: isActive ? 2.5 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconFor(status),
                        size: isActive ? 18 : 15,
                        color: color.withValues(alpha: isActive ? 1.0 : 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (status == PedidoProdutoStatus.aguardandoProducao
                            ? 'AGUARDANDO'
                            : status.label.toUpperCase()),
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          // Texto sempre preto
                          color: Colors.black.withValues(alpha: isActive ? 0.85 : 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

