import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';

class KanbanCardDetailsWidget extends StatelessWidget {
  final PedidoModel pedido;
  final bool showDeliveryAt;
  const KanbanCardDetailsWidget(
    this.pedido, {
    super.key,
    this.showDeliveryAt = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        if (showDeliveryAt)
          if (pedido.deliveryAt != null) _entregaWidget(pedido.deliveryAt!),
        if (pedido.archives.isNotEmpty)
          _detailWidget(
            Icons.file_present,
            value: pedido.archives.length.toString(),
          ),
        if (pedido.checks.isNotEmpty)
          _detailWidget(
            Icons.checklist,
            value:
                '${pedido.checks.where((e) => e.isCheck).length}/${pedido.checks.length}',
          ),
        if (pedido.comments.isNotEmpty)
          _detailWidget(
            Icons.comment_outlined,
            value: pedido.comments.length.toString(),
          ),
      ],
    );
  }

  /// Entrega: cinza no prazo, âmbar hoje, vermelho com os dias de atraso
  /// (pedidos entregues ficam sempre em cinza)
  Widget _entregaWidget(DateTime entrega) {
    final hoje = DateTime.now();
    final dias = DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(entrega.year, entrega.month, entrega.day))
        .inDays;
    if (pedido.isEntregue || dias < 0) {
      return _detailWidget(Icons.timer_outlined, value: entrega.toddMM());
    }
    final atrasado = dias > 0;
    final cor = atrasado ? AppColors.statusCritico : const Color(0xFFB45309);
    final texto = atrasado
        ? '${entrega.toddMM()} · ${dias == 1 ? '1 dia' : '$dias dias'}'
        : 'Hoje';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: atrasado ? const Color(0xFFFDECEA) : const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(atrasado ? Icons.schedule : Icons.today, color: cor, size: 13),
          const W(4),
          Text(
            texto,
            style: TextStyle(
                color: cor, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _detailWidget(IconData icon, {String? value}) {
    return IntrinsicWidth(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF787C86), size: 14),
          if (value != null) ...[
            const W(4),
            Text(
              value,
              style: const TextStyle(color: Color(0xFF787C86), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
