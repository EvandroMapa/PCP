import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/modules/step/step_controller.dart';
import 'package:aco_plus/app/modules/step/step_view_model.dart';
import 'package:aco_plus/app/modules/step/ui/step_create_page.dart';
import 'package:flutter/material.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';

class StepsPage extends StatefulWidget {
  const StepsPage({super.key});

  @override
  State<StepsPage> createState() => _StepsPageState();
}

class _StepsPageState extends State<StepsPage> {
  @override
  void initState() {
    setWebTitle('Etapas');
    stepCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Etapas',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          CadastroBotaoNovo('Nova etapa',
              onTap: () => push(context, const StepCreatePage())),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<StepModel>>(
        stream: FirestoreClient.steps.dataStream.listen,
        builder: (_, todas) => StreamOut<StepUtils>(
          stream: stepCtrl.utilsStream.listen,
          builder: (_, utils) {
            final steps =
                stepCtrl.getStepesFiltered(utils.search.text, todas).toList();
            return Container(
              color: AppColors.neutralLightest,
              child: Column(
                children: [
                  CadastroBusca(
                    hint: 'Buscar etapa',
                    controller: utils.search,
                    contador: steps.length == 1
                        ? '1 etapa'
                        : '${steps.length} etapas',
                    onChanged: () => stepCtrl.utilsStream.update(),
                  ),
                  Expanded(
                    child: steps.isEmpty
                        ? const EmptyData()
                        : RefreshIndicator(
                            onRefresh: () async =>
                                FirestoreClient.steps.fetch(),
                            // A ordem das etapas é definida arrastando
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.only(bottom: 32),
                              buildDefaultDragHandles: false,
                              itemCount: steps.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex = newIndex - 1;
                                }
                                final step = steps.removeAt(oldIndex);
                                steps.insert(newIndex, step);
                                for (var i = 0; i < steps.length; i++) {
                                  steps[i].index = i;
                                  FirestoreClient.steps.dataStream.update();
                                  FirestoreClient.steps.update(steps[i]);
                                }
                              },
                              itemBuilder: (_, i) =>
                                  _itemStepWidget(steps[i], i),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _itemStepWidget(StepModel step, int index) {
    final quemMove = step.moveRoles.isEmpty
        ? 'Todos'
        : step.moveRoles.map((id) {
            final tipo = AppSupabaseClient.usuarioTipos.data
                .where((t) => t.id == id)
                .firstOrNull;
            return tipo?.nome ?? id;
          }).join(', ');
    return KeyedSubtree(
      key: ValueKey(step.id),
      child: CadastroLinha(
        onTap: () => push(context, StepCreatePage(step: step)),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Arraste para mudar a ordem',
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.drag_indicator,
                      size: 20, color: AppColors.neutralMedium),
                ),
              ),
            ),
            CadastroCor(step.color),
          ],
        ),
        titulo: step.name,
        selos: [
          if (step.isDefault) const CadastroSelo('Padrão'),
          if (step.isPermiteProducao) const CadastroSelo('Permite produção'),
          if (step.isExibirArmacao) const CadastroSelo('Exibe armação'),
          if (step.isMarcarEntregue)
            CadastroSelo('Marca entregue', cor: AppColors.statusPronto),
        ],
        pares: [('Quem move', quemMove)],
        trailing: CadastroMenu([
          CadastroAcao(Icons.edit_outlined, 'Editar etapa',
              () => push(context, StepCreatePage(step: step))),
          CadastroAcao(Icons.delete_outline, 'Excluir etapa',
              () => stepCtrl.onDelete(context, step),
              destrutiva: true),
        ]),
      ),
    );
  }
}
