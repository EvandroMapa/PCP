import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoProdutoCollection {
  static final PedidoProdutoCollection _instance = PedidoProdutoCollection._();

  PedidoProdutoCollection._();
  PedidoProdutoCollection.base();

  factory PedidoProdutoCollection() => _instance;
  String name = 'pedido_produtos';

  AppStream<List<PedidoProdutoModel>> dataStream = AppStream<List<PedidoProdutoModel>>();
  List<PedidoProdutoModel> get data => dataStream.value;

  Future<void> start({bool lock = true, GetOptions? options}) async {}
  Future<void> listen() async {}
  Future<void> fetch({bool lock = true, GetOptions? options}) async {}
  Future<PedidoProdutoModel?> add(PedidoProdutoModel model) async => null;
  Future<PedidoProdutoModel?> update(PedidoProdutoModel model) async => null;
  Future<void> delete(PedidoProdutoModel model) async {}
}
