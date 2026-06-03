import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/modules/graph/bitola_status/bitola_status_model.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

final bitolaStatusCtrl = BitolaStatusController();

class BitolaStatusController {
  static final BitolaStatusController _instance = BitolaStatusController._();

  BitolaStatusController._();

  factory BitolaStatusController() => _instance;

  List<ColumnSeries<BitolaStatusGraphModel, String>> getSource() {
    return [
      PedidoBitolaStatus.aguardandoProducao,
      PedidoBitolaStatus.produzindo,
      PedidoBitolaStatus.pronto,
    ]
        .map(
          (status) => ColumnSeries<BitolaStatusGraphModel, String>(
            dataSource: getSourceByStatus(status),
            name: status.label,
            xValueMapper: (BitolaStatusGraphModel data, _) =>
                data.produto.descricao,
            yValueMapper: (BitolaStatusGraphModel data, _) => data.qtde,
            color: status.color,
            pointColorMapper: (BitolaStatusGraphModel data, _) =>
                data.status.color,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
            ),
          ),
        )
        .toList();
  }

  List<BitolaStatusGraphModel> getSourceByStatus(PedidoBitolaStatus status) {
    final pedidos = FirestoreClient.pedidos.data
        .where((p) => !p.isArchived) // Omitir arquivados
        .map((e) => e.copyWith())
        .toList();

    List<PedidoBitolaModel> pedidosProdutos = [];
    for (var pedido in pedidos) {
      for (var produto in pedido.produtos) {
        final currentStatus = produto.status.getStatusMinified();
        if (currentStatus == status ||
            (status == PedidoBitolaStatus.aguardandoProducao &&
                currentStatus == PedidoBitolaStatus.separado)) {
          pedidosProdutos.add(produto.copyWith());
        }
      }
    }

    List<BitolaStatusGraphModel> graph = [];
    for (BitolaModel produto in FirestoreClient.bitolas.data.map(
      (e) => e.copyWith(),
    )) {
      for (PedidoBitolaModel pedido in pedidosProdutos.where(
        (e) => e.produto.id == produto.id,
      )) {
        if (graph.any((e) => e.produto.id == produto.id)) {
          graph.firstWhere((e) => e.produto.id == produto.id).qtde +=
              pedido.qtde;
        } else {
          graph.add(
            BitolaStatusGraphModel(
              status: pedido.status.getStatusMinified(),
              produto: produto,
              qtde: pedido.qtde,
            ),
          );
        }
      }
    }

    for (var produto in FirestoreClient.bitolas.data.map(
      (e) => e.copyWith(),
    )) {
      if (!graph.map((e) => e.produto.id).contains(produto.id)) {
        graph.add(
          BitolaStatusGraphModel(status: status, produto: produto, qtde: 0),
        );
      }
    }

    return graph;
  }
}
