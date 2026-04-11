import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:flutter/material.dart';

Future<void> showUsuarioTipoFormDialog(BuildContext context, {UsuarioTipoModel? tipo}) async {
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
        content: SizedBox(
          width: 400,
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
                onChanged: (v) => setState(() => form.isPermitirElementos = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Acessa como operador'),
                value: form.isOperador,
                onChanged: (v) => setState(() => form.isOperador = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Acessa como armador'),
                value: form.isArmador,
                onChanged: (v) => setState(() => form.isArmador = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
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
}
