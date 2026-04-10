import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:aco_plus/app/core/client/firestore/collections/usuario/usuario_collection.dart';

class UsuarioSupabaseCollection extends UsuarioCollection {
  static final UsuarioSupabaseCollection _instance = UsuarioSupabaseCollection._();
  UsuarioSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory UsuarioSupabaseCollection() => _instance;

  Timer? _streamDebounce;

  @override
  final String tableName = 'usuarios';

  @override
  List<UsuarioModel> get data => dataStream.value;

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
      final response = await SupabaseService.client.from(tableName).select('*, perfis(*)');
      final usuarios = List<Map<String, dynamic>>.from(response)
          .map((e) => UsuarioModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(usuarios);
    } catch (e) {
      print('Supabase Error (Usuario.start): $e');
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
          _streamDebounce?.cancel();
          _streamDebounce = Timer(const Duration(milliseconds: 500), () {
            start(lock: false);
          });
        });
  }

  UsuarioModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => UsuarioModel.empty());

  @override
  Future<UsuarioModel?> add(UsuarioModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Usuario.add): $e');
      return null;
    }
  }

  @override
  Future<UsuarioModel?> update(UsuarioModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Usuario.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(UsuarioModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Usuario.delete): $e');
    }
  }
}
