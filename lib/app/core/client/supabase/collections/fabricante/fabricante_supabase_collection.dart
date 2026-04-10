import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class FabricanteSupabaseCollection extends FabricanteCollection {
  static final FabricanteSupabaseCollection _instance = FabricanteSupabaseCollection._();
  FabricanteSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory FabricanteSupabaseCollection() => _instance;

  @override
  final String name = 'fabricantes';

  @override
  List<FabricanteModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final fabricantes = List<Map<String, dynamic>>.from(response)
          .map((e) => FabricanteModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(fabricantes);
    } catch (e) {
      log('Supabase Error (Fabricante.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<FabricanteModel?> add(FabricanteModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Fabricante.add): $e');
      return null;
    }
  }

  @override
  Future<FabricanteModel?> update(FabricanteModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      log('Supabase Error (Fabricante.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(FabricanteModel model) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      log('Supabase Error (Fabricante.delete): $e');
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
        .from(name)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          final fabricantes = data.map((e) => FabricanteModel.fromSupabaseMap(e)).toList();
          dataStream.add(fabricantes);
        });
  }
}
