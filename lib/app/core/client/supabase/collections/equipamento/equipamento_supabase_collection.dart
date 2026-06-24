import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class EquipamentoSupabaseCollection extends EquipamentoCollection {
  static final EquipamentoSupabaseCollection _instance =
      EquipamentoSupabaseCollection._();
  EquipamentoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory EquipamentoSupabaseCollection() => _instance;

  @override
  final String name = 'equipamentos';

  @override
  List<EquipamentoModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final items = List<Map<String, dynamic>>.from(response)
          .map((e) => EquipamentoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(items);
    } catch (e) {
      log('Supabase Error (Equipamento.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<EquipamentoModel?> add(EquipamentoModel model) async {
    await SupabaseService.client.from(name).insert(model.toSupabaseMap());
    return model;
  }

  @override
  Future<EquipamentoModel?> update(EquipamentoModel model) async {
    await SupabaseService.client
        .from(name)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    return model;
  }

  @override
  Future<void> delete(EquipamentoModel model) async {
    await SupabaseService.client.from(name).delete().eq('id', model.id);
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
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      final items =
          data.map((e) => EquipamentoModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    });
  }
}
