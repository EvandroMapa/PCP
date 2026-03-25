import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_produto_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoProdutoSupabaseCollection extends PedidoProdutoCollection {
  static final PedidoProdutoSupabaseCollection _instance = PedidoProdutoSupabaseCollection._();
  PedidoProdutoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory PedidoProdutoSupabaseCollection() => _instance;

  final String tableName = 'pedido_produtos';

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final produtos = List<Map<String, dynamic>>.from(response)
          .map((e) => PedidoProdutoModel.fromSupabaseMap(e))
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
  Future<PedidoProdutoModel?> add(PedidoProdutoModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap(model.pedidoId));
      return model;
    } catch (e) {
      print('Supabase Error (PedidoProduto.add): $e');
      return null;
    }
  }

  @override
  Future<void> listen() async {
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          final produtos = data.map((e) => PedidoProdutoModel.fromSupabaseMap(e)).toList();
          dataStream.add(produtos);
        });
  }

  Future<List<PedidoProdutoModel>> getByPedidoId(String pedidoId) async {
    final response = await SupabaseService.client.from(tableName).select().eq('pedido_id', pedidoId);
    return response.map((e) => PedidoProdutoModel.fromSupabaseMap(e)).toList();
  }
}
