import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';

class PedidoSupabaseCollection extends PedidoCollection {
  static final PedidoSupabaseCollection _instance = PedidoSupabaseCollection._();
  PedidoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
    pedidosUnarchivedsStream = AppStream.seed([]);
    pedidosArchivedsStream = AppStream.seed([]);
    pedidosPrioridadeStream = AppStream.seed([]);
  }
  factory PedidoSupabaseCollection() => _instance;

  @override
  final String tableName = 'pedidos';

  @override
  List<PedidoModel> get data => dataStream.value;

  @override
  List<PedidoModel> get pepidosUnarchiveds => pedidosUnarchivedsStream.value;

  @override
  List<PedidoModel> get pedidosArchiveds => pedidosArchivedsStream.value;

  @override
  List<PedidoModel> get pedidosPrioridade => pedidosPrioridadeStream.value;

  bool _isStarted = false;

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .eq('is_archived', false);
      _updateStreams(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      print('Supabase Error (Pedido.start): $e');
    }
  }

  void _updateStreams(List<Map<String, dynamic>> raw) {
    final pedidos = raw.map((e) => PedidoModel.fromSupabaseMap(e)).toList();
    dataStream.add(pedidos);
    pedidosUnarchivedsStream.add(pedidos.where((e) => !e.isArchived).toList());
    pedidosPrioridadeStream.add(pedidos.where((e) => e.prioridade != null).toList());
  }

  bool _isListen = false;
  @override
  Future<void> listen({
    Object? field,
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq('is_archived', false)
        .listen((List<Map<String, dynamic>> data) {
          _updateStreams(data);
        });
  }

  PedidoModel getById(String id) =>
      ([...data, ...pedidosArchiveds]).firstWhereOrNull((e) => e.id == id) ??
      PedidoModel.empty();

  PedidoProdutoModel getProdutoByPedidoId(String pedidoId, String produtoId) =>
      getById(pedidoId).produtos.firstWhereOrNull((e) => e.id == produtoId) ??
      PedidoProdutoModel.empty(getById(pedidoId));

  Future<PedidoModel?> add(PedidoModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      return model;
    } catch (e) {
      print('Supabase Error (Pedido.add): $e');
      return null;
    }
  }

  Future<PedidoModel?> update(PedidoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      return model;
    } catch (e) {
      print('Supabase Error (Pedido.update): $e');
      return null;
    }
  }

  Future<void> delete(PedidoModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
    } catch (e) {
      print('Supabase Error (Pedido.delete): $e');
    }
  }

  Future<void> updateAll(List<PedidoModel> pedidos) async {
    try {
      final maps = pedidos.map((e) => e.toSupabaseMap()).toList();
      await SupabaseService.client.from(tableName).upsert(maps);
    } catch (e) {
      print('Supabase Error (Pedido.updateAll): $e');
    }
  }
}
