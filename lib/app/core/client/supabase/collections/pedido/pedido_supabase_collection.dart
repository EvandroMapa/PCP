import 'dart:developer';
import 'package:aco_plus/app/core/services/notification_service.dart';
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
      log('Supabase (Pedido.start): Found ${pedidos.length} orders.');
      NotificationService.showPositive('Carga Supabase', 'Pedidos carregados: ${pedidos.length}');
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
    final List<String> errorLogs = [];
    try {
      log('Supabase (Pedido.add): Sending record (upsert)...');
      await SupabaseService.client.from(tableName).upsert(model.toSupabaseMap());
      log('Supabase (Pedido.add): Record saved. Syncing relationships...');
      
      final syncErrors = await _syncRelationships(model);
      errorLogs.addAll(syncErrors);

      if (errorLogs.isNotEmpty) {
        final alert = '--- ERROS DE SINCRONIZAÇÃO (PODE COPIAR) ---\n${errorLogs.join("\n")}\n------------------------------------------';
        log(alert);
        NotificationService.showNegative('Pedido Salvo com Alertas', 'Alguns itens não foram sincronizados. Erros detalhados no console.');
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
    final List<String> errorLogs = [];
    try {
      log('Supabase (Pedido.update): Updating main record...');
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      log('Supabase (Pedido.update): Main record updated. Syncing relationships...');
      
      final syncErrors = await _syncRelationships(model);
      errorLogs.addAll(syncErrors);

      if (errorLogs.isNotEmpty) {
        final alert = '--- ERROS DE SINCRONIZAÇÃO (PODE COPIAR) ---\n${errorLogs.join("\n")}\n------------------------------------------';
        log(alert);
        NotificationService.showNegative('Pedido Atualizado com Alertas', 'Alguns itens não foram sincronizados. Erros detalhados no console.');
      }

      log('Supabase (Pedido.update): Fetching updated data...');
      await fetch();
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
        print('Supabase (Sync): Tentando inserir ${model.produtos.length} produtos para o pedido ${model.id}...');
        final payload = model.produtos.map((p) => p.toSupabaseMap(model.id)).toList();
        print('Supabase (Sync): Payload de Produtos: $payload');
        
        final response = await SupabaseService.client.from('pedido_produtos').insert(payload).select();
        print('Supabase (Sync): Resposta da inserção de produtos: $response');
      } else {
        print('Supabase (Sync): O pedido ${model.id} NÃO POSSUI produtos para sincronizar.');
      }
    } catch (e) {
      print('Supabase ERROR (Sync Produtos): $e');
      syncErrors.add('Erro na sincronia de Produtos: $e');
    }

    try {
      // Status History
      if (model.statusess.isNotEmpty) {
        log('Supabase (Sync): Inserting ${model.statusess.length} status history items...');
        await SupabaseService.client.from('pedido_status_history').insert(
            model.statusess.map((s) => s.toSupabaseMap(model.id)).toList());
      }
    } catch (e) {
      syncErrors.add('Erro na sincronia de Histórico de Status: $e');
    }

    try {
      // Steps History
      if (model.steps.isNotEmpty) {
        log('Supabase (Sync): Inserting ${model.steps.length} step history items...');
        await SupabaseService.client.from('pedido_steps_history').insert(
            model.steps.map((st) => st.toSupabaseMap(model.id)).toList());
      }
    } catch (e) {
      syncErrors.add('Erro na sincronia de Histórico de Etapas: $e');
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
      final maps = pedidos.map((e) => e.toSupabaseMap()).toList();
      await SupabaseService.client.from(tableName).upsert(maps);
    } catch (e) {
      print('Supabase Error (Pedido.updateAll): $e');
    }
  }
}
