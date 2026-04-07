import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';

import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:flutter/material.dart';

class AutomatizacaoPage extends StatefulWidget {
  const AutomatizacaoPage({super.key});

  @override
  State<AutomatizacaoPage> createState() => _AutomatizacaoPageState();
}

class _AutomatizacaoPageState extends State<AutomatizacaoPage> {
  late AutomatizacaoModel model;
  bool isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    setWebTitle('Automações de Processos');
    model = FirestoreClient.automatizacao.data.copyWith();
    super.initState();
  }

  void _onSave() async {
    setState(() => isSaving = true);
    await FirestoreClient.automatizacao.update(model);
    NotificationService.showPositive(
      'Automação Atualizada',
      'As regras de automação foram aplicadas no banco de dados com sucesso.',
    );
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text(
          'Automações de Etapas',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamOut<AutomatizacaoModel>(
        stream: FirestoreClient.automatizacao.dataStream.listen,
        builder: (_, data) {
          if (!_isInitialized && data != AutomatizacaoModel.empty) {
            model = data.copyWith();
            _isInitialized = true;
          }
          // Mantendo os steps sempre fresquinhos (caso tenham adicionado/removido um)
          final steps = FirestoreClient.steps.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Regras de Transição de Status'),
                const SizedBox(height: 16),
                
                _buildSingleStepRule(
                  'Criação de Pedido',
                  'Ao criar um pedido, anexar a etapa:',
                  model.criacaoPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      criacaoPedido: model.criacaoPedido.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Produto Separado',
                  'Ao marcar Produto como Separado:',
                  model.produtoPedidoSeparado.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      produtoPedidoSeparado: model.produtoPedidoSeparado.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Produzindo CD (Corte e Dobra)',
                  'Muda status para Produzindo CD:',
                  model.produzindoCDPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      produzindoCDPedido: model.produzindoCDPedido.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Pronto CD',
                  'Ao finalizar a produção na etapa de CD:',
                  model.prontoCDPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      prontoCDPedido: model.prontoCDPedido.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Aguardando Armação',
                  'Enviado/Aguardando iniciar Armação:',
                  model.aguardandoArmacaoPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      aguardandoArmacaoPedido: model.aguardandoArmacaoPedido.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Produzindo Armação',
                  'Muda status para Produzindo Armação:',
                  model.produzindoArmacaoPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      produzindoArmacaoPedido: model.produzindoArmacaoPedido.copyWith(step: step))),
                ),

                _buildSingleStepRule(
                  'Pronto Armação',
                  'Ao finalizar a produção de Armação:',
                  model.prontoArmacaoPedido.step,
                  steps,
                  (step) => setState(() => model = model.copyWith(
                      prontoArmacaoPedido: model.prontoArmacaoPedido.copyWith(step: step))),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('Regras de Filtro / Ocultação'),
                const SizedBox(height: 16),

                _buildMultiStepRule(
                  'Não Mostrar no Calendário',
                  'Selecionar etapas onde o Pedido não deve constar na visualização de calendário:',
                  model.naoMostrarNoCalendario.steps ?? [],
                  steps,
                  () => setState(() => model = model.copyWith(
                      naoMostrarNoCalendario: model.naoMostrarNoCalendario.copyWith(steps: List.from(model.naoMostrarNoCalendario.steps ?? [])))),
                ),

                _buildMultiStepRule(
                  'Remover Lista Prioridade',
                  'Selecionar etapas a serem ocultadas da lista de priorização:',
                  model.removerListaPrioridade.steps ?? [],
                  steps,
                  () => setState(() => model = model.copyWith(
                      removerListaPrioridade: model.removerListaPrioridade.copyWith(steps: List.from(model.removerListaPrioridade.steps ?? [])))),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Salvar Automações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.primaryMain,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divisor(),
      ],
    );
  }

  Widget _buildSingleStepRule(
    String targetName,
    String description,
    StepModel? currentStep,
    List<StepModel> allSteps,
    void Function(StepModel) onChanged,
  ) {
    // Busca o step por ID na lista atual para garantir que seja a mesma instância (referência)
    // Sem isso, o operator == por referência do StepModel nunca dá match no dropdown
    StepModel? selected = currentStep != null
        ? allSteps.firstWhere(
            (e) => e.id == currentStep.id,
            orElse: () => currentStep,
          )
        : null;
    if (selected != null && !allSteps.any((e) => e.id == selected!.id)) {
      selected = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.neutralLight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(targetName, style: AppCss.largeBold.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: AppCss.smallRegular.copyWith(color: AppColors.neutralDark)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: AppDropDown<StepModel?>(
              item: selected,
              itens: allSteps,
              itemLabel: (v) => v?.name ?? 'Selecione',
              required: false,
              onSelect: (step) {
                if (step != null) onChanged(step);
              },
              hint: 'Selecione a etapa',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiStepRule(
    String targetName,
    String description,
    List<StepModel> currentSteps,
    List<StepModel> allSteps,
    void Function() onChanged,
  ) {
    currentSteps.removeWhere((st) => !allSteps.any((s) => s.id == st.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.neutralLight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(targetName, style: AppCss.largeBold.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: AppCss.smallRegular.copyWith(color: AppColors.neutralDark)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: AppDropDownList<StepModel>(
              label: '',
              addeds: currentSteps,
              itens: allSteps,
              itemLabel: (v) => v.name,
              required: false,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
