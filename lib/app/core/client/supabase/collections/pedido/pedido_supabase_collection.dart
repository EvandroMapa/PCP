import 'dart:async';

import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/elemento/elemento_supabase_collection.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';

class PedidoSupabaseCollection extends PedidoCollection {
  static final PedidoSupabaseCollection _instance =
      PedidoSupabaseCollection._();
  PedidoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed(<PedidoModel>[]);
    pedidosUnarchivedsStream = AppStream.seed(<PedidoModel>[]);
    pedidosArchivedsStream = AppStream.seed(<PedidoModel>[]);
  }
  factory PedidoSupabaseCollection() => _instance;

  @override
  final String name = 'pedidos';

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

  // Não inclui elementos no join — carregados separadamente pelo ElementoSupabaseCollection
  // e resolvidos por memória em _mapPedido. Evita query com 3k+ elementos + 9k posições.
  static const String _selectCompleto = '''
    *,
    pedido_bitolas (*),
    pedido_status_history (*),
    pedido_steps_history (*),
    pedido_tags (*)
  ''';

  /// Índice de elementos por pedidoId — evita O(n×m) no _mapPedido
  Map<String, List<ElementoModel>> _elementosPorPedido = {};

  /// Reconstrói o índice a partir do cache de elementos
  void _rebuildElementosIndex() {
    _elementosPorPedido = {};
    for (final e in ElementoSupabaseCollection().data) {
      (_elementosPorPedido[e.pedidoId] ??= []).add(e);
    }
  }

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;

    // Se estiver no cooldown otimista, não sobrescreve os dados locais
    if (_optimisticCooldown) {
      log('Supabase (Pedido.start): bloqueado pelo cooldown otimista.');
      return;
    }

    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(name)
          .select(_selectCompleto)
          .eq('is_archived', false);

      // Verificação DUPLA: o cooldown pode ter sido ativado durante o await
      if (_optimisticCooldown) {
        log('Supabase (Pedido.start): cooldown ativado durante fetch, descartando resultado.');
        return;
      }

      log('Supabase (Pedido.start): ${response.length} pedidos carregados.');

      // Reconstrói índice de elementos ANTES de mapear pedidos
      _rebuildElementosIndex();

      final pedidos = response.map((pMap) => _mapPedido(pMap)).toList();

      pedidosUnarchivedsStream.add(pedidos);
      dataStream.add(pedidos);
    } catch (e) {
      log('Supabase CRITICAL Error (Pedido.start): $e');
      NotificationService.showNegative('Erro ao Carregar Pedidos', e.toString());
    }
  }

  @override
  Future<void> startOnlyArquivadas() async {
    try {
      final response = await SupabaseService.client
          .from(name)
          .select(_selectCompleto)
          .eq('is_archived', true);

      _rebuildElementosIndex();
      final pedidos = response.map((pMap) => _mapPedido(pMap)).toList();
      pedidosArchivedsStream.add(pedidos);
    } catch (e) {
      log('Supabase Error (Pedido.startOnlyArquivadas): $e');
    }
  }

  @override
  Future<PedidoModel?> getByIdSupabase(String id) async {
    try {
      final pRaw = await SupabaseService.client
          .from(name)
          .select(_selectCompleto)
          .eq('id', id)
          .maybeSingle();

      if (pRaw == null) return null;
      return _mapPedido(pRaw);
    } catch (e) {
      log('Supabase Error (Pedido.getByIdSupabase): $e');
      return null;
    }
  }

  @override
  Future<void> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final response = await SupabaseService.client
          .from(name)
          .select(_selectCompleto)
          .filter('id', 'in', '(${ids.join(",")})');

      _rebuildElementosIndex();
      final newPedidos = response.map((pMap) => _mapPedido(pMap)).toList();

      // Merge com dados locais
      final currentData = Map<String, PedidoModel>.fromIterable(data, key: (e) => e.id);
      for (var p in newPedidos) {
        currentData[p.id] = p;
      }
      final updatedList = currentData.values.toList();
      dataStream.add(updatedList);
      pedidosUnarchivedsStream.add(updatedList.where((e) => !e.isArchived).toList());
    } catch (e) {
      log('Supabase Error (Pedido.fetchByIds): $e');
    }
  }

  /// Mapeia os dados do Supabase (com joins) para o PedidoModel.
  /// Elementos são resolvidos a partir do cache em memória do ElementoSupabaseCollection.
  PedidoModel _mapPedido(Map<String, dynamic> pMap) {
    final pedidoId = (pMap['id'] ?? '').toString();

    // Monta o pedido sem elementos (join removido da query)
    final pedido = PedidoModel.fromSupabaseMap(
      pMap,
      produtosRaw: (pMap['pedido_bitolas'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e)).toList(),
      statusRaw: (pMap['pedido_status_history'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e)).toList(),
      stepsRaw: (pMap['pedido_steps_history'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e)).toList(),
      tagsIds: (pMap['pedido_tags'] as List?)
          ?.map((t) => t['tag_id'].toString()).toList(),
      elementosRaw: null,
    );

    // Injeta os elementos do índice (O(1) lookup em vez de O(n) scan)
    final elementosDoPedido = _elementosPorPedido[pedidoId] ?? [];
    pedido.elementos
      ..clear()
      ..addAll(elementosDoPedido);

    return pedido;
  }

  bool _isListen = false;
  Timer? _realtimeDebounce;

  /// Janela de proteção: após add/update otimista, bloqueia o Realtime
  /// de sobrescrever os dados locais por alguns segundos.
  bool _optimisticCooldown = false;
  Timer? _optimisticTimer;

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

    // Registra callback para re-mapear pedidos quando elementos forem
    // atualizados via Realtime. Corrige a race condition onde o Realtime de
    // elementos atualizava o cache mas os pedidos em memória continuavam com
    // os elementos antigos (sem kg, sem elementos nos cartões).
    ElementoSupabaseCollection().onUpdated = () async {
      if (!ElementoSupabaseCollection.isImportando) {
        log('PedidoSupabase: re-mapeando pedidos após atualização dos elementos.');
        // Não verifica _optimisticCooldown aqui: a atualização de elementos
        // é uma fonte externa ao pedido e DEVE sempre re-mapear.
        // Caso contrário, deletar o último elemento não atualiza o botão de parcial.
        await start(lock: false);
      }
    };

    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id'])
        .eq('is_archived', false)
        .listen((List<Map<String, dynamic>> data) {
          _realtimeDebounce?.cancel();
          _realtimeDebounce =
              Timer(const Duration(milliseconds: 1000), () async {
            if (!kanbanCtrl.isDropLocked && !_optimisticCooldown && !ElementoSupabaseCollection.isImportando) {
              await start(lock: false);
            }
          });
        });
  }



  @override
  PedidoModel getById(String id) =>
      ([...data, ...pedidosArchiveds]).firstWhereOrNull((e) => e.id == id) ??
      PedidoModel.empty();

  @override
  PedidoBitolaModel getProdutoByPedidoId(String pedidoId, String produtoId) =>
      getById(pedidoId).produtos.firstWhereOrNull((e) => e.id == produtoId) ??
      PedidoBitolaModel.empty(getById(pedidoId));

  @override
  Future<PedidoModel?> add(PedidoModel model) async {
    final List<String> errorLogs = [];
    try {
      log('Supabase (Pedido.add): Sending record (upsert)...');
      await SupabaseService.client.from(name).upsert(model.toSupabaseMap());
      log('Supabase (Pedido.add): Record saved. Syncing relationships...');

      final syncErrors = await _syncRelationships(model);
      errorLogs.addAll(syncErrors);

      if (errorLogs.isNotEmpty) {
        NotificationService.showNegative(
            'Pedido Salvo com Alertas', 'Erros: ${errorLogs.join(", ")}');
      }

      // ── Atualização otimista: injeta na lista local imediatamente ──
      final currentData = List<PedidoModel>.from(data);
      currentData.removeWhere((p) => p.id == model.id);
      currentData.add(model);
      dataStream.add(currentData);
      pedidosUnarchivedsStream
          .add(currentData.where((e) => !e.isArchived).toList());

      // Protege contra o Realtime sobrescrever dados otimistas
      _optimisticCooldown = true;
      _optimisticTimer?.cancel();
      _optimisticTimer = Timer(const Duration(seconds: 4), () {
        _optimisticCooldown = false;
        // Após o cooldown, faz fetch para garantir sincronização completa
        start(lock: false);
      });

      return model;
    } catch (e) {
      log('Supabase CRITICAL ERROR (Pedido.add): $e');
      NotificationService.showNegative(
          'Erro Crítico ao Salvar Pedido', e.toString());
      return null;
    }
  }

  @override
  Future<void> delete(PedidoModel model) async {
    try {
      log('Supabase (Pedido.delete): Deleting pedido ${model.id}...');
      // Deletar tabelas filhas primeiro
      await Future.wait([
        SupabaseService.client
            .from('pedido_bitolas')
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
      // Deletar o pedido principal
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      log('Supabase (Pedido.delete): Pedido ${model.id} deleted successfully.');
      await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (Pedido.delete): $e');
      NotificationService.showNegative('Erro ao Excluir Pedido', e.toString());
    }
  }

  @override
  Future<List<PedidoModel>> updateAll(List<PedidoModel> pedidos) async {
    try {
      if (pedidos.isEmpty) return [];

      // Atualiza SOMENTE o campo index — sem re-sincronizar relacionamentos.
      // Isso evita 409 Conflict causado por concorrência com o update() individual
      // do pedido que foi movido (que já cuida de tags, status_history, etc.).
      await Future.wait(
        pedidos.map((p) => SupabaseService.client
            .from(name)
            .update({'index': p.index})
            .eq('id', p.id)),
      );

      return pedidos;
    } catch (e) {
      log('Supabase Error (Pedido.updateAll): $e');
      return [];
    }
  }


  @override
  Future<PedidoModel?> update(PedidoModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);

      await _syncRelationships(model);

      // ── Atualização otimista: atualiza lista local imediatamente ──
      final currentData = List<PedidoModel>.from(data);
      final idx = currentData.indexWhere((p) => p.id == model.id);
      if (idx != -1) {
        currentData[idx] = model;
      } else {
        currentData.add(model);
      }
      dataStream.add(currentData);
      pedidosUnarchivedsStream
          .add(currentData.where((e) => !e.isArchived).toList());

      // Protege contra o Realtime sobrescrever dados otimistas
      _optimisticCooldown = true;
      _optimisticTimer?.cancel();
      _optimisticTimer = Timer(const Duration(seconds: 4), () {
        _optimisticCooldown = false;
        start(lock: false);
      });

      return model;
    } catch (e) {
      log('Supabase CRITICAL ERROR (Pedido.update): $e');
      NotificationService.showNegative(
          'Erro Crítico ao Atualizar Pedido', e.toString());
      return null;
    }
  }

  Future<List<String>> _syncRelationships(PedidoModel model) async {
    final List<String> syncErrors = [];
    try {
      // 1. Limpa apenas o status_history (sempre recriado)
      // O steps_history SÓ é limpo se houver steps válidos em memória
      log('Supabase (Sync): Cleaning status history...');
      await SupabaseService.client
          .from('pedido_status_history')
          .delete()
          .eq('pedido_id', model.id);
    } catch (e) {
      syncErrors.add('Erro ao limpar status histórico: $e');
    }

    // 2. Sync Products (Atomic-ish)
    try {
      final idsToKeep = model.produtos.map((e) => e.id).toList();
      if (idsToKeep.isNotEmpty) {
        final payload =
            model.produtos.map((p) => p.toSupabaseMap(model.id)).toList();
        await SupabaseService.client.from('pedido_bitolas').upsert(payload);
        // Exclui o que não está mais no modelo
        await SupabaseService.client
            .from('pedido_bitolas')
            .delete()
            .eq('pedido_id', model.id)
            .filter('id', 'not.in', '(${idsToKeep.join(",")})');
      } else {
        await SupabaseService.client
            .from('pedido_bitolas')
            .delete()
            .eq('pedido_id', model.id);
      }
    } catch (e) {
      syncErrors.add('Erro sincronia Produtos: $e');
    }

    // 3. Sync Tags (Atomic-ish)
    try {
      await SupabaseService.client
          .from('pedido_tags')
          .delete()
          .eq('pedido_id', model.id);
      if (model.tags.isNotEmpty) {
        // upsert + ignoreDuplicates evita 409 em race conditions concorrentes
        await SupabaseService.client.from('pedido_tags').upsert(
          model.tags
              .map((t) => {'pedido_id': model.id, 'tag_id': t.id})
              .toList(),
          onConflict: 'pedido_id,tag_id',
          ignoreDuplicates: true,
        );
      }
    } catch (e) {
      syncErrors.add('Erro sincronia Tags: $e');
    }

    // 4. Insert history (already cleaned)
    try {
      // Status History — upsert + ignoreDuplicates evita 409 em race conditions
      if (model.statusess.isNotEmpty) {
        await SupabaseService.client.from('pedido_status_history').upsert(
          model.statusess.map((s) => s.toSupabaseMap(model.id)).toList(),
          onConflict: 'id',
          ignoreDuplicates: true,
        );
      }
    } catch (e) {
      syncErrors.add('Erro Status: $e');
    }

    try {
      // Steps History — só recria se TODOS os steps têm step_id válido
      // Evita apagar o histórico existente quando o step não está carregado em memória
      final stepsValidos = model.steps.where((st) {
        final id = st.stepId.isNotEmpty && st.stepId != 'step-not-found'
            ? st.stepId
            : st.step.id;
        return id.isNotEmpty && id != 'step-not-found';
      }).toList();

      if (stepsValidos.isNotEmpty) {
        // Tem steps válidos: deleta e recria
        // upsert + ignoreDuplicates evita 409 em race conditions concorrentes
        await SupabaseService.client
            .from('pedido_steps_history')
            .delete()
            .eq('pedido_id', model.id);
        await SupabaseService.client.from('pedido_steps_history').upsert(
          stepsValidos.map((st) => st.toSupabaseMap(model.id)).toList(),
          onConflict: 'id',
          ignoreDuplicates: true,
        );


      }
      // Se não há steps válidos: não toca no banco (preserva o que já existe)
    } catch (e) {
      syncErrors.add('Erro Etapas: $e');
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
    PedidoBitolaModel produto,
    MateriaPrimaModel? materiaPrima,
  ) async {
    return await updateProdutosMateriaPrima([(produto, materiaPrima)]);
  }

  Future<void> updateProdutosMateriaPrima(
    List<(PedidoBitolaModel, MateriaPrimaModel?)> updates,
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

        payload.add(pedido.produtos
            .firstWhere((e) => e.id == produto.id)
            .toSupabaseMap(pedido.id));
      }

      if (payload.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_bitolas')
            .upsert(payload, onConflict: 'id');
      }

      // Gatilho: atualiza a tabela pai 'pedidos' para os pedidos afetados (em paralelo)
      if (pedidoIds.isNotEmpty) {
        await Future.wait(pedidoIds.map((pId) {
          final pedido = getById(pId);
          return SupabaseService.client
              .from(name)
              .update({'index': pedido.index}).eq('id', pId);
        }));
      }

      // await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutosMateriaPrima): $e');
    }
  }

  @override
  Future<void> updateProdutoPause(
    PedidoBitolaModel produto,
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
          .from('pedido_bitolas')
          .update({'is_paused': isPaused}).eq('id', produto.id);

      // Gatilho: atualiza a tabela pai 'pedidos' com um valor novo (timestamp) para garantir que o stream dispare
      await SupabaseService.client
          .from(name)
          .update({'index': pedido.index}).eq('id', pedido.id);

      // Força um fetch local imediato para a janela atual
      // await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutoPause): $e');
    }
  }

  @override
  Future<void> updateProdutoStatus(
    PedidoBitolaModel produto,
    PedidoBitolaStatus status, {
    bool clear = false,
  }) async {
    return await updateProdutosStatus([(produto, status)], clear: clear);
  }

  Future<void> updateProdutosStatus(
    List<(PedidoBitolaModel, PedidoBitolaStatus)> updates, {
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
        // Fallback: se não encontrar no cache do pedido, usa o próprio objeto
        // (evita pular silenciosamente e deixar status órfão)
        final alvo = pedidoProduto ?? produto;

        if (clear) {
          alvo.statusess.clear();
        }

        if (alvo.statusess.isEmpty ||
            alvo.statusess.last.status != status) {
          alvo.statusess.add(PedidoBitolaStatusModel.create(status));
        }

        payload.add(alvo.toSupabaseMap(pedido.id));
      }

      if (payload.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_bitolas')
            .upsert(payload, onConflict: 'id');
      }

      // Gatilho: atualiza a tabela pai 'pedidos' para os pedidos afetados (em paralelo)
      if (pedidoIds.isNotEmpty) {
        await Future.wait(pedidoIds.map((pId) {
          final pedido = getById(pId);
          return SupabaseService.client
              .from(name)
              .update({'index': pedido.index}).eq('id', pId);
        }));
      }

      // await fetch(lock: false);
    } catch (e) {
      log('Supabase Error (updateProdutosStatus): $e');
    }
  }

  @override
  Future<PedidoModel?> updatePedidoStatus(PedidoBitolaModel produto) async {
    try {
      final pedido = getById(produto.pedidoId);
      final newPedidoStatus = getPedidoStatusByProduto(pedido);
      if (newPedidoStatus == pedido.status) return null;

      final statusModel = PedidoStatusModel.create(newPedidoStatus);
      pedido.statusess.add(statusModel);

      // Persist the new status in the history table
      await SupabaseService.client.from('pedido_status_history').insert({
        'id': statusModel.id,
        'pedido_id': pedido.id,
        'status': newPedidoStatus.name,
        'created_at': statusModel.createdAt.toIso8601String(),
      });

      // Gatilho: atualiza a tabela pai 'pedidos' com um valor novo (timestamp) para garantir que o stream dispare
      await SupabaseService.client
          .from(name)
          .update({'index': pedido.index}).eq('id', pedido.id);

      // Força um fetch local imediato para a janela atual
      // await fetch(lock: false);

      return pedido;
    } catch (e) {
      log('Supabase Error (updatePedidoStatus): $e');
      return null;
    }
  }
}
