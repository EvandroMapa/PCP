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
              break;
          }
          break;
        // arquivado não é um status válido do enum
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

  Future<void> onCheckFinalizacaoArmacao(PedidoModel pedido) async {
    // 1. Validar se é CDA
    log('onCheckFinalizacaoArmacao: Pedido: ${pedido.localizador}, Tipo: ${pedido.tipo.name}');
    if (pedido.tipo != PedidoTipo.cda) return;

    // 2. Validar se a etapa atual exibe armação (é uma etapa de produção de armador)
    log('onCheckFinalizacaoArmacao: Etapa atual: ${pedido.step.name}, isExibirArmacao: ${pedido.step.isExibirArmacao}');
    if (!pedido.step.isExibirArmacao) return;

    // 3. Validar se tem elementos e se todos estão prontos
    final resumo = pedido.armacaoResumo;
    final total = int.tryParse(resumo['total_qtd']?.toString() ?? '0') ?? 0;
    final pronto = int.tryParse(resumo['details']?['pronto']?['qtd']?.toString() ?? '0') ?? 0;
    
    log('onCheckFinalizacaoArmacao: Pedido ${pedido.id} - Total: $total, Pronto: $pronto');

    if (total == 0) return;

    // Se todos estiverem prontos
    if (pronto >= total) {
      final config = automatizacaoConfig.finalizacaoArmacaoPedido;
      final targetStep = config.step;
      
      log('onCheckFinalizacaoArmacao: Condição de 100% atingida. Config Target: ${targetStep?.name}');

      if (targetStep == null) {
        log('onCheckFinalizacaoArmacao: AVISO - Nenhuma etapa de destino configurada para Finalização de Armação.');
        return;
      }

      log('onCheckFinalizacaoArmacao: Comparando índices - Atual: ${pedido.step.index}, Destino: ${targetStep.index}');

      // Só move se tiver etapa configurada e se não for mover para "trás" ou para a mesma etapa
      if (pedido.step.index < targetStep.index) {
        log('onCheckFinalizacaoArmacao: EXECUTANDO MOVIMENTAÇÃO para ${targetStep.name}');
        final stepById = FirestoreClient.steps.getById(targetStep.id);
        pedido.steps.add(PedidoStepModel.create(stepById));
        
        // Registrar histórico
        pedidoCtrl.onAddHistory(
          pedido: pedido,
          data: stepById,
          type: PedidoHistoryType.step,
          action: PedidoHistoryAction.update,
          isFromAutomatizacao: true,
        );

        await FirestoreClient.pedidos.update(pedido);
        log('onCheckFinalizacaoArmacao: Pedido atualizado com sucesso.');
      } else {
        log('onCheckFinalizacaoArmacao: Movimentação ignorada (índice destino não é maior que o atual).');
      }
    }
  }
}
