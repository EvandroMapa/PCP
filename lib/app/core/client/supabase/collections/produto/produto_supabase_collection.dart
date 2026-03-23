import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProdutoSupabaseCollection extends ProdutoCollection {
  static final ProdutoSupabaseCollection _instance = ProdutoSupabaseCollection._();
  ProdutoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory ProdutoSupabaseCollection() => _instance;

  @override
  final String tableName = 'produtos';

  @override
  List<ProdutoModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final produtos = List<Map<String, dynamic>>.from(response)
          .map((e) => ProdutoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(produtos);
    } catch (e) {
      print('Supabase Error (Produto.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<ProdutoModel?> add(ProdutoModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Produto.add): $e');
      return null;
    }
  }

  @override
  Future<ProdutoModel?> update(ProdutoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Produto.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(ProdutoModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Produto.delete): $e');
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
          final produtos = data.map((e) => ProdutoModel.fromSupabaseMap(e)).toList();
          dataStream.add(produtos);
        });
  }
}
