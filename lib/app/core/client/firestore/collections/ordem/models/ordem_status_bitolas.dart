import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';

class OrdemStatusProdutos {
  final PedidoBitolaStatus status;
  final List<PedidoBitolaModel> produtos;

  OrdemStatusProdutos({required this.status, required this.produtos});

  factory OrdemStatusProdutos.fromJson(Map<String, dynamic> json) {
    return OrdemStatusProdutos(
      status: PedidoBitolaStatus.values.byName(json['status']),
      produtos: List<PedidoBitolaModel>.from(
        (json['produtos'] ?? [])
            .map((e) => PedidoBitolaModel.fromMap(e))
            .toList(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'produtos': produtos.map((e) => e.toMap()).toList(),
    };
  }
}
