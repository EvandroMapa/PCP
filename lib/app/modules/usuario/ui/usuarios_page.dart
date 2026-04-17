import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuario_form_dialog.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  @override
  void initState() {
    setWebTitle('Usuários');
    FirestoreClient.usuarios.fetch();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
      ),
      body: StreamOut<List<UsuarioModel>>(
        stream: FirestoreClient.usuarios.dataStream.listen,
        builder: (_, __) => StreamOut<UsuarioUtils>(
          stream: usuarioCtrl.utilsStream.listen,
          builder: (_, utils) {
            final usuarios = usuarioCtrl.getUsuariosFiltered(
              utils.search.text,
              __,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppField(
                    hint: 'Pesquisar Login / Nome',
                    controller: utils.search,
                    suffixIcon: Icons.search,
                    onChanged: (_) => usuarioCtrl.utilsStream.update(),
                  ),
                ),
                Expanded(
                  child: usuarios.isEmpty
                      ? const EmptyData()
                      : ListView.separated(
                          itemCount: usuarios.length,
                          separatorBuilder: (_, i) => const Divisor(),
                          itemBuilder: (_, i) =>
                              _itemUsuarioWidget(usuarios[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      fab: FloatingActionButton(
        backgroundColor: AppColors.primaryMain,
        onPressed: () => showUsuarioFormDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  ListTile _itemUsuarioWidget(UsuarioModel usuario) {
    return ListTile(
      onTap: () => showUsuarioFormDialog(context, usuario: usuario),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(usuario.nome, style: AppCss.mediumBold),
      subtitle: usuario.tipo != null ? Text(usuario.tipo!.nome) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => showUsuarioFormDialog(context, usuario: usuario),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => _confirmDelete(context, usuario),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, UsuarioModel usuario) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Usuário'),
        content: Text('Deseja realmente excluir o usuário "${usuario.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => usuarioCtrl.onDelete(context, usuario),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
