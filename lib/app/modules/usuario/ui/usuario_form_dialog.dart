import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';

import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioCreateModel>(
      stream: usuarioCtrl.formStream.listen,
      builder: (_, form) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${form.isEdit ? 'Editar' : 'Adicionar'} Usuário',
                style: AppCss.largeBold,
              ),
            ),
            if (form.isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => usuarioCtrl.onDelete(context, widget.usuario!),
                tooltip: 'Excluir Usuário',
              ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Linha 1: Nome e Perfil ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppField(
                        label: 'Nome',
                        controller: form.nome,
                        onChanged: (_) => usuarioCtrl.formStream.update(),
                      ),
                    ),
                    const W(16),
                    Expanded(
                      flex: 1,
                      child: AppDropDown<UsuarioTipoModel?>(
                        label: 'Perfil',
                        item: form.usuarioTipoId.isNotEmpty
                            ? BackendClient.usuarioTipos
                                .data
                                .where((t) => t.id == form.usuarioTipoId)
                                .firstOrNull
                            : null,
                        itens: BackendClient.usuarioTipos.data,
                        itemLabel: (e) => e?.nome ?? 'Selecione',
                        onSelect: (e) {
                          if (e != null) {
                            form.usuarioTipoId = e.id;
                          }
                          usuarioCtrl.formStream.update();
                        },
                      ),
                    ),
                  ],
                ),
                const H(16),
                // ── Linha 2: Login e Senha ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppField(
                        label: 'Login',
                        controller: form.email,
                        onChanged: (_) => usuarioCtrl.formStream.update(),
                      ),
                    ),
                    const W(16),
                    Expanded(
                      child: AppField(
                        label: 'Senha',
                        controller: form.senha,
                        onChanged: (_) => usuarioCtrl.formStream.update(),
                      ),
                    ),
                  ],
                ),
                const H(16),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[700])),
          ),
          const W(8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async =>
                await usuarioCtrl.onConfirm(context, widget.usuario),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
