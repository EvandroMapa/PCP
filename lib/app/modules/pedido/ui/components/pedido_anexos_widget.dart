import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/components/archive/ui/archives_widget.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:flutter/material.dart';

class PedidoAnexosWidget extends StatelessWidget {
  final PedidoModel pedido;
  const PedidoAnexosWidget(this.pedido, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ArchivesWidget(
        path: 'pedidos/${pedido.id}',
        archives: pedido.archives,
        onChanged: (List<ArchiveModel> archives) {
          // Pega o pedido MAIS RECENTE do stream e aplica os archives explicitamente
          // Evita a race condition onde o polling timer substituía o pedido
          // entre o archives.add() e o save
          final latest = pedidoCtrl.pedidoStream.value;
          final updated = latest.copyWith(archives: archives);
          pedidoCtrl.pedidoStream.add(updated);
          BackendClient.pedidos.update(updated);
        },
      ),
    );
  }
}
