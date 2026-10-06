import 'package:aco_plus/app/core/client/firestore/collections/checklist/models/checklist_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/checklist/check_list_widget.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/checklist/checklist_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ChecklistCreatePage extends StatefulWidget {
  final ChecklistModel? checklist;
  const ChecklistCreatePage({this.checklist, super.key});

  @override
  State<ChecklistCreatePage> createState() => _ChecklistCreatePageState();
}

class _ChecklistCreatePageState extends State<ChecklistCreatePage> {
  @override
  void initState() {
    setWebTitle('Novo Modelo de Checklist');
    checklistCtrl.init(widget.checklist);
    super.initState();
  }

  Future<void> _voltar() async {
    if (!checklistCtrl.form.isDirty) {
      pop(context);
      return;
    }
    if (await showConfirmDialog(
          'Deseja realmente sair?',
          widget.checklist != null
              ? 'A edição que realizou será perdida'
              : 'Os dados do checklist serão perdidos.',
        ) &&
        mounted) {
      pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: checklistCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.isEdit
            ? (form.nome.text.trim().isEmpty
                ? 'Modelo de checklist'
                : form.nome.text.trim())
            : 'Novo modelo de checklist',
        selo: form.isPadrao ? 'Padrão' : null,
        onVoltar: _voltar,
        onSalvar: () => checklistCtrl.onConfirm(context, widget.checklist),
        onExcluir: form.isEdit
            ? () => checklistCtrl.onDelete(context, widget.checklist!)
            : null,
        rotuloExcluir: 'Excluir modelo',
        secoes: [
          CadastroSecao(
            icon: Symbols.checklist,
            titulo: 'Identificação',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(
                  label: 'Nome',
                  controller: form.nome,
                  onChanged: (_) => checklistCtrl.formStream.update(),
                ),
                const SizedBox(height: 8),
                CadastroOpcao(
                  titulo: 'Padrão para novos pedidos',
                  explicacao:
                      'Este modelo é sugerido automaticamente quando um pedido é criado',
                  valor: form.isPadrao,
                  onChanged: (v) {
                    form.isPadrao = v;
                    checklistCtrl.formStream.update();
                  },
                ),
              ],
            ),
          ),
          CadastroSecao(
            icon: Symbols.format_list_bulleted,
            titulo: 'Itens do checklist (${form.checklist.length})',
            child: CheckListWidget(
              items: form.checklist,
              onChanged: (item) => checklistCtrl.formStream.update(),
              onAdd: (item) {
                form.checklist.add(item);
                checklistCtrl.formStream.update();
              },
              onRemove: (item) {
                form.checklist.remove(item);
                checklistCtrl.formStream.update();
              },
            ),
          ),
        ],
      ),
    );
  }
}
