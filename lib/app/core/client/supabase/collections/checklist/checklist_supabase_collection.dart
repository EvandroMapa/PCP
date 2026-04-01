import 'package:aco_plus/app/core/client/firestore/collections/checklist/checklist_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/checklist/models/checklist_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistSupabaseCollection extends ChecklistCollection {
  static final ChecklistSupabaseCollection _instance =
      ChecklistSupabaseCollection._();
  ChecklistSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory ChecklistSupabaseCollection() => _instance;

  @override
  final String tableName = 'checklists';

  @override
  List<ChecklistModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .order('created_at', ascending: true);
      final checklists = List<Map<String, dynamic>>.from(response)
          .map((e) => ChecklistModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(checklists);
    } catch (e) {
      print('Supabase Error (Checklist.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<ChecklistModel?> add(ChecklistModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Checklist.add): $e');
      return null;
    }
  }

  @override
  Future<ChecklistModel?> update(ChecklistModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Checklist.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(ChecklistModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Checklist.delete): $e');
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
      final checklists =
          data.map((e) => ChecklistModel.fromSupabaseMap(e)).toList();
      checklists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(checklists);
    });
  }
}
