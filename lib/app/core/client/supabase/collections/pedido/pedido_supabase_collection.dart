import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';

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
      // 1. Fetch main table first (critical)
      final pedidosRaw = await SupabaseService.client
          .from(tableName)
          .select()
          .eq('is_archived', false);

      // 2. Fetch auxiliary tables with individual error handling
      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          final res = await SupabaseService.client.from(table).select();
          if (res == null) return [];
          final list = res as List;
          return list.map((item) {
            try {
              if (item is Map) {
                return item.map((key, value) => MapEntry(key.toString(), value));
              }
            } catch (_) {}
            return <String, dynamic>{};
          }).toList();
        } catch (_) {
          return [];
        }
      }

      final results = await Future.wait([
        safeFetch('pedido_produtos'),
        safeFetch('pedido_status_history'),
        safeFetch('pedido_steps_history'),
        safeFetch('pedido_tags'),
      ]);

      final List<Map<String, dynamic>> produtosRaw = results[0];
      final List<Map<String, dynamic>> statusRaw = results[1];
      final List<Map<String, dynamic>> stepsRaw = results[2];
      final List<Map<String, dynamic>> tagsRaw = results[3];

      final pedidos = pedidosRaw.map((pMap) {
        final String pId = pMap['id'].toString().trim();
        
        final pProdutos = produtosRaw
            .where((r) {
              final String pedidoId = (r['pedido_id'] ?? '').toString().trim();
              return pedidoId == pId;
            })
            .toList();
        
        final pedido = PedidoModel.fromSupabaseMap(
          pMap,
          produtosRaw: pProdutos,
          statusRaw: statusRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          stepsRaw: stepsRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          tagsIds: tagsRaw
              .where((r) => r['pedido_id'].toString().trim() == pId)
              .map((r) => r['tag_id'].toString())
              .toList(),
        );
        return pedido;
      }).toList();

      dataStream.add(pedidos);
      pedidosUnarchivedsStream.add(pedidos.where((e) => !e.isArchived).toList());
      pedidosPrioridadeStream
          .add(pedidos.where((e) => e.prioridade != null).toList());
    } catch (e) {
      print('Supabase Error (Pedido.start): $e');
    }
  }

  Timer? _streamDebounce;

  void _updateStreams(List<Map<String, dynamic>> raw) {
    // Em debug mode (local), rebuilds automaticos da stream causam freeze no drag
    // pois o Flutter debug mode e muito mais lento. Fetches explicitos sao suficientes.
    if (kDebugMode) return;

    _streamDebounce?.cancel();
    _streamDebounce = Timer(const Duration(seconds: 5), () {
      if (!kanbanCtrl.isDragging) start(lock: false);
    });
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
    final List<String> errorLogs = [];
    try {
      log('Supabase (Pedido.add): Sending record (upsert)...');
      await SupabaseService.client.from(tableName).upsert(model.toSupabaseMap());
      log('Supabase (Pedido.add): Record saved. Syncing relationships...');
      
      final syncErrors = await _syncRelationships(model);
      errorLogs.addAll(syncErrors);

      if (errorLogs.isNotEmpty) {
        NotificationService.showNegative('Pedido Salvo com Alertas', 'Erros: ${errorLogs.join(", ")}');
      }

      log('Supabase (Pedido.add): Fetching updated data...');
      await fetch();
      return model;
    } catch (e) {
      log('Supabase CRITICAL ERROR (Pedido.add): $e');
      NotificationService.showNegative('Erro Crítico ao Salvar Pedido', e.toString());
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

      // Nao chama fetch() aqui -- o stream debounce (2s) cuidara do refresh.
      // Chamar fetch() aqui causava rebuild do Kanban no meio do drag (freeze).
      return model;
    } catch (e) {
      log('Supabase CRITICAL ERROR (Pedido.update): $e');
      NotificationService.showNegative('Erro Crítico ao Atualizar Pedido', e.toString());
      return null;
    }
  }

  Future<List<String>> _syncRelationships(PedidoModel model) async {
    final List<String> syncErrors = [];
    try {
      // 1. Delete existing for update
      log('Supabase (Sync): Cleaning old relationships...');
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
    } catch (e) {
      syncErrors.add('Erro ao limpar relações antigas: $e');
    }

    // 2. Insert new relationships (Granular)
    try {
      // Products
      if (model.produtos.isNotEmpty) {
        final payload = model.produtos.map((p) => p.toSupabaseMap(model.id)).toList();
        await SupabaseService.client.from('pedido_produtos').insert(payload);
      }
    } catch (e) {
      syncErrors.add('Erro Produtos: $e');
    }

    try {
      // Status History
      if (model.statusess.isNotEmpty) {
        await SupabaseService.client.from('pedido_status_history').insert(
            model.statusess.map((s) => s.toSupabaseMap(model.id)).toList());
      }
    } catch (e) {
      syncErrors.add('Erro Status: $e');
    }

    try {
      // Steps History
      if (model.steps.isNotEmpty) {
        await SupabaseService.client.from('pedido_steps_history').insert(
            model.steps.map((st) => st.toSupabaseMap(model.id)).toList());
      }
    } catch (e) {
      syncErrors.add('Erro Etapas: $e');
    }

    try {
      // Tags
      if (model.tags.isNotEmpty) {
        log('Supabase (Sync): Inserting ${model.tags.length} tags...');
        await SupabaseService.client.from('pedido_tags').insert(model.tags
            .map((t) => {'pedido_id': model.id, 'tag_id': t.id})
            .toList());
      }
    } catch (e) {
      syncErrors.add('Erro na sincronia de Tags: $e');
    }

    try {
      // Archives — saved as JSONB in pedidos table, not a separate table
      // No insert needed here; archives are included in toSupabaseMap()
    } catch (e) {
      syncErrors.add('Erro Archives: $e');
    }

    return syncErrors;
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
      final maps = pedidos
          .where((e) => e != null)
          .map((e) => e.toSupabaseMap())
          .toList();
      if (maps.isNotEmpty) {
        await SupabaseService.client.from(tableName).upsert(maps);
      }
    } catch (e) {
      print('Supabase Error (Pedido.updateAll): $e');
    }
  }
}
