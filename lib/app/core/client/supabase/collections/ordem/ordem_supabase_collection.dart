import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/ordem_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class OrdemSupabaseCollection extends OrdemCollection {
  static final OrdemSupabaseCollection _instance = OrdemSupabaseCollection._();
  OrdemSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
    ordensNaoArquivadasStream = AppStream.seed([]);
    ordensArquivadasStream = AppStream.seed([]);
  }
  factory OrdemSupabaseCollection() => _instance;

  Timer? _streamDebounce;
  bool _isReordering = false;

  @override
  final String name = 'ordens';

  @override
  List<OrdemModel> get data => dataStream.value;

  @override
  List<OrdemModel> get ordensArquivadas => ordensArquivadasStream.value;

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
          .from(name)
          .select()
          .eq('is_archived', false);

      final ordens = List<Map<String, dynamic>>.from(response)
          .map((e) => OrdemModel.fromSupabaseMap(e))
          .toList();

      _updateStreams(ordens);
    } catch (e) {
      log('Supabase Error (Ordem.start): $e');
    }
  }

  @override
  Future<void> startOnlyArquivadas({DateTime? de, DateTime? ate}) async {
    try {
      // Período padrão: mês corrente
      final inicio = de ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      final fim = ate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 1)
          .subtract(const Duration(seconds: 1));

      final response = await SupabaseService.client
          .from(name)
          .select()
          .eq('is_archived', true)
          .gte('updated_at', inicio.toIso8601String())
          .lte('updated_at', fim.toIso8601String());

      final ordens = List<Map<String, dynamic>>.from(response)
          .map((e) => OrdemModel.fromSupabaseMap(e))
          .toList();

      ordensArquivadasStream.add(ordens);
    } catch (e) {
      log('Supabase Error (Ordem.startOnlyArquivadas): $e');
    }
  }

  void _updateStreams(List<OrdemModel> ordens) {
    final ordensNaoArquivadas = ordens.where((e) => !e.isArchived).toList();
    ordensNaoArquivadas.sort((a, b) {
      if (a.freezed.isFreezed && !b.freezed.isFreezed) return 1;
      if (!a.freezed.isFreezed && b.freezed.isFreezed) return -1;
      if (a.beltIndex == null || b.beltIndex == null) return 0;
      return a.beltIndex!.compareTo(b.beltIndex!);
    });

    ordensNaoArquivadasStream.add(ordensNaoArquivadas);
    dataStream.add(ordensNaoArquivadas);
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
        .from(name)
        .stream(primaryKey: ['id'])
        .eq('is_archived', false)
        .listen((List<Map<String, dynamic>> data) {
          // Ignora eventos do Realtime durante reorder para evitar
          // que a UI reverta antes de todos os belt_index serem persistidos
          if (_isReordering) return;
          // Debounce para evitar rebuilds rápidos que acessam pedidos
          // ainda não carregados (ex: durante onReorder batch updates)
          _streamDebounce?.cancel();
          _streamDebounce = Timer(const Duration(milliseconds: 500), () {
            start(lock: false);
          });
        });
  }

  @override
  Future<OrdemModel?> add(OrdemModel model) async {
    await SupabaseService.client.from(name).insert(model.toSupabaseMap());
    // pedidos.fetch() removido — o Realtime de pedidos já cuida da sincronização.
    // Antes: cada add de ordem disparava SELECT + 4 JOINs em todos os pedidos.
    return model;
  }

  @override
  Future<OrdemModel?> update(OrdemModel model) async {
    await SupabaseService.client
        .from(name)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    return model;
  }

  /// Atualiza apenas o beltIndex (usado pelo onReorder) sem recarregar pedidos.
  Future<void> updateBeltIndex(OrdemModel model) async {
    await SupabaseService.client
        .from(name)
        .update({'belt_index': model.beltIndex}).eq('id', model.id);
  }

  /// Atualiza todos os beltIndex de uma vez, bloqueando o Realtime durante o processo.
  Future<void> reorderAll(List<OrdemModel> ordens) async {
    _isReordering = true;
    try {
      final futures = ordens.map((ordem) => SupabaseService.client
          .from(name)
          .update({'belt_index': ordem.beltIndex}).eq('id', ordem.id));
      await Future.wait(futures);
    } finally {
      // Mantém o bloqueio por 2s para absorver eventos Realtime
      // que chegam após os updates serem persistidos.
      // O estado local já está correto (atualizado no onReorder).
      Timer(const Duration(milliseconds: 2000), () {
        _isReordering = false;
      });
    }
  }

  @override
  Future<void> delete(OrdemModel model) async {
    await SupabaseService.client.from(name).delete().eq('id', model.id);
    // pedidos.fetch() removido — o Realtime de pedidos já cuida da sincronização.
  }

  @override
  Stream<OrdemModel> listenById(String id) {
    return dataStream.listen.map((_) => getById(id));
  }
}
