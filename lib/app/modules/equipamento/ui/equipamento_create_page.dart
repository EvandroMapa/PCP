import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class EquipamentoCreatePage extends StatefulWidget {
  final EquipamentoModel? equipamento;
  const EquipamentoCreatePage({this.equipamento, super.key});

  @override
  State<EquipamentoCreatePage> createState() => _EquipamentoCreatePageState();
}

class _EquipamentoCreatePageState extends State<EquipamentoCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(EquipamentoCreateModel form) =>
      '${form.codigo.text}|${form.descricao.text}';

  @override
  void initState() {
    setWebTitle('Novo Equipamento');
    equipamentoCtrl.init(widget.equipamento);
    _initialSnapshot = _snapshot(equipamentoCtrl.form);
    super.initState();
  }

  Future<void> _voltar() async {
    final isDirty = _snapshot(equipamentoCtrl.form) != _initialSnapshot;
    if (!isDirty) {
      pop(context);
      return;
    }
    if (await showConfirmDialog(
          'Deseja realmente sair?',
          widget.equipamento != null
              ? 'A edição que realizou será perdida'
              : 'Os dados do equipamento serão perdidos.',
        ) &&
        mounted) {
      pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: equipamentoCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.isEdit
            ? (form.descricao.text.trim().isEmpty
                ? 'Equipamento'
                : form.descricao.text.trim())
            : 'Novo equipamento',
        selo: form.isEdit && form.codigo.text.trim().isNotEmpty
            ? 'Cód. ${form.codigo.text.trim()}'
            : null,
        onVoltar: _voltar,
        onSalvar: () => equipamentoCtrl.onConfirm(context, widget.equipamento),
        onExcluir: form.isEdit
            ? () => equipamentoCtrl.onDelete(context, widget.equipamento!)
            : null,
        rotuloExcluir: 'Excluir equipamento',
        secoes: [
          CadastroSecao(
            icon: Symbols.precision_manufacturing,
            titulo: 'Dados do equipamento',
            child: CadastroLinhaCampos(
              [
                AppField(
                  label: 'Código',
                  controller: form.codigo,
                  onChanged: (_) => equipamentoCtrl.formStream.update(),
                ),
                AppField(
                  label: 'Descrição',
                  hint: 'Ex.: Dobradeira automática',
                  controller: form.descricao,
                  onChanged: (_) => equipamentoCtrl.formStream.update(),
                ),
              ],
              flex: const [1, 3],
            ),
          ),
        ],
      ),
    );
  }
}
