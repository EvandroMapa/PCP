// import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
// import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
// import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
// import 'package:aco_plus/app/core/models/text_controller.dart';

// import 'package:flutter_masked_text2/flutter_masked_text2.dart';

// class PedidoBitolaCreateModel {
//   final String id;
//   BitolaModel? produtoModel;
//   MoneyMaskedTextController qtde = MoneyMaskedTextController(rightSymbol: ' Kg');

//   bool get isEnable => produtoModel != null && qtde.numberValue > 0;

//   late bool isEdit;

//   PedidoBitolaCreateModel()
//       : id = HashService.get,
//         isEdit = false;

//   PedidoBitolaCreateModel.edit(PedidoBitolaModel produto)
//       : id = produto.id,
//         isEdit = true;

//   PedidoBitolaModel toPedidoBitolaModel() =>
//       PedidoBitolaModel(id: id, produto: produtoModel!, qtde: qtde.numberValue, statusess: [
//         PedidoBitolaStatusModel(
//             id: HashService.get,
//             status: PedidoBitolaStatus.aguardandoProducao,
//             createdAt: DateTime.now())
//       ]);
// }
