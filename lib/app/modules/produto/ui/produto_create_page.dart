import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/produto/produto_controller.dart';
import 'package:aco_plus/app/modules/produto/produto_view_model.dart';
import 'package:flutter/material.dart';

class ProdutoCreatePage extends StatefulWidget {
  final ProdutoModel? produto;
  const ProdutoCreatePage({this.produto, super.key});

  @override
  State<ProdutoCreatePage> createState() => _ProdutoCreatePageState();
}

class _ProdutoCreatePageState extends State<ProdutoCreatePage> {
  String _initialSnapshot = '';

  String _snapshot(ProdutoCreateModel form) =>
      '${form.nome.text}|${form.codigoFinanceiro.text}|${form.descricao.text}|${form.massaFinal.text}';

  @override
  void initState() {
    setWebTitle('Novo Produto');
    produtoCtrl.init(widget.produto);
    _initialSnapshot = _snapshot(produtoCtrl.form);
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
            final isDirty = _snapshot(produtoCtrl.form) != _initialSnapshot;
            if (isDirty) {
              if (await showConfirmDialog(
                'Deseja realmente sair?',
                widget.produto != null
                    ? 'A edição que realizou será perdida'
                    : 'Os dados do produto serão perdidos.',
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
          '${produtoCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Produto',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async => await produtoCtrl.onConfirm(context, widget.produto),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: produtoCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(ProdutoCreateModel form) {
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
                  Icon(Icons.inventory_2_outlined,
                      color: AppColors.primaryMain),
                  const SizedBox(width: 12),
                  Text('DADOS DO PRODUTO',
                      style: AppCss.mediumBold.setSize(16)),
                ],
              ),
              const SizedBox(height: 24),
              AppField(
                label: 'Nome',
                controller: form.nome,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Código Financeiro',
                controller: form.codigoFinanceiro,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'Descrição',
                controller: form.descricao,
                onChanged: (_) => produtoCtrl.formStream.update(),
              ),
              const H(16),
              AppField(
                label: 'MASSA NOMINAL LINEAR (Kg/Metro)',
                controller: form.massaFinal,
                onChanged: (_) => produtoCtrl.formStream.update(),
                suffixText: 'Kg',
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
      onTap: () => produtoCtrl.onDelete(context, widget.produto!),
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
              'EXCLUIR PRODUTO',
              style: AppCss.mediumBold.setColor(AppColors.error).setSize(14),
            ),
          ],
        ),
      ),
    );
  }
}
