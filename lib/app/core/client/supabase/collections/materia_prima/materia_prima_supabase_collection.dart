import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/materia_prima_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MateriaPrimaSupabaseCollection extends MateriaPrimaCollection {
  static final MateriaPrimaSupabaseCollection _instance = MateriaPrimaSupabaseCollection._();
  MateriaPrimaSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory MateriaPrimaSupabaseCollection() => _instance;

  @override
  final String tableName = 'materia_prima';

  @override
  List<MateriaPrimaModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final materiaPrimas = List<Map<String, dynamic>>.from(response)
          .map((e) => MateriaPrimaModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(materiaPrimas);
    } catch (e) {
      print('Supabase Error (MateriaPrima.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<MateriaPrimaModel?> add(MateriaPrimaModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (MateriaPrima.add): $e');
      return null;
    }
  }

  @override
  Future<MateriaPrimaModel?> update(MateriaPrimaModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (MateriaPrima.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(MateriaPrimaModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (MateriaPrima.delete): $e');
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
        .listen((List<Map<String, dynamic>> data) {
          final materiaPrimas = data.map((e) => MateriaPrimaModel.fromSupabaseMap(e)).toList();
          dataStream.add(materiaPrimas);
        });
  }
}
