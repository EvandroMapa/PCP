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
      // 1. Fetch all tables in parallel
      final results = await Future.wait([
        SupabaseService.client.from(tableName).select().eq('is_archived', false),
        SupabaseService.client.from('pedido_produtos').select(),
        SupabaseService.client.from('pedido_status_history').select(),
        SupabaseService.client.from('pedido_steps_history').select(),
        SupabaseService.client.from('pedido_tags').select(),
      ]);

      final pedidosRaw = List<Map<String, dynamic>>.from(results[0]);
      final produtosRaw = List<Map<String, dynamic>>.from(results[1]);
      final statusRaw = List<Map<String, dynamic>>.from(results[2]);
      final stepsRaw = List<Map<String, dynamic>>.from(results[3]);
      final tagsRaw = List<Map<String, dynamic>>.from(results[4]);

      final pedidos = pedidosRaw.map((pMap) {
        final pId = pMap['id'];
        return PedidoModel.fromSupabaseMap(
          pMap,
          produtosRaw: produtosRaw.where((r) => r['pedido_id'] == pId).toList(),
          statusRaw: statusRaw.where((r) => r['pedido_id'] == pId).toList(),
          stepsRaw: stepsRaw.where((r) => r['pedido_id'] == pId).toList(),
          tagsIds: tagsRaw
              .where((r) => r['pedido_id'] == pId)
              .map((r) => r['tag_id'].toString())
              .toList(),
        );
      }).toList();

      dataStream.add(pedidos);
      pedidosUnarchivedsStream.add(pedidos.where((e) => !e.isArchived).toList());
      pedidosPrioridadeStream
          .add(pedidos.where((e) => e.prioridade != null).toList());
    } catch (e) {
      print('Supabase Error (Pedido.start): $e');
    }
  }

  void _updateStreams(List<Map<String, dynamic>> raw) {
    // Legacy support or for simple updates - ideally start() is called
    final pedidos = raw.map((e) => PedidoModel.fromSupabaseMap(e)).toList();
    dataStream.add(pedidos);
    pedidosUnarchivedsStream.add(pedidos.where((e) => !e.isArchived).toList());
    pedidosPrioridadeStream
        .add(pedidos.where((e) => e.prioridade != null).toList());
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

  @override
  Future<PedidoModel?> add(PedidoModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await _syncRelationships(model);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Pedido.add): $e');
      return null;
    }
  }

  @override
  Future<PedidoModel?> update(PedidoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await _syncRelationships(model);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Pedido.update): $e');
      return null;
    }
  }

  Future<void> _syncRelationships(PedidoModel model) async {
    try {
      // 1. Delete existing for update
      await Future.wait([
        SupabaseService.client
            .from('pedido_produtos')
            .delete()
            .eq('pedido_id', model.id),
        SupabaseService.client
            .from('pedido_status_history')
            .delete()
            .eq('pedido_id', model.id),
        SupabaseService.client
            .from('pedido_steps_history')
            .delete()
            .eq('pedido_id', model.id),
        SupabaseService.client
            .from('pedido_tags')
            .delete()
            .eq('pedido_id', model.id),
      ]);

      // 2. Insert new relationships
      final List<Future> insertions = [];

      // Products
      if (model.produtos.isNotEmpty) {
        insertions.add(SupabaseService.client.from('pedido_produtos').insert(
            model.produtos.map((p) => p.toSupabaseMap(model.id)).toList()));
      }

      // Status History
      if (model.statusess.isNotEmpty) {
        insertions.add(SupabaseService.client.from('pedido_status_history').insert(
            model.statusess.map((s) => s.toSupabaseMap(model.id)).toList()));
      }

      // Steps History
      if (model.steps.isNotEmpty) {
        insertions.add(SupabaseService.client.from('pedido_steps_history').insert(
            model.steps.map((st) => st.toSupabaseMap(model.id)).toList()));
      }

      // Tags
      if (model.tags.isNotEmpty) {
        insertions.add(SupabaseService.client.from('pedido_tags').insert(model.tags
            .map((t) => {'pedido_id': model.id, 'tag_id': t.id})
            .toList()));
      }

      if (insertions.isNotEmpty) {
        await Future.wait(insertions);
      }
    } catch (e) {
      print('Supabase Error (Pedido._syncRelationships): $e');
    }
  }

  @override
  Future<void> delete(PedidoModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
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
