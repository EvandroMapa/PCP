import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/bitola/bitola_controller.dart';
import 'package:aco_plus/app/modules/bitola/bitola_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BitolaCreatePage extends StatefulWidget {
  final BitolaModel? produto;
  const BitolaCreatePage({this.produto, super.key});

  @override
  State<BitolaCreatePage> createState() => _BitolaCreatePageState();
}

class _BitolaCreatePageState extends State<BitolaCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(BitolaCreateModel form) =>
      '${form.nome.text}|${form.codigoFinanceiro.text}|${form.descricao.text}|${form.massaFinal.text}';

  @override
  void initState() {
    setWebTitle('Nova Bitola');
    bitolaCtrl.init(widget.produto);
    _initialSnapshot = _snapshot(bitolaCtrl.form);
    super.initState();
  }

  Future<void> _voltar() async {
    final isDirty = _snapshot(bitolaCtrl.form) != _initialSnapshot;
    if (!isDirty) {
      pop(context);
      return;
    }
    if (await showConfirmDialog(
          'Deseja realmente sair?',
          widget.produto != null
              ? 'A edição que realizou será perdida'
              : 'Os dados da bitola serão perdidos.',
        ) &&
        mounted) {
      pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: bitolaCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.isEdit
            ? (form.nome.text.trim().isEmpty ? 'Bitola' : form.nome.text.trim())
            : 'Nova bitola',
        onVoltar: _voltar,
        onSalvar: () => bitolaCtrl.onConfirm(context, widget.produto),
        onExcluir: form.isEdit
            ? () => bitolaCtrl.onDelete(context, widget.produto!)
            : null,
        rotuloExcluir: 'Excluir bitola',
        secoes: [
          CadastroSecao(
            icon: Symbols.stacks,
            titulo: 'Dados da bitola',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CadastroLinhaCampos([
                  AppField(
                    label: 'Nome',
                    hint: 'Ex.: 12,5 MM',
                    controller: form.nome,
                    onChanged: (_) => bitolaCtrl.formStream.update(),
                  ),
                  AppField(
                    label: 'Código financeiro',
                    controller: form.codigoFinanceiro,
                    onChanged: (_) => bitolaCtrl.formStream.update(),
                  ),
                ]),
                const H(14),
                CadastroLinhaCampos(
                  [
                    AppField(
                      label: 'Descrição',
                      hint: 'Ex.: VERGALHÃO 12,5 MM ROLO',
                      controller: form.descricao,
                      onChanged: (_) => bitolaCtrl.formStream.update(),
                    ),
                    AppField(
                      label: 'Massa nominal linear',
                      controller: form.massaFinal,
                      onChanged: (_) => bitolaCtrl.formStream.update(),
                      suffixText: 'kg/m',
                    ),
                  ],
                  flex: const [2, 1],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
