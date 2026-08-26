import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_bitola_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class PedidoBitolaSupabaseCollection extends PedidoBitolaCollection {
  static final PedidoBitolaSupabaseCollection _instance =
      PedidoBitolaSupabaseCollection._();
  PedidoBitolaSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory PedidoBitolaSupabaseCollection() => _instance;

  final String tableName = 'pedido_bitolas';

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final produtos = List<Map<String, dynamic>>.from(response)
          .map((e) => PedidoBitolaModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(produtos);
    } catch (e) {
      print('Supabase Error (PedidoProduto.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    await start(lock: false, options: options);
  }

  @override
  Future<PedidoBitolaModel?> add(PedidoBitolaModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap(model.pedidoId));
      return model;
    } catch (e) {
      print('Supabase Error (PedidoProduto.add): $e');
      return null;
    }
  }

  bool _isListen = false;
  @override
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .channel('pedido_bitolas_realtime')
        .onPostgresChanges(
          event: sf.PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          callback: (payload) {
            if (payload.eventType == sf.PostgresChangeEvent.update) {
              final newRecord = payload.newRecord;
              final id = newRecord['id']?.toString();
              if (id != null) {
                final currentList = List<PedidoBitolaModel>.from(data);
                final idx = currentList.indexWhere((e) => e.id == id);
                if (idx != -1) {
                  currentList[idx] =
                      PedidoBitolaModel.fromSupabaseMap(newRecord);
                  dataStream.add(currentList);
                  return;
                }
              }
            } else if (payload.eventType == sf.PostgresChangeEvent.insert) {
              final newRecord = payload.newRecord;
              final id = newRecord['id']?.toString();
              if (id != null) {
                final currentList = List<PedidoBitolaModel>.from(data);
                if (!currentList.any((e) => e.id == id)) {
                  currentList
                      .add(PedidoBitolaModel.fromSupabaseMap(newRecord));
                  dataStream.add(currentList);
                }
                return;
              }
            } else if (payload.eventType == sf.PostgresChangeEvent.delete) {
              final oldRecord = payload.oldRecord;
              final id = oldRecord['id']?.toString();
              if (id != null) {
                final currentList = List<PedidoBitolaModel>.from(data);
                currentList.removeWhere((e) => e.id == id);
                dataStream.add(currentList);
                return;
              }
            }
            // Fallback: só se o tratamento cirúrgico falhar
            fetch();
          },
        )
        .subscribe();
  }

  Future<List<PedidoBitolaModel>> getByPedidoId(String pedidoId) async {
    final response = await SupabaseService.client
        .from(tableName)
        .select()
        .eq('pedido_id', pedidoId);
    return response.map((e) => PedidoBitolaModel.fromSupabaseMap(e)).toList();
  }
}
