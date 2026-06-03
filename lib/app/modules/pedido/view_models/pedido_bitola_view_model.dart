import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/extensions/text_controller_ext.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoBitolaCreateModel {
  final String id;
  BitolaModel? produtoModel;
  TextController produtoEC = TextController();
  TextController qtde = TextController();
  List<PedidoBitolaStatusModel> statusess = [];
  final bool isEnabled;
  final double? qtdeDisponivel;
  double? _qtdeOriginal;
  bool isSelected = true;

  bool get isEnable => produtoModel != null && qtde.doubleValue > 0;

  late bool isEdit;

  PedidoBitolaCreateModel(
      {this.isEnabled = true, this.qtdeDisponivel, this.isSelected = true})
      : id = HashService.get,
        isEdit = false {
    statusess = [
      PedidoBitolaStatusModel(
        id: HashService.get,
        status: PedidoBitolaStatus.separado,
        createdAt: DateTime.now(),
      ),
    ];
  }

  PedidoBitolaCreateModel.edit(PedidoBitolaModel produto,
      {this.isEnabled = true, this.qtdeDisponivel, this.isSelected = true})
      : id = produto.id,
        isEdit = true {
    produtoModel = produto.produto;
    qtde.text = produto.qtde.toString();
    _qtdeOriginal = produto.qtdeOriginal;
    statusess = produto.statusess.toList();
  }

  PedidoBitolaModel toPedidoBitolaModel(
    String pedidoId,
    ClienteModel cliente,
    ObraModel obra,
  ) =>
      PedidoBitolaModel(
        id: id,
        pedidoId: pedidoId,
        produto: produtoModel!,
        qtde: qtde.doubleValue,
        qtdeOriginal: _qtdeOriginal ?? qtde.doubleValue,
        statusess: statusess.map((e) => e.copyWith()).toList(),
        clienteId: cliente.id,
        obraId: obra.id,
      );
}
