import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/models/pedido_box_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';

/// Coleção base (Firestore stub) — a implementação real é Supabase.
class PedidoBoxCollection {
  static final PedidoBoxCollection _instance = PedidoBoxCollection._();
  PedidoBoxCollection._();
  PedidoBoxCollection.base();
  factory PedidoBoxCollection() => _instance;

  String name = 'pedido_boxes';
  String get tableName => name;

  AppStream<List<PedidoBoxModel>> dataStream =
      AppStream<List<PedidoBoxModel>>.seed([]);
  List<PedidoBoxModel> get data => dataStream.value;

  Future<void> start() async {}
  Future<void> fetch() async {}
  Future<void> listen() async {}

  List<PedidoBoxModel> getByPedidoId(String pedidoId) =>
      data.where((e) => e.pedidoId == pedidoId).toList();

  List<PedidoBoxModel> getByBoxId(String boxId) =>
      data.where((e) => e.boxId == boxId).toList();

  Future<PedidoBoxModel?> add(PedidoBoxModel model) async => null;
  Future<void> delete(PedidoBoxModel model) async {}
  Future<void> deleteByPedidoId(String pedidoId) async {}
}
