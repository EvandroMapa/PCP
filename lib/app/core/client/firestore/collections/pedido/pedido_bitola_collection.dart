import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoBitolaCollection {
  static final PedidoBitolaCollection _instance = PedidoBitolaCollection._();

  PedidoBitolaCollection._();
  PedidoBitolaCollection.base();

  factory PedidoBitolaCollection() => _instance;
  String name = 'pedido_bitolas';

  AppStream<List<PedidoBitolaModel>> dataStream =
      AppStream<List<PedidoBitolaModel>>();
  List<PedidoBitolaModel> get data => dataStream.value;

  Future<void> start({bool lock = true, GetOptions? options}) async {}
  Future<void> listen() async {}
  Future<void> fetch({bool lock = true, GetOptions? options}) async {}
  Future<PedidoBitolaModel?> add(PedidoBitolaModel model) async => null;
  Future<PedidoBitolaModel?> update(PedidoBitolaModel model) async => null;
  Future<void> delete(PedidoBitolaModel model) async {}
}
