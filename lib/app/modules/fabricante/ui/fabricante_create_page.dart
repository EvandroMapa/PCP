import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/fabricante/fabricante_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

class FabricanteCreatePage extends StatefulWidget {
  final FabricanteModel? fabricante;
  const FabricanteCreatePage({this.fabricante, super.key});

  @override
  State<FabricanteCreatePage> createState() => _FabricanteCreatePageState();
}

class _FabricanteCreatePageState extends State<FabricanteCreatePage> {
  String _initialSnapshot = '';

  String _snapshot() {
    final f = fabricanteCtrl.form;
    return '${f.nome.text}|${f.descricao.text}|${f.contato.text}|'
        '${f.telefone.text}|${f.email.text}';
  }

  @override
  void initState() {
    setWebTitle('Novo Fabricante');
    fabricanteCtrl.init(widget.fabricante);
    _initialSnapshot = _snapshot();
    super.initState();
  }

  Future<void> _voltar() async {
    // Sem mudança, sai direto
    if (_snapshot() == _initialSnapshot) {
      pop(context);
      return;
    }
    if (await showConfirmDialog(
          'Deseja realmente sair?',
          widget.fabricante != null
              ? 'A edição que realizou será perdida'
              : 'Os dados do fabricante serão perdidos.',
        ) &&
        mounted) {
      pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: fabricanteCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.isEdit
            ? (form.nome.text.trim().isEmpty
                ? 'Fabricante'
                : form.nome.text.trim())
            : 'Novo fabricante',
        selo: form.isEdit ? form.descricao.text : null,
        onVoltar: _voltar,
        onSalvar: () => fabricanteCtrl.onConfirm(context, widget.fabricante),
        onExcluir: form.isEdit
            ? () => fabricanteCtrl.onDelete(context, widget.fabricante!)
            : null,
        rotuloExcluir: 'Excluir fabricante',
        secoes: [
          CadastroSecao(
            icon: Symbols.factory,
            titulo: 'Identificação',
            child: CadastroLinhaCampos([
              AppField(
                label: 'Nome do fabricante / fornecedor',
                controller: form.nome,
                onChanged: (_) => fabricanteCtrl.formStream.update(),
              ),
              AppField(
                label: 'Ramo',
                required: false,
                hint: 'Ex.: Usina siderúrgica, distribuidora de aço',
                controller: form.descricao,
                onChanged: (_) => fabricanteCtrl.formStream.update(),
              ),
            ]),
          ),
          CadastroSecao(
            icon: Symbols.person,
            titulo: 'Contato (A/C)',
            apoio: 'Responsável no fornecedor; aparece no PDF',
            child: AppField(
              label: 'Nome do contato',
              required: false,
              hint: 'Ex.: Carlos Silva, Depto. de Vendas',
              capitalization: TextCapitalization.words,
              controller: form.contato,
              onChanged: (_) => fabricanteCtrl.formStream.update(),
            ),
          ),
          CadastroSecao(
            icon: Symbols.contact_phone,
            titulo: 'Comunicação',
            apoio: 'Para enviar cotação e pedido de compra direto',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CadastroLinhaCampos([
                  AppField(
                    label: 'WhatsApp',
                    required: false,
                    hint: 'País + DDD + número. Ex.: 5511999999999',
                    type: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\+]')),
                    ],
                    controller: form.telefone,
                    onChanged: (_) => fabricanteCtrl.formStream.update(),
                  ),
                  AppField(
                    label: 'E-mail',
                    required: false,
                    hint: 'compras@fornecedor.com.br',
                    type: TextInputType.emailAddress,
                    controller: form.email,
                    onChanged: (_) => fabricanteCtrl.formStream.update(),
                  ),
                ]),
                const H(2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
