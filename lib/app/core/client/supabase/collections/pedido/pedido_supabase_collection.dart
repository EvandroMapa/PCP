import 'dart:async';


import 'dart:developer';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';

class PedidoSupabaseCollection extends PedidoCollection {
  static final PedidoSupabaseCollection _instance = PedidoSupabaseCollection._();
  PedidoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed(<PedidoModel>[]);
    pedidosUnarchivedsStream = AppStream.seed(<PedidoModel>[]);
    pedidosArchivedsStream = AppStream.seed(<PedidoModel>[]);

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

      if (pedidosRaw.isEmpty) {
        pedidosUnarchivedsStream.add(<PedidoModel>[]);
        dataStream.add(<PedidoModel>[]);
        return;
      }

      final List<String> pIds = pedidosRaw.map((e) => e['id'].toString().trim()).toList();

      // 2. Fetch auxiliary tables FILTERED by pIds in parallel
      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          final res = await SupabaseService.client
              .from(table)
              .select()
              .filter('pedido_id', 'in', pIds);
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
        
        return PedidoModel.fromSupabaseMap(
          pMap,
          produtosRaw: pProdutos,
          statusRaw: statusRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          stepsRaw: stepsRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          tagsIds: tagsRaw
              .where((r) => r['pedido_id'].toString().trim() == pId)
              .map((r) => r['tag_id'].toString())
              .toList(),
        );
      }).toList();

      pedidosUnarchivedsStream.add(pedidos);
      dataStream.add(pedidos);

    } catch (e) {
      log('Supabase Error (Pedido.start): $e');
    }
  }

  Timer? _streamDebounce;

  void _updateStreams(List<Map<String, dynamic>> raw) {
    _streamDebounce?.cancel();
    _streamDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!kanbanCtrl.isDragging) start(lock: false);
    });
  }

  @override
  Future<PedidoModel?> getByIdSupabase(String id) async {
    try {
      final pRaw = await SupabaseService.client
          .from(tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (pRaw == null) return null;

      final pMap = pRaw as Map<String, dynamic>;

      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          final res = await SupabaseService.client
              .from(table)
              .select()
              .eq('pedido_id', id);
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

      return PedidoModel.fromSupabaseMap(
        pMap,
        produtosRaw: results[0],
        statusRaw: results[1],
        stepsRaw: results[2],
        tagsIds: results[3].map((t) => (t['tag_id'] ?? '').toString()).toList(),
      );
    } catch (e) {
      log('Supabase Error (Pedido.getByIdSupabase): $e');
      return null;
    }
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

  @override
  Future<void> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      log('Supabase (Pedido.fetchByIds): Fetching ${ids.length} records...');
      // 1. Fetch main table
      final pedidosRaw = await SupabaseService.client
          .from(tableName)
          .select()
          .filter('id', 'in', ids);

      if (pedidosRaw.isEmpty) return;

      final List<String> pIds = pedidosRaw.map((e) => e['id'].toString().trim()).toList();

      // 2. Fetch auxiliary tables in parallel
      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          final res = await SupabaseService.client
              .from(table)
              .select()
              .filter('pedido_id', 'in', pIds);
          final list = res as List;
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
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

      final newPedidos = pedidosRaw.map((pMap) {
        final String pId = pMap['id'].toString().trim();
        return PedidoModel.fromSupabaseMap(
          pMap,
          produtosRaw: produtosRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          statusRaw: statusRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          stepsRaw: stepsRaw.where((r) => r['pedido_id'].toString().trim() == pId).toList(),
          tagsIds: tagsRaw
              .where((r) => r['pedido_id'].toString().trim() == pId)
              .map((r) => r['tag_id'].toString())
              .toList(),
        );
      }).toList();

      // 3. Merge with local data and update streams
      final currentData = Map<String, PedidoModel>.fromIterable(data, key: (e) => e.id);
      for (var p in newPedidos) {
        currentData[p.id] = p;
      }
      
      final updatedList = currentData.values.toList();
      dataStream.add(updatedList);
      pedidosUnarchivedsStream.add(updatedList.where((e) => !e.isArchived).toList());


      log('Supabase (Pedido.fetchByIds): ${newPedidos.length} records synced.');
    } catch (e) {
      log('Supabase Error (Pedido.fetchByIds): $e');
    }
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
  Future<List<PedidoModel>> updateAll(List<PedidoModel> models) async {
    try {
      if (models.isEmpty) return [];
      
      final payload = models.map((e) => e.toSupabaseMap()).toList();
      await SupabaseService.client
          .from(tableName)
          .upsert(payload);
          
      // O streaming cuidará de atualizar a UI local.
      // Retornamos a lista original para consistência.
      return models;
    } catch (e) {
      log('Supabase Error (Pedido.updateAll): $e');
      return [];
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

      if (!kanbanCtrl.isDragging) {
        await fetch(lock: false);
      }

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
  Future<void> updateProdutoMateriaPrima(
    PedidoProdutoModel produto,
    MateriaPrimaModel? materiaPrima,
  ) async {
    return await updateProdutosMateriaPrima([(produto, materiaPrima)]);
  }

  Future<void> updateProdutosMateriaPrima(
    List<(PedidoProdutoModel, MateriaPrimaModel?)> updates,
  ) async {
    try {
      if (updates.isEmpty) return;

      final List<Map<String, dynamic>> payload = [];
      final Set<String> pedidoIds = {};

      for (var update in updates) {
        final produto = update.$1;
        final materiaPrima = update.$2;
        final pedido = getById(produto.pedidoId);
        pedidoIds.add(pedido.id);

        for (final p in pedido.produtos) {
          if (p.id == produto.id) {
            p.materiaPrima = materiaPrima;
            break;
          }
        }

        payload.add(pedido.produtos.firstWhere((e) => e.id == produto.id).toSupabaseMap(pedido.id));
      }

      if (payload.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_produtos')
            .upsert(payload, onConflict: 'id');
      }

      // Gatilho: atualiza a tabela pai 'pedidos' para os pedidos afetados
      if (pedidoIds.isNotEmpty) {
        for (var pId in pedidoIds) {
          final pedido = getById(pId);
          await SupabaseService.client
              .from(tableName)
              .update({'index': pedido.index})
              .eq('id', pId);
        }
      }
      
      await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutosMateriaPrima): $e');
    }
  }

  @override
  Future<void> updateProdutoPause(
    PedidoProdutoModel produto,
    bool isPaused,
  ) async {
    try {
      final pedido = getById(produto.pedidoId);
      for (final p in pedido.produtos) {
        if (p.id == produto.id) {
          p.isPaused = isPaused;
          break;
        }
      }
      await SupabaseService.client
          .from('pedido_produtos')
          .update({'is_paused': isPaused})
          .eq('id', produto.id);

      // Gatilho: atualiza a tabela pai 'pedidos' com um valor novo (timestamp) para garantir que o stream dispare
      await SupabaseService.client
          .from(tableName)
          .update({'index': pedido.index})
          .eq('id', pedido.id);
      
      // Força um fetch local imediato para a janela atual
      await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutoPause): $e');
    }
  }

  @override
  Future<void> updateProdutoStatus(
    PedidoProdutoModel produto,
    PedidoProdutoStatus status, {
    bool clear = false,
  }) async {
    return await updateProdutosStatus([(produto, status)], clear: clear);
  }

  Future<void> updateProdutosStatus(
    List<(PedidoProdutoModel, PedidoProdutoStatus)> updates, {
    bool clear = false,
  }) async {
    try {
      if (updates.isEmpty) return;

      final List<Map<String, dynamic>> payload = [];
      final Set<String> pedidoIds = {};

      for (var update in updates) {
        final produto = update.$1;
        final status = update.$2;
        final pedido = getById(produto.pedidoId);
        pedidoIds.add(pedido.id);

        final pedidoProduto =
            pedido.produtos.firstWhereOrNull((e) => e.id == produto.id);
        if (pedidoProduto == null) continue;

        if (clear) {
          pedidoProduto.statusess.clear();
        }

        if (pedidoProduto.statusess.isEmpty ||
            pedidoProduto.statusess.last.status != status) {
          pedidoProduto.statusess.add(PedidoProdutoStatusModel.create(status));
        }

        payload.add(pedidoProduto.toSupabaseMap(pedido.id));
      }

      if (payload.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_produtos')
            .upsert(payload, onConflict: 'id');
      }

      // Gatilho: atualiza a tabela pai 'pedidos' para os pedidos afetados
      if (pedidoIds.isNotEmpty) {
        for (var pId in pedidoIds) {
          final pedido = getById(pId);
          await SupabaseService.client
              .from(tableName)
              .update({'index': pedido.index})
              .eq('id', pId);
        }
      }
      
      await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutosStatus): $e');
    }
  }

  @override
  Future<PedidoModel?> updatePedidoStatus(PedidoProdutoModel produto) async {
    try {
      final pedido = getById(produto.pedidoId);
      final newPedidoStatus =
          getPedidoStatusByProduto(pedido);
      if (newPedidoStatus == pedido.status) return null;

      final statusModel = PedidoStatusModel.create(newPedidoStatus);
      pedido.statusess.add(statusModel);

      // Persist the new status in the history table
      await SupabaseService.client
          .from('pedido_status_history')
          .insert({
            'id': statusModel.id,
            'pedido_id': pedido.id,
            'status': newPedidoStatus.name,
            'created_at': statusModel.createdAt.toIso8601String(),
          });

      // Gatilho: atualiza a tabela pai 'pedidos' com um valor novo (timestamp) para garantir que o stream dispare
      await SupabaseService.client
          .from(tableName)
          .update({'index': pedido.index})
          .eq('id', pedido.id);
      
      // Força um fetch local imediato para a janela atual
      await fetch(lock: false);
      
      return pedido;
    } catch (e) {
      log('Supabase Error (updatePedidoStatus): $e');
      return null;
    }
  }
}
