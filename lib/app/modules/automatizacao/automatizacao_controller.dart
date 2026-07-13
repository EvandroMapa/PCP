import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_item_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';

final automatizacaoCtrl = AutomatizacaoController();

class AutomatizacaoController {
  static final AutomatizacaoController _instance = AutomatizacaoController._();

  AutomatizacaoController._();

  factory AutomatizacaoController() => _instance;

  Future<void> onSetStepByPedidoStatus(List<PedidoModel> pedidos) async {
    for (PedidoModel pedido in pedidos) {
      // Pedidos Mestre não devem ser movidos pela automação — apenas parciais e pedidos normais
      if (pedido.pedidosFilhos.isNotEmpty) continue;

      try {
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
              case PedidoTipo.outros:
                // Sem automação de etapa para pedidos do tipo 'Outros'
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

          // Flag real: só salva se pelo menos um step foi de fato adicionado
          var algumStepAdicionado = false;
          for (var step in stepsToAdd) {
            if (pedido.step.index < step.index) {
              final stepById = FirestoreClient.steps.getById(step.id);
              pedido.steps.add(PedidoStepModel.create(stepById));

              // Registrar histórico
              pedidoCtrl.onAddHistory(
                pedido: pedido,
                data: stepById,
                type: PedidoHistoryType.step,
                action: PedidoHistoryAction.update,
                isFromAutomatizacao: true,
              );
              algumStepAdicionado = true;
            }
          }

          if (algumStepAdicionado) {
            // IMPORTANTE: usar BackendClient (Supabase), não FirestoreClient (Firestore),
            // para evitar que o estado antigo do Firestore sobrescreva o Supabase.
            await BackendClient.pedidos.update(pedido);
            log('[Automação] Pedido ${pedido.localizador} movido para → ${pedido.step.name}');
          }
        }
      } catch (e, stack) {
        log('[Automação] ERRO ao processar pedido ${pedido.localizador}: $e\n$stack');
      }
    }
  }

  StepModel? checkFinalizacaoArmacaoTargetStep(PedidoModel pedido) {
    // 1. Validar se é CDA
    if (pedido.tipo != PedidoTipo.cda) return null;

    // 2. Validar se a etapa atual exibe armação (é uma etapa de produção de armador)
    if (!pedido.step.isExibirArmacao) return null;

    // 3. Validar se tem elementos e se todos estão prontos
    final resumo = pedido.armacaoResumo;
    final total = int.tryParse(resumo['total_qtd']?.toString() ?? '0') ?? 0;
    final pronto =
        int.tryParse(resumo['details']?['pronto']?['qtd']?.toString() ?? '0') ??
            0;

    if (total == 0) {
      // Distingue "sem elementos cadastrados" de possível dado corrompido
      log('[Automação] checkFinalizacaoArmacao: pedido ${pedido.localizador} sem elementos (total=0) — nenhuma ação.');
      return null;
    }
    if (pronto < total) return null;

    // Se todos estiverem prontos
    final config = automatizacaoConfig.finalizacaoArmacaoPedido;
    final targetStep = config.step;

    if (targetStep == null) return null;

    // Só sugere se não for mover para "trás" ou para a mesma etapa
    if (pedido.step.index < targetStep.index) {
      return FirestoreClient.steps.getById(targetStep.id);
    }

    return null;
  }

  Future<void> executeFinalizacaoArmacao(
      PedidoModel pedido, StepModel targetStep) async {
    log('executeFinalizacaoArmacao: EXECUTANDO MOVIMENTAÇÃO para ${targetStep.name}');
    pedido.steps.add(PedidoStepModel.create(targetStep));

    // Registrar histórico
    pedidoCtrl.onAddHistory(
      pedido: pedido,
      data: targetStep,
      type: PedidoHistoryType.step,
      action: PedidoHistoryAction.update,
      isFromAutomatizacao: true,
    );

    // IMPORTANTE: usar BackendClient (Supabase), não FirestoreClient.
    await BackendClient.pedidos.update(pedido);
    log('executeFinalizacaoArmacao: Pedido atualizado com sucesso.');
  }
}
