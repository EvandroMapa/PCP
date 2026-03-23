import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_collection.dart';

class ClienteSupabaseCollection extends ClienteCollection {
  static final ClienteSupabaseCollection _instance = ClienteSupabaseCollection._();
  ClienteSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory ClienteSupabaseCollection() => _instance;

  @override
  final String tableName = 'clientes';
  final String obraTableName = 'obras';

  @override
  List<ClienteModel> get data => dataStream.value;

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
      final clientesRaw = await SupabaseService.client.from(tableName).select();
      final obrasRaw = await SupabaseService.client.from(obraTableName).select();

      final obrasByClienteId = <String, List<Map<String, dynamic>>>{};
      for (final obra in List<Map<String, dynamic>>.from(obrasRaw)) {
        final clienteId = obra['cliente_id'] as String?;
        if (clienteId != null) {
          obrasByClienteId.putIfAbsent(clienteId, () => []).add(obra);
        }
      }

      final clientes = List<Map<String, dynamic>>.from(clientesRaw).map((c) {
        final obras = obrasByClienteId[c['id']] ?? [];
        return ClienteModel.fromSupabaseMap(c, obras);
      }).toList();

      dataStream.add(clientes);
    } catch (e) {
      print('Supabase Error (Cliente.start): $e');
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
    // Basic implementation for now, listening to main table
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((_) => start(lock: false));
  }

  ClienteModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => ClienteModel.empty());

  @override
  Future<ClienteModel?> add(ClienteModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Cliente.add): $e');
      return null;
    }
  }

  @override
  Future<ClienteModel?> update(ClienteModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Cliente.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(ClienteModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Cliente.delete): $e');
    }
  }
}
