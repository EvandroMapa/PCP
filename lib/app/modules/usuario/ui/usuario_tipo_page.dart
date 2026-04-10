import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuario_tipo_form_dialog.dart';
import 'package:flutter/material.dart';

class UsuarioTipoPage extends StatefulWidget {
  const UsuarioTipoPage({super.key});

  @override
  State<UsuarioTipoPage> createState() => _UsuarioTipoPageState();
}

class _UsuarioTipoPageState extends State<UsuarioTipoPage> {
  @override
  void initState() {
    setWebTitle('Perfis de Usuário');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Perfis de Usuário'),
      ),
      body: StreamOut<List<UsuarioTipoModel>>(
        stream: usuarioTipoCtrl.tiposStream.listen,
        builder: (_, tipos) {
          return ListView.separated(
            itemCount: tipos.length,
            separatorBuilder: (_, __) => const Divisor(),
            itemBuilder: (_, i) {
              final tipo = tipos[i];
              return ListTile(
                title: Text(tipo.nome, style: AppCss.mediumBold),
                subtitle: Text(
                  '${tipo.isPermitirElementos ? 'Acesso a Elementos' : 'Sem acesso a Elementos'} · ${tipo.isOperador ? 'Operador' : 'Gestor'}',
                  style: AppCss.smallRegular.copyWith(color: Colors.grey[600]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showUsuarioTipoFormDialog(context, tipo: tipo),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _confirmDelete(context, tipo),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      fab: FloatingActionButton(
        backgroundColor: AppColors.primaryMain,
        onPressed: () => showUsuarioTipoFormDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, UsuarioTipoModel tipo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Perfil'),
        content: Text('Deseja realmente excluir o perfil "${tipo.nome}"?'),
        actions: [
          TextButton(onPressed: () => pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              pop(context);
              usuarioTipoCtrl.onDelete(context, tipo);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
