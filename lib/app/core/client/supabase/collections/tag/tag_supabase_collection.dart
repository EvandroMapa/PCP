import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/tag_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TagSupabaseCollection extends TagCollection {
  static final TagSupabaseCollection _instance = TagSupabaseCollection._();
  TagSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory TagSupabaseCollection() => _instance;

  @override
  final String tableName = 'tags';

  @override
  List<TagModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select();
      final tags = List<Map<String, dynamic>>.from(response)
          .map((e) => TagModel.fromSupabaseMap(e))
          .toList();
      tags.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(tags);
    } catch (e) {
      print('Supabase Error (Tag.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<TagModel?> add(TagModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Tag.add): $e');
      return null;
    }
  }

  @override
  Future<TagModel?> update(TagModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Tag.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(TagModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Tag.delete): $e');
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
          final tags = data.map((e) => TagModel.fromSupabaseMap(e)).toList();
          tags.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          dataStream.add(tags);
        });
  }
}
