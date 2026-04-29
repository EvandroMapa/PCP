import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:flutter/material.dart';

class OrdemPedidoStatusOperatorWidget extends StatelessWidget {
  final PedidoProdutoModel produto;
  final OrdemModel ordem;
  final bool readOnly;
  const OrdemPedidoStatusOperatorWidget({
    super.key,
    required this.produto,
    required this.ordem,
    this.readOnly = false,
  });

  IconData _iconFor(PedidoProdutoStatus status, {bool isActive = false}) {
    switch (status) {
      case PedidoProdutoStatus.aguardandoProducao:
        return isActive ? Icons.hourglass_bottom_rounded : Icons.hourglass_empty_rounded;
      case PedidoProdutoStatus.produzindo:
        return Icons.construction_rounded;
      case PedidoProdutoStatus.pronto:
        return isActive ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded;
      default:
        return isActive ? Icons.circle : Icons.circle_outlined;
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
      ignoring: produto.isPaused || readOnly,
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
                    : () =>
                        ordemCtrl.onSelectProdutoStatus(ordem, produto, status),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isActive ? 12 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: isActive 
                        ? null 
                        : Border.all(
                            color: color.withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 14,
                              spreadRadius: 3,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconFor(status, isActive: isActive),
                        size: isActive ? 18 : 15,
                        color: isActive ? Colors.black : color.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (status == PedidoProdutoStatus.aguardandoProducao
                            ? 'AGUARDANDO'
                            : status.label.toUpperCase()),
                        style: TextStyle(
                          fontSize: isActive ? 14 : 12,
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w500,
                          color: isActive
                              ? Colors.black
                              : Colors.black.withValues(alpha: 0.55),
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
