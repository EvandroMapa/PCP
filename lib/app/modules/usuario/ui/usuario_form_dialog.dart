import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';

import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<void> showUsuarioFormDialog(BuildContext context,
    {UsuarioModel? usuario}) async {
  usuarioCtrl.init(usuario);
  await showDialog(
    context: context,
    builder: (_) => UsuarioFormDialog(usuario: usuario),
  );
}

class UsuarioFormDialog extends StatefulWidget {
  final UsuarioModel? usuario;
  const UsuarioFormDialog({this.usuario, super.key});

  @override
  State<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<UsuarioFormDialog> {
  bool _verSenha = false;

  /// Mesma regra de antes: com registros na auditoria não exclui (inativa)
  Future<void> _excluir() async {
    final podeExcluir =
        await usuarioCtrl.verificarPodeExcluir(widget.usuario!);
    if (!mounted) return;
    if (!podeExcluir) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Exclusão bloqueada'),
          content: const Text(
            'Este usuário possui registros no log de auditoria e não pode ser excluído. '
            'Para impedir o acesso, inative o usuário.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMain),
              onPressed: () => pop(dialogCtx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text(
            'Deseja realmente excluir o usuário "${widget.usuario!.nome}"?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.transparent),
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      usuarioCtrl.onDelete(context, widget.usuario!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioCreateModel>(
      stream: usuarioCtrl.formStream.listen,
      builder: (_, form) => CadastroDialog(
        icon: Symbols.person,
        titulo: form.isEdit ? 'Editar usuário' : 'Novo usuário',
        onSalvar: () => usuarioCtrl.onConfirm(context, widget.usuario),
        onExcluir: form.isEdit ? _excluir : null,
        rotuloExcluir: 'Excluir usuário',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CadastroSubtitulo('Identificação'),
            CadastroLinhaCampos(
              [
                AppField(
                  label: 'Nome',
                  controller: form.nome,
                  onChanged: (_) => usuarioCtrl.formStream.update(),
                ),
                AppDropDown<UsuarioTipoModel?>(
                  label: 'Perfil',
                  item: form.usuarioTipoId.isNotEmpty
                      ? BackendClient.usuarioTipos.data
                          .where((t) => t.id == form.usuarioTipoId)
                          .firstOrNull
                      : null,
                  itens: BackendClient.usuarioTipos.data,
                  itemLabel: (e) => e?.nome ?? 'Selecione',
                  onSelect: (e) {
                    if (e != null) form.usuarioTipoId = e.id;
                    usuarioCtrl.formStream.update();
                  },
                ),
              ],
              flex: const [3, 2],
            ),
            const SizedBox(height: 18),
            const CadastroSubtitulo('Acesso ao sistema'),
            CadastroLinhaCampos([
              AppField(
                label: 'Login',
                controller: form.email,
                onChanged: (_) => usuarioCtrl.formStream.update(),
              ),
              AppField(
                label: 'Senha',
                controller: form.senha,
                obscure: !_verSenha,
                suffixIcon: _verSenha ? Icons.visibility_off : Icons.visibility,
                onSuffix: () => setState(() => _verSenha = !_verSenha),
                onChanged: (_) => usuarioCtrl.formStream.update(),
              ),
            ]),
            if (form.isEdit) ...[
              const SizedBox(height: 12),
              CadastroOpcao(
                titulo: form.isAtivo ? 'Usuário ativo' : 'Usuário inativo',
                explicacao: form.isAtivo
                    ? 'Pode entrar no sistema'
                    : 'Não consegue entrar no sistema; o histórico é mantido',
                valor: form.isAtivo,
                onChanged: (v) {
                  form.isAtivo = v;
                  usuarioCtrl.formStream.update();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
