import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:flutter/material.dart';

/// Badge compacto que mostra o Pátio e Boxes alocados ao pedido.
/// Exibido apenas quando o pedido tem alocação.
class KanbanCardPatioWidget extends StatelessWidget {
  final PedidoModel pedido;
  const KanbanCardPatioWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    final alocacoes =
        FirestoreClient.pedidoBoxes.getByPedidoId(pedido.id);
    if (alocacoes.isEmpty) return const SizedBox.shrink();

    // Agrupa boxes por pátio
    final allBoxes = FirestoreClient.boxes.data;
    final boxesAlocados = alocacoes
        .map((a) => allBoxes.where((b) => b.id == a.boxId).firstOrNull)
        .whereType<BoxModel>()
        .toList();
    if (boxesAlocados.isEmpty) return const SizedBox.shrink();

    // Map<patioId, List<BoxModel>>
    final porPatio = <String, List<BoxModel>>{};
    for (final box in boxesAlocados) {
      porPatio.putIfAbsent(box.patioId, () => []).add(box);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: porPatio.entries.map((entry) {
        final patio = FirestoreClient.patios.data
            .where((p) => p.id == entry.key)
            .firstOrNull;
        final nomePatio = patio?.nome ?? 'Pátio';
        final nomesBoxes =
            entry.value.map((b) => b.nome).join(', ');

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFF86EFAC), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined,
                    size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$nomePatio → Box $nomesBoxes',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF166534),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
