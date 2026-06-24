import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_view_model.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: const Color(0xFFCBD5E1),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            final isDirty =
                _snapshot(equipamentoCtrl.form) != _initialSnapshot;
            if (isDirty) {
              if (await showConfirmDialog(
                'Deseja realmente sair?',
                widget.equipamento != null
                    ? 'A edição que realizou será perdida'
                    : 'Os dados do equipamento serão perdidos.',
              )) {
                pop(context);
              }
            } else {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${equipamentoCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Equipamento',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async =>
                await equipamentoCtrl.onConfirm(context, widget.equipamento),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: equipamentoCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(EquipamentoCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.precision_manufacturing_outlined,
                      color: AppColors.primaryMain),
                  const SizedBox(width: 12),
                  Text('DADOS DO EQUIPAMENTO',
                      style: AppCss.mediumBold.setSize(16)),
                ],
              ),
              const SizedBox(height: 24),
              AppField(
                label: 'Código',
                controller: form.codigo,
                onChanged: (_) => equipamentoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Descrição',
                controller: form.descricao,
                onChanged: (_) => equipamentoCtrl.formStream.update(),
              ),
            ],
          ),
        ),
        const H(24),
        if (form.isEdit) _buildDeleteButton(),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: () => equipamentoCtrl.onDelete(context, widget.equipamento!),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'EXCLUIR EQUIPAMENTO',
              style: AppCss.mediumBold.setColor(AppColors.error).setSize(14),
            ),
          ],
        ),
      ),
    );
  }
}
