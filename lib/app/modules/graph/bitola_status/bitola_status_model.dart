import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';

class BitolaStatusGraphModel {
  final PedidoBitolaStatus status;
  final BitolaModel produto;
  double qtde;
  BitolaStatusGraphModel({
    required this.status,
    required this.produto,
    required this.qtde,
  });
}
