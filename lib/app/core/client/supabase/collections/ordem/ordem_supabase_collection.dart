import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/ordem_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdemSupabaseCollection extends OrdemCollection {
  static final OrdemSupabaseCollection _instance = OrdemSupabaseCollection._();
  OrdemSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
    ordensNaoArquivadasStream = AppStream.seed([]);
    ordensArquivadasStream = AppStream.seed([]);
  }
  factory OrdemSupabaseCollection() => _instance;

  @override
  final String tableName = 'ordens';

  @override
  List<OrdemModel> get data => dataStream.value;

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
      
      final ordens = List<Map<String, dynamic>>.from(response)
          .map((e) => OrdemModel.fromSupabaseMap(e))
          .toList();
      
      _updateStreams(ordens);
    } catch (e) {
      print('Supabase Error (Ordem.start): $e');
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
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq('is_archived', false)
        .listen((List<Map<String, dynamic>> data) {
          final ordens = data.map((e) => OrdemModel.fromSupabaseMap(e)).toList();
          _updateStreams(ordens);
        });
  }

  @override
  Future<OrdemModel?> add(OrdemModel model) async {
    await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
    // Após adicionar ordem, forçar atualização de pedidos (pois eles agora estão vinculados)
    await BackendClient.pedidos.fetch();
    return model;
  }

  @override
  Future<OrdemModel?> update(OrdemModel model) async {
    await SupabaseService.client
        .from(tableName)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    // Após atualizar ordem, forçar atualização de pedidos
    await BackendClient.pedidos.fetch();
    return model;
  }

  @override
  Future<void> delete(OrdemModel model) async {
    await SupabaseService.client.from(tableName).delete().eq('id', model.id);
    // Após deletar ordem, forçar atualização de pedidos
    await BackendClient.pedidos.fetch();
  }
}
