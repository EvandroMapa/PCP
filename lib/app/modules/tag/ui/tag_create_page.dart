import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/components/app_color_picker.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/tag/tag_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class TagCreatePage extends StatefulWidget {
  final TagModel? tag;
  const TagCreatePage({this.tag, super.key});

  @override
  State<TagCreatePage> createState() => _TagCreatePageState();
}

class _TagCreatePageState extends State<TagCreatePage> {
  String _initialSnapshot = '';

  String _snapshot() {
    final f = tagCtrl.form;
    return '${f.nome.text}|${f.descricao.text}|${f.color.toARGB32()}|'
        '${f.isDefaultCD}|${f.isDefaultCDA}';
  }

  @override
  void initState() {
    setWebTitle('Nova Etiqueta');
    tagCtrl.init(widget.tag);
    _initialSnapshot = _snapshot();
    super.initState();
  }

  /// Sem mudança, sai direto
  Future<void> _voltar() async {
    if (_snapshot() == _initialSnapshot) {
      pop(context);
      return;
    }
    if (await showConfirmDialog(
          'Deseja realmente sair?',
          widget.tag != null
              ? 'A edição que realizou será perdida'
              : 'Os dados da etiqueta serão perdidos.',
        ) &&
        mounted) {
      pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: tagCtrl.formStream.listen,
      builder: (_, form) => CadastroFormPage(
        titulo: form.isEdit
            ? (form.nome.text.trim().isEmpty ? 'Etiqueta' : form.nome.text.trim())
            : 'Nova etiqueta',
        onVoltar: _voltar,
        onSalvar: () => tagCtrl.onConfirm(context, widget.tag),
        onExcluir: form.isEdit
            ? () => tagCtrl.onDelete(context, widget.tag!)
            : null,
        rotuloExcluir: 'Excluir etiqueta',
        secoes: [
          CadastroSecao(
            icon: Symbols.sell,
            titulo: 'Identificação',
            child: CadastroLinhaCampos([
              AppField(
                label: 'Nome',
                controller: form.nome,
                onChanged: (_) => tagCtrl.formStream.update(),
              ),
              AppField(
                label: 'Descrição',
                required: false,
                controller: form.descricao,
                onChanged: (_) => tagCtrl.formStream.update(),
              ),
            ]),
          ),
          CadastroSecao(
            icon: Symbols.palette,
            titulo: 'Cor',
            apoio: 'Cor da etiqueta nos cartões do Kanban',
            child: AppColorPicker(
              label: 'Cor:',
              color: form.color,
              onChanged: (e) {
                form.color = e;
                tagCtrl.formStream.update();
              },
            ),
          ),
          CadastroSecao(
            icon: Symbols.auto_mode,
            titulo: 'Vincular automaticamente',
            child: Column(
              children: [
                CadastroOpcao(
                  titulo: 'Em todo pedido CD',
                  explicacao:
                      'Pedidos de corte e dobra recebem esta etiqueta ao serem criados',
                  valor: form.isDefaultCD,
                  onChanged: (v) {
                    form.isDefaultCD = v;
                    tagCtrl.formStream.update();
                  },
                ),
                CadastroOpcao(
                  titulo: 'Em todo pedido CDA',
                  explicacao:
                      'Pedidos com armação recebem esta etiqueta ao serem criados',
                  valor: form.isDefaultCDA,
                  onChanged: (v) {
                    form.isDefaultCDA = v;
                    tagCtrl.formStream.update();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
