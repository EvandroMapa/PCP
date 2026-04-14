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
                    horizontal: 14,
                    vertical: isActive ? 11 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? color : color.withValues(alpha: 0.25),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(status),
                        size: isActive ? 18 : 15,
                        color: isActive ? Colors.white : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive ? Colors.white : color.withValues(alpha: 0.65),
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

