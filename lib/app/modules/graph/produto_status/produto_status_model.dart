import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';

class ProdutoStatusGraphModel {
  final PedidoProdutoStatus status;
  final ProdutoModel produto;
  double qtde;
  ProdutoStatusGraphModel({
    required this.status,
    required this.produto,
    required this.qtde,
  });
}
