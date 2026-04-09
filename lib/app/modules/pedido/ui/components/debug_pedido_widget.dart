import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:flutter/material.dart';

class DebugPedidoWidget extends StatelessWidget {
  final PedidoModel pedido;
  const DebugPedidoWidget(this.pedido, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: FirestoreClient.ordens.dataStream.listen,
      builder: (_, ordens) {
        final ordensArquivadas = FirestoreClient.ordens.ordensArquivadas;
        
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIAGNÓSTICO DE MONTAGEM (DEBUG)',
                style: AppCss.mediumBold.copyWith(color: Colors.white, fontSize: 14),
              ),
              const Divider(color: Colors.white24),
              _debugRow('Total Ordens Ativas:', ordens.length.toString()),
              _debugRow('Total Ordens Arquivadas:', ordensArquivadas.length.toString()),
              _debugRow('Total Pedidos Ativos:', FirestoreClient.pedidos.data.length.toString()),
              _debugRow('Total Pedidos Arquivados:', FirestoreClient.pedidos.pedidosArchiveds.length.toString()),
              const SizedBox(height: 8),
              Text(
                'Produtos do Pedido:',
                style: AppCss.minimumBold.copyWith(color: Colors.blueAccent),
              ),
              ...pedido.produtos.map((p) {
                final ordem = pedidoCtrl.getOrdemByProduto(p, true);
                final status = ordem != null 
                    ? '✅ Encontrada: ${ordem.localizator}' 
                    : '❌ Não vinculada';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${p.produto.nome}: $status',
                    style: AppCss.minimumRegular.copyWith(
                      color: ordem != null ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                );
              }),
              const Divider(color: Colors.white24),
              Text(
                'Conteúdo das Ordens Ativas:',
                style: AppCss.minimumBold.copyWith(color: Colors.orangeAccent),
              ),
              ...ordens.map((o) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${o.localizator}: ${o.idPedidosProdutosRefs}',
                  style: AppCss.minimumRegular.copyWith(color: Colors.white, fontSize: 10),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppCss.minimumRegular.copyWith(color: Colors.white70)),
          Text(value, style: AppCss.minimumBold.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
