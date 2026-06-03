import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';

enum RelatorioPedidoTipo { totaisPedidos, totais, pedidos, mestre, geral, parciais }

extension RelatorioTipoStatusExtension on RelatorioPedidoTipo {
  String get label {
    switch (this) {
      case RelatorioPedidoTipo.pedidos:
        return 'Pedidos';
      case RelatorioPedidoTipo.totais:
        return 'Totais';
      case RelatorioPedidoTipo.totaisPedidos:
        return 'Totais e Pedidos';
      case RelatorioPedidoTipo.mestre:
        return 'Relatório de Pedidos Parciais';
      case RelatorioPedidoTipo.geral:
        return 'Informações do Pedido';
      case RelatorioPedidoTipo.parciais:
        return 'Saldo e Pedidos Parciais';
    }
  }
}

class RelatorioPedidoViewModel {
  ClienteModel? cliente;
  List<PedidoBitolaStatus> status = [
    PedidoBitolaStatus.separado,
    PedidoBitolaStatus.aguardandoProducao,
    PedidoBitolaStatus.produzindo,
  ].toList();
  List<BitolaModel> produtos = FirestoreClient.bitolas.data.toList();
  RelatorioPedidoModel? relatorio;
  late SortType sortType;
  SortOrder sortOrder = SortOrder.asc;
  RelatorioPedidoTipo tipo = RelatorioPedidoTipo.totais;
  bool showFilter = false;
  List<String> expandedProdutosIds = [];

  List<SortType> sortTypes = [
    SortType.localizator,
    SortType.deliveryAt,
    SortType.qtde,
    SortType.client,
  ];

  RelatorioPedidoViewModel() {
    sortType = sortTypes.first;
  }
}

class RelatorioPedidoModel {
  final ClienteModel? cliente;
  final List<PedidoBitolaStatus> status;
  final List<BitolaModel> produtos;
  final List<PedidoModel> pedidos;
  final DateTime createdAt = DateTime.now();
  final RelatorioPedidoTipo tipo;

  RelatorioPedidoModel(
    this.cliente,
    this.status,
    this.pedidos,
    this.tipo,
    this.produtos,
  );
}
