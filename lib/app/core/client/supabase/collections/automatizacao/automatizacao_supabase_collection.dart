import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AutomatizacaoSupabaseCollection extends AutomatizacaoCollection {
  static final AutomatizacaoSupabaseCollection _instance =
      AutomatizacaoSupabaseCollection._();
  AutomatizacaoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed(AutomatizacaoModel.empty);
  }
  factory AutomatizacaoSupabaseCollection() => _instance;

  @override
  final String tableName = 'automatizacao';

  @override
  AutomatizacaoModel get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .eq('id', 'instance');
      
      if (response.isNotEmpty) {
        final automatizacao = AutomatizacaoModel.fromSupabaseMap(response.first);
        dataStream.add(automatizacao);
      } else {
        dataStream.add(AutomatizacaoModel.empty);
      }
    } catch (e) {
      print('Supabase Error (Automatizacao.start): $e');
      dataStream.add(AutomatizacaoModel.empty);
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<void> update(AutomatizacaoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', 'instance');
      await fetch();
    } catch (e) {
      print('Supabase Error (Automatizacao.update): $e');
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
        .eq('id', 'instance')
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final automatizacao = AutomatizacaoModel.fromSupabaseMap(data.first);
            dataStream.add(automatizacao);
          }
        });
  }
}
