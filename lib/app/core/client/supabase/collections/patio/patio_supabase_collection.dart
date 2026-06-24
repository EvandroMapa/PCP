import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/patio_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatioSupabaseCollection extends PatioCollection {
  static final PatioSupabaseCollection _instance = PatioSupabaseCollection._();
  PatioSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory PatioSupabaseCollection() => _instance;

  @override
  final String tableName = 'patios';

  @override
  List<PatioModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final patios = List<Map<String, dynamic>>.from(response)
          .map((e) => PatioModel.fromSupabaseMap(e))
          .toList();
      patios.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(patios);
    } catch (e) {
      print('Supabase Error (Patio.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<PatioModel?> add(PatioModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap());
      // fetch() removido — o Realtime já dispara atualização automaticamente
      return model;
    } catch (e) {
      print('Supabase Error (Patio.add): $e');
      return null;
    }
  }

  @override
  Future<PatioModel?> update(PatioModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
      return model;
    } catch (e) {
      print('Supabase Error (Patio.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(PatioModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .delete()
          .eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      print('Supabase Error (Patio.delete): $e');
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
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      final patios = data.map((e) => PatioModel.fromSupabaseMap(e)).toList();
      patios.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(patios);
    });
  }
}
