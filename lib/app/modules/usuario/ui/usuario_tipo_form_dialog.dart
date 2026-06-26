import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:flutter/material.dart';

Future<void> showUsuarioTipoFormDialog(BuildContext context,
    {UsuarioTipoModel? tipo}) async {
  usuarioTipoCtrl.init(tipo);
  await showDialog(
    context: context,
    builder: (_) => const UsuarioTipoFormDialog(),
  );
}

class UsuarioTipoFormDialog extends StatefulWidget {
  const UsuarioTipoFormDialog({super.key});

  @override
  State<UsuarioTipoFormDialog> createState() => _UsuarioTipoFormDialogState();
}

class _UsuarioTipoFormDialogState extends State<UsuarioTipoFormDialog> {
  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioTipoCreateModel>(
      stream: usuarioTipoCtrl.formStream.listen,
      builder: (_, form) => AlertDialog(
        title: Text('${form.isEdit ? 'Editar' : 'Novo'} Perfil de Usuário'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: form.nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Perfil',
                    hintText: 'Ex: Admin, Operador, Vendedor...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Tem acesso à aba Elementos'),
                  value: form.isPermitirElementos,
                  onChanged: (v) =>
                      setState(() => form.isPermitirElementos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Permite editar elementos'),
                  value: form.isPermitirEditarElementos,
                  onChanged: (v) =>
                      setState(() => form.isPermitirEditarElementos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Permite excluir pedidos'),
                  value: form.isPermitirExcluirPedido,
                  onChanged: (v) =>
                      setState(() => form.isPermitirExcluirPedido = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Permite ajuste de estoque'),
                  value: form.isPermitirAjusteEstoque,
                  onChanged: (v) =>
                      setState(() => form.isPermitirAjusteEstoque = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Acessa como administrador'),
                  value: form.isAdministrador,
                  onChanged: (v) => setState(() {
                    form.isAdministrador = v ?? false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Acessa como operador'),
                  value: form.isOperador,
                  onChanged: (v) => setState(() {
                    form.isOperador = v ?? false;
                    // Se exclusivo, só pode ter um
                    if (form.isExclusivo && form.isOperador) {
                      form.isArmador = false;
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Acessa como armador'),
                  value: form.isArmador,
                  onChanged: (v) => setState(() {
                    form.isArmador = v ?? false;
                    // Se exclusivo, só pode ter um
                    if (form.isExclusivo && form.isArmador) {
                      form.isOperador = false;
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (form.isOperador || form.isArmador) ...[
                  const Divider(height: 8),
                  CheckboxListTile(
                    title: const Text('Acesso exclusivo'),
                    subtitle: Text(
                      'Bloqueia o acesso à tela principal.\n'
                      'Permite apenas a rota dedicada'
                      '${form.isOperador ? " (/operador)" : ""}'
                      '${form.isArmador ? " (/armador)" : ""}.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    value: form.isExclusivo,
                    onChanged: (v) => setState(() {
                      form.isExclusivo = v ?? false;
                      // Ao marcar exclusivo com ambos, mantém só operador
                      if (form.isExclusivo && form.isOperador && form.isArmador) {
                        form.isArmador = false;
                      }
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                // ── Permissões CRUD (Clientes / Pedidos / Ordens) ──
                if (!form.isExclusivo) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Permissões de Acesso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _permissionChipGroup(
                          'Clientes',
                          Icons.people_outline,
                          form.permissaoCliente,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _permissionChipGroup(
                          'Pedidos',
                          Icons.receipt_long_outlined,
                          form.permissaoPedido,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _permissionChipGroup(
                          'Ordens',
                          Icons.assignment_outlined,
                          form.permissaoOrdem,
                          Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () => usuarioTipoCtrl.onConfirm(context),
            child: const Text('Salvar'),
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
      padding: const EdgeInsets.all(10),
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
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: UserPermissionType.values.map((perm) {
              final isActive = selected.contains(perm);
              return FilterChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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
                  setState(() {
                    if (isActive) {
                      selected.remove(perm);
                    } else {
                      selected.add(perm);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
