import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_item_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';

final automatizacaoCtrl = AutomatizacaoController();

class AutomatizacaoController {
  static final AutomatizacaoController _instance = AutomatizacaoController._();

  AutomatizacaoController._();

  factory AutomatizacaoController() => _instance;

  Future<void> onSetStepByPedidoStatus(List<PedidoModel> pedidos) async {
    for (PedidoModel pedido in pedidos) {
      AutomatizacaoItemModel? item;
      switch (pedido.status) {
        case PedidoStatus.aguardandoProducaoCD:
          item = automatizacaoConfig.produtoPedidoSeparado;
          break;
        case PedidoStatus.produzindoCD:
          item = automatizacaoConfig.produzindoCDPedido;
          break;
        case PedidoStatus.aguardandoProducaoCDA:
          item = automatizacaoConfig.aguardandoArmacaoPedido;
          break;
        case PedidoStatus.produzindoCDA:
          item = automatizacaoConfig.produzindoArmacaoPedido;
          break;
        case PedidoStatus.pronto:
          switch (pedido.tipo) {
            case PedidoTipo.cd:
              item = automatizacaoConfig.prontoCDPedido;
              break;
            case PedidoTipo.cda:
              item = automatizacaoConfig.prontoArmacaoPedido;
            default:
          }
          break;
        default:
      }

      if (item != null) {
        List<StepModel> stepsToAdd = [];
        if (item.steps != null && item.steps!.isNotEmpty) {
          stepsToAdd = item.steps!;
        } else if (item.step != null) {
          stepsToAdd = [item.step!];
        }

        for (var step in stepsToAdd) {
          if (pedido.step.index < step.index) {
            final stepById = FirestoreClient.steps.getById(step.id);
            pedido.steps.add(PedidoStepModel.create(stepById));
            pedidoCtrl.onAddHistory(
              pedido: pedido,
              data: stepById,
              type: PedidoHistoryType.step,
              action: PedidoHistoryAction.update,
              isFromAutomatizacao: true,
            );
          }
        }
        if (stepsToAdd.isNotEmpty) {
          await FirestoreClient.pedidos.update(pedido);
        }
      }
    }
  }
}
