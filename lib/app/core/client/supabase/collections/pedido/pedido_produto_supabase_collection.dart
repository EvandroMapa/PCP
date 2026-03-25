import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/supabase_collection.dart';

class PedidoProdutoSupabaseCollection extends SupabaseCollection<PedidoProdutoModel> {
  PedidoProdutoSupabaseCollection() : super('pedido_produtos');

  @override
  PedidoProdutoModel fromSupabaseMap(Map<String, dynamic> map) {
    return PedidoProdutoModel.fromSupabaseMap(map);
  }

  @override
  Map<String, dynamic> toSupabaseMap(PedidoProdutoModel model) {
    return model.toSupabaseMap(model.pedidoId);
  }

  Future<List<PedidoProdutoModel>> getByPedidoId(String pedidoId) async {
    final response = await supabase.from(tableName).select().eq('pedido_id', pedidoId);
    return response.map((e) => fromSupabaseMap(e)).toList();
  }
}
