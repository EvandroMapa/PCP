import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class PedidoTrackerTimelineWidget extends StatelessWidget {
  final PedidoModel pedido;
  const PedidoTrackerTimelineWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Obter os IDs das etapas configuradas
    final selectedStepIds = PreferencesService.stepsAcompanhamento.value;
    
    // 2. Obter as Etapas reais do Firestore para ter os nomes e índices
    final allSteps = FirestoreClient.steps.data;
    final timelineSteps = allSteps
        .where((s) => selectedStepIds.contains(s.id))
        .toList();
    timelineSteps.sort((a, b) => a.index.compareTo(b.index));

    // 3. Cruzar com o histórico do pedido
    // Queremos saber QUANDO o pedido entrou em cada uma das etapas selecionadas
    final historySteps = pedido.histories
        .where((h) => h.type == PedidoHistoryType.step)
        .toList();

    // Montar a lista final de "Eventos da Timeline"
    final List<_TimelineNode> nodes = [];

    // Nó Inicial Obrigatório: Pedido Recebido
    nodes.add(_TimelineNode(
      title: 'Pedido Recebido',
      subtitle: pedido.createdAt.textHour(),
      isCompleted: true,
      isCurrent: pedido.histories.isEmpty,
      icon: Icons.assignment_turned_in_outlined,
    ));

    for (var step in timelineSteps) {
      // Verifica se existe registro no histórico para esta etapa específica
      final historyMatch = historySteps.firstWhereOrNull((h) {
        final stepData = h.data as StepModel;
        return stepData.id == step.id;
      });

      final bool isPastOrCurrent = pedido.step.id == step.id || 
                                  historyMatch != null ||
                                  _isStepPast(pedido.step, step, allSteps);

      nodes.add(_TimelineNode(
        title: step.name,
        subtitle: historyMatch?.createdAt.textHour() ?? (isPastOrCurrent ? 'Concluído' : 'Aguardando'),
        isCompleted: isPastOrCurrent && pedido.step.id != step.id,
        isCurrent: pedido.step.id == step.id,
        icon: _getStepIcon(step.name),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: List.generate(nodes.length, (index) {
          final node = nodes[index];
          final isLast = index == nodes.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna da Linha e Dot
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: node.isCurrent 
                            ? AppColors.primaryMain 
                            : (node.isCompleted ? AppColors.primaryMain.withValues(alpha: 0.2) : Colors.grey[200]!),
                        shape: BoxShape.circle,
                        border: node.isCurrent 
                            ? Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3), width: 4)
                            : null,
                      ),
                      child: Icon(
                        node.isCompleted ? Icons.check : node.icon,
                        size: 14,
                        color: node.isCurrent ? Colors.white : (node.isCompleted ? AppColors.primaryMain : Colors.grey[400]!),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: node.isCompleted ? AppColors.primaryMain : Colors.grey[200],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Coluna do Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title.toUpperCase(),
                        style: AppCss.smallBold.setSize(13).setColor(
                          node.isCurrent ? AppColors.primaryMain : (node.isCompleted ? AppColors.black : Colors.grey[500]!)
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.subtitle,
                        style: AppCss.minimumRegular.setSize(11).setColor(Colors.grey[600]!),
                      ),
                      if (!isLast) const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _isStepPast(StepModel currentStep, StepModel targetStep, List<StepModel> allSteps) {
    return currentStep.index > targetStep.index;
  }

  IconData _getStepIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('produ')) return Icons.precision_manufacturing_outlined;
    if (name.contains('cd')) return Icons.inventory_2_outlined;
    if (name.contains('expe') || name.contains('entr')) return Icons.local_shipping_outlined;
    return Icons.radio_button_checked;
  }
}

class _TimelineNode {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final IconData icon;

  _TimelineNode({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.icon,
  });
}
