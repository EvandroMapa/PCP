import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/models/pedido_box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/pedido_box_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class PedidoBoxSupabaseCollection extends PedidoBoxCollection {
  static final PedidoBoxSupabaseCollection _instance =
      PedidoBoxSupabaseCollection._();
  PedidoBoxSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory PedidoBoxSupabaseCollection() => _instance;

  @override
  final String tableName = 'pedido_boxes';

  @override
  List<PedidoBoxModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    try {
      final response =
          await SupabaseService.client.from(tableName).select();
      final items = List<Map<String, dynamic>>.from(response)
          .map((e) => PedidoBoxModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(items);
    } catch (e) {
      print('Supabase Error (PedidoBox.start): $e');
    }
  }

  @override
  Future<void> fetch() async {
    _isStarted = false;
    await start();
    _isStarted = true;
  }

  @override
  Future<PedidoBoxModel?> add(PedidoBoxModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (PedidoBox.add): $e');
      return null;
    }
  }

  @override
  Future<void> delete(PedidoBoxModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .delete()
          .eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (PedidoBox.delete): $e');
    }
  }

  @override
  Future<void> deleteByPedidoId(String pedidoId) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .delete()
          .eq('pedido_id', pedidoId);
      await fetch();
    } catch (e) {
      print('Supabase Error (PedidoBox.deleteByPedidoId): $e');
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
      final items =
          data.map((e) => PedidoBoxModel.fromSupabaseMap(e)).toList();
      dataStream.add(items);
    });
  }
}
