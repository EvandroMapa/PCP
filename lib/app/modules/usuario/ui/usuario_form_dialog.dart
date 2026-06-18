import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
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
        content: SizedBox(
          width: 800,
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
                            if (e.isOperador) {
                              form.permission.cliente = [];
                              form.permission.pedido = [];
                              form.permission.ordem = [
                                UserPermissionType.read,
                                UserPermissionType.update,
                              ];
                            } else {
                              form.permission.cliente =
                                  UserPermissionType.values.toList();
                              form.permission.pedido =
                                  UserPermissionType.values.toList();
                              form.permission.ordem =
                                  UserPermissionType.values.toList();
                            }
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
                const H(24),
                // ── Área de Permissões ou Banner de Operador ──
                if (!BackendClient.usuarioTipos
                    .getById(form.usuarioTipoId)
                    .isOperador) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _permissionChipGroup(
                          'Clientes',
                          Icons.people_outline,
                          form.permission.cliente,
                          Colors.blue,
                        ),
                      ),
                      const W(12),
                      Expanded(
                        child: _permissionChipGroup(
                          'Pedidos',
                          Icons.receipt_long_outlined,
                          form.permission.pedido,
                          Colors.teal,
                        ),
                      ),
                      const W(12),
                      Expanded(
                        child: _permissionChipGroup(
                          'Ordens',
                          Icons.assignment_outlined,
                          form.permission.ordem,
                          Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[800]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Operadores podem visualizar apenas ordens pendentes',
                            style: TextStyle(
                                color: Colors.amber[900], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _permissionChipGroup(
    String title,
    IconData icon,
    List<UserPermissionType> selected,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: UserPermissionType.values.map((perm) {
              final isActive = selected.contains(perm);
              return FilterChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                showCheckmark: false,
                label: Text(
                  perm.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.white : Colors.grey[600],
                  ),
                ),
                selected: isActive,
                selectedColor: accentColor,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isActive ? accentColor : Colors.grey[300]!,
                  width: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (_) {
                  if (isActive) {
                    selected.remove(perm);
                  } else {
                    selected.add(perm);
                  }
                  usuarioCtrl.formStream.update();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
