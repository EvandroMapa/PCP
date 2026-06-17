import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/fabricante/fabricante_controller.dart';
import 'package:aco_plus/app/modules/fabricante/fabricante_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FabricanteCreatePage extends StatefulWidget {
  final FabricanteModel? fabricante;
  const FabricanteCreatePage({this.fabricante, super.key});

  @override
  State<FabricanteCreatePage> createState() => _FabricanteCreatePageState();
}

class _FabricanteCreatePageState extends State<FabricanteCreatePage> {
  @override
  void initState() {
    setWebTitle('Novo Fabricante');
    fabricanteCtrl.init(widget.fabricante);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (await showConfirmDialog(
              'Deseja realmente sair?',
              widget.fabricante != null
                  ? 'A edicao que realizou sera perdida'
                  : 'Os dados do fabricante serao perdidos.',
            )) {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${fabricanteCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Fabricante',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async =>
                await fabricanteCtrl.onConfirm(context, widget.fabricante),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: fabricanteCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(FabricanteCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Identificacao ─────────────────────────────────────────
        _sectionLabel(Icons.factory_outlined, 'Identificacao'),
        const H(8),
        AppField(
          label: 'Nome do Fabricante / Fornecedor *',
          controller: form.nome,
          onChanged: (_) => fabricanteCtrl.formStream.update(),
        ),
        const H(12),
        // Descricao
        TextFormField(
          controller: form.descricao.controller,
          decoration: InputDecoration(
            labelText: 'Descricao (opcional)',
            hintText: 'Ex: Distribuidora de Aco, Usina Siderurgica...',
            prefixIcon: const Icon(Icons.description_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryMain),
            ),
            isDense: true,
          ),
          onChanged: (_) => fabricanteCtrl.formStream.update(),
        ),

        const H(20),

        // ── Contato ───────────────────────────────────────────────
        _sectionLabel(Icons.person_outline, 'Contato (A/C)'),
        const H(4),
        Text(
          'Nome do responsavel pelo contato no fornecedor (aparece no PDF).',
          style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12),
        ),
        const H(12),
        TextFormField(
          controller: form.contato.controller,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nome do Contato (opcional)',
            hintText: 'Ex: Carlos Silva, Depto. de Vendas...',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryMain),
            ),
            isDense: true,
          ),
          onChanged: (_) => fabricanteCtrl.formStream.update(),
        ),

        const H(20),

        // ── Comunicacao ───────────────────────────────────────────
        _sectionLabel(Icons.contact_phone_outlined, 'Comunicacao (opcional)'),
        const H(4),
        Text(
          'Usados para envio direto de pedidos de cotacao e compra.',
          style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(12),
        ),
        const H(12),

        // WhatsApp
        TextFormField(
          controller: form.telefone.controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\+]')),
          ],
          decoration: InputDecoration(
            labelText: 'WhatsApp',
            hintText: 'Ex: 5511999999999 (somente numeros)',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            helperText: 'Codigo do pais + DDD + numero',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryMain),
            ),
            isDense: true,
          ),
          onChanged: (_) => fabricanteCtrl.formStream.update(),
        ),
        const H(12),

        // E-mail
        TextFormField(
          controller: form.email.controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail',
            hintText: 'compras@fornecedor.com.br',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryMain),
            ),
            isDense: true,
          ),
          onChanged: (_) => fabricanteCtrl.formStream.update(),
        ),

        const H(24),

        if (form.isEdit)
          TextButton.icon(
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(
                Size.fromWidth(double.maxFinite),
              ),
              foregroundColor: WidgetStatePropertyAll(AppColors.error),
              backgroundColor: WidgetStatePropertyAll(AppColors.white),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: AppCss.radius8,
                  side: BorderSide(color: AppColors.error),
                ),
              ),
            ),
            onPressed: () =>
                fabricanteCtrl.onDelete(context, widget.fabricante!),
            label: const Text('Excluir'),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primaryMain),
          const SizedBox(width: 6),
          Text(label,
              style: AppCss.minimumBold
                  .setSize(13)
                  .setColor(AppColors.primaryMain)),
        ],
      );
}
