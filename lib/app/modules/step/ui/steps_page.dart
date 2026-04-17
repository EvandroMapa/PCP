import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/modules/step/step_controller.dart';
import 'package:aco_plus/app/modules/step/step_view_model.dart';
import 'package:aco_plus/app/modules/step/ui/step_create_page.dart';
import 'package:flutter/material.dart';

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
          IconButton(
            onPressed: () => push(context, const StepCreatePage()),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<StepModel>>(
        stream: FirestoreClient.steps.dataStream.listen,
        builder: (_, __) => StreamOut<StepUtils>(
          stream: stepCtrl.utilsStream.listen,
          builder: (_, utils) {
            final steps =
                stepCtrl.getStepesFiltered(utils.search.text, __).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppField(
                    hint: 'Pesquisar',
                    controller: utils.search,
                    suffixIcon: Icons.search,
                    onChanged: (_) => stepCtrl.utilsStream.update(),
                  ),
                ),
                Expanded(
                  child: steps.isEmpty
                      ? const EmptyData()
                      : RefreshIndicator(
                          onRefresh: () async => FirestoreClient.steps.fetch(),
                          child: ReorderableListView.builder(
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
                            itemBuilder: (_, i) => _itemStepWidget(steps[i], i),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemStepWidget(StepModel step, int index) {
    return Container(
      key: ValueKey(step.id),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () => push(context, StepCreatePage(step: step)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child:
                    Icon(Icons.drag_handle, color: Colors.grey[400], size: 24),
              ),
            ),
            const W(8),
            Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: step.color,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.neutralMedium),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(step.name, style: AppCss.mediumBold),
            const W(4),
            if (step.isDefault)
              Container(
                margin: const EdgeInsets.only(left: 3),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Padrão',
                  style:
                      AppCss.minimumBold.setColor(AppColors.white).setSize(11),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movido por: ${step.moveRoles.isEmpty ? 'Todos' : step.moveRoles.map((id) {
                  final tipo = AppSupabaseClient.usuarioTipos.data
                      .where((t) => t.id == id)
                      .firstOrNull;
                  return tipo?.nome ?? id;
                }).join(', ')}',
              style: AppCss.minimumRegular.setSize(12),
            ),
            const H(2),
            Text(
              'Criado em ${step.createdAt.textHour()}',
              style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon:
                  Icon(Icons.edit_outlined, color: Colors.blue[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => push(context, StepCreatePage(step: step)),
            ),
            const W(6),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, color: Colors.red[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => stepCtrl.onDelete(context, step),
            ),
          ],
        ),
      ),
    );
  }
}
