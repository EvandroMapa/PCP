import 'package:aco_plus/app/core/client/firestore/collections/checklist/models/checklist_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/checklist/checklist_controller.dart';
import 'package:aco_plus/app/modules/checklist/checklist_view_model.dart';
import 'package:aco_plus/app/modules/checklist/ui/checklist_create_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';

class ChecklistsPage extends StatefulWidget {
  const ChecklistsPage({super.key});

  @override
  State<ChecklistsPage> createState() => _ChecklistsPageState();
}

class _ChecklistsPageState extends State<ChecklistsPage> {
  @override
  void initState() {
    setWebTitle('Modelos de Checklist');
    checklistCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Modelos de checklist',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          CadastroBotaoNovo('Novo modelo',
              onTap: () => push(context, const ChecklistCreatePage())),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<ChecklistModel>>(
        stream: FirestoreClient.checklists.dataStream.listen,
        builder: (_, todos) => StreamOut<ChecklistUtils>(
          stream: checklistCtrl.utilsStream.listen,
          builder: (_, utils) {
            final checklists = checklistCtrl
                .getChecklistsFiltered(utils.search.text, todos)
                .toList();
            return Container(
              color: AppColors.neutralLightest,
              child: Column(
                children: [
                  CadastroBusca(
                    hint: 'Buscar modelo',
                    controller: utils.search,
                    contador: checklists.length == 1
                        ? '1 modelo'
                        : '${checklists.length} modelos',
                    onChanged: () => checklistCtrl.utilsStream.update(),
                  ),
                  Expanded(
                    child: checklists.isEmpty
                        ? const EmptyData()
                        : CadastroLista(
                            onRefresh: () async =>
                                FirestoreClient.checklists.fetch(),
                            itens: checklists
                                .map((c) => CadastroLinha(
                                      onTap: () => push(context,
                                          ChecklistCreatePage(checklist: c)),
                                      leading: const CadastroIcone(
                                          Symbols.checklist),
                                      titulo: c.nome,
                                      pares: [
                                        (
                                          'Itens',
                                          c.checklist.length == 1
                                              ? '1 item'
                                              : '${c.checklist.length} itens'
                                        ),
                                      ],
                                    ))
                                .toList(),
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
}
