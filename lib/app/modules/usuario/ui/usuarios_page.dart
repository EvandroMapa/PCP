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
              mostrarInativos: utils.mostrarInativos,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppField(
                          hint: 'Pesquisar Login / Nome',
                          controller: utils.search,
                          suffixIcon: Icons.search,
                          onChanged: (_) => usuarioCtrl.utilsStream.update(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () {
                          utils.mostrarInativos = !utils.mostrarInativos;
                          usuarioCtrl.utilsStream.update();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: utils.mostrarInativos,
                                  activeColor: AppColors.primaryMain,
                                  onChanged: (v) {
                                    utils.mostrarInativos = v ?? false;
                                    usuarioCtrl.utilsStream.update();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mostrar inativos',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
      title: Row(
        children: [
          Flexible(
            child: Text(
              usuario.nome,
              style: AppCss.mediumBold.copyWith(
                color: usuario.isAtivo ? null : Colors.grey[400],
              ),
            ),
          ),
          if (!usuario.isAtivo) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Inativo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: usuario.tipo != null
          ? Text(
              usuario.tipo!.nome,
              style: TextStyle(
                color: usuario.isAtivo ? null : Colors.grey[400],
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão ativar/inativar
          Tooltip(
            message: usuario.isAtivo ? 'Inativar usuário' : 'Ativar usuário',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: Icon(
                usuario.isAtivo
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined,
                size: 28,
                color: usuario.isAtivo ? Colors.green : Colors.grey[400],
              ),
              onPressed: () => _confirmToggleAtivo(context, usuario),
            ),
          ),
          const SizedBox(width: 4),
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

  void _confirmToggleAtivo(BuildContext context, UsuarioModel usuario) {
    final novoStatus = !usuario.isAtivo;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(novoStatus ? 'Ativar Usuário' : 'Inativar Usuário'),
        content: Text(
          novoStatus
              ? 'Deseja reativar o acesso de "${usuario.nome}" ao sistema?'
              : 'Deseja inativar "${usuario.nome}"? Ele não poderá mais acessar o sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  novoStatus ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              pop(_);
              usuarioCtrl.toggleAtivo(usuario);
            },
            child: Text(novoStatus ? 'Ativar' : 'Inativar'),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => usuarioCtrl.onDelete(context, usuario),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
