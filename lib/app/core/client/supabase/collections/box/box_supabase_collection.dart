import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/box/box_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoxSupabaseCollection extends BoxCollection {
  static final BoxSupabaseCollection _instance = BoxSupabaseCollection._();
  BoxSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory BoxSupabaseCollection() => _instance;

  @override
  final String tableName = 'boxes';

  @override
  List<BoxModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final boxes = List<Map<String, dynamic>>.from(response)
          .map((e) => BoxModel.fromSupabaseMap(e))
          .toList();
      boxes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(boxes);
    } catch (e) {
      print('Supabase Error (Box.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  @override
  Future<BoxModel?> add(BoxModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      // fetch() removido — o Realtime já dispara atualização automaticamente
      return model;
    } catch (e) {
      print('Supabase Error (Box.add): $e');
      rethrow;
    }
  }

  @override
  Future<BoxModel?> update(BoxModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
      return model;
    } catch (e) {
      print('Supabase Error (Box.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(BoxModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      print('Supabase Error (Box.delete): $e');
    }
  }

  bool _isListen = false;
  @override
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      final boxes = data.map((e) => BoxModel.fromSupabaseMap(e)).toList();
      boxes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(boxes);
    });
  }
}
