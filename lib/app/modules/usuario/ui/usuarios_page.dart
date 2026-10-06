import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuario_form_dialog.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
        actions: [
          CadastroBotaoNovo('Novo usuário',
              onTap: () => showUsuarioFormDialog(context)),
        ],
      ),
      body: StreamOut<List<UsuarioModel>>(
        stream: FirestoreClient.usuarios.dataStream.listen,
        builder: (_, todos) => StreamOut<UsuarioUtils>(
          stream: usuarioCtrl.utilsStream.listen,
          builder: (_, utils) {
            final usuarios = usuarioCtrl.getUsuariosFiltered(
              utils.search.text,
              todos,
              mostrarInativos: utils.mostrarInativos,
            );
            final inativos = todos.where((u) => !u.isAtivo).length;

            return Container(
              color: AppColors.neutralLightest,
              child: Column(
                children: [
                  CadastroBusca(
                    hint: 'Buscar por login ou nome',
                    controller: utils.search,
                    contador: usuarios.length == 1
                        ? '1 usuário'
                        : '${usuarios.length} usuários',
                    onChanged: () => usuarioCtrl.utilsStream.update(),
                    acoes: [
                      FilterChip(
                        label: Text('Mostrar inativos ($inativos)'),
                        selected: utils.mostrarInativos,
                        showCheckmark: true,
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.brandSoft,
                        side: BorderSide(color: AppColors.neutralLight),
                        labelStyle: AppCss.minimumBold.setSize(12.5),
                        onSelected: (v) {
                          utils.mostrarInativos = v;
                          usuarioCtrl.utilsStream.update();
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: usuarios.isEmpty
                        ? const EmptyData()
                        : CadastroLista(
                            itens: usuarios.map(_itemUsuarioWidget).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _itemUsuarioWidget(UsuarioModel usuario) {
    return Opacity(
      opacity: usuario.isAtivo ? 1 : 0.6,
      child: CadastroLinha(
        onTap: () => showUsuarioFormDialog(context, usuario: usuario),
        leading: const CadastroIcone(Symbols.person),
        titulo: usuario.nome,
        selos: [
          if (usuario.tipo != null) CadastroSelo(usuario.tipo!.nome),
          if (!usuario.isAtivo)
            CadastroSelo('Inativo', cor: AppColors.statusCritico),
        ],
        pares: [('Login', usuario.email)],
        trailing: CadastroMenu([
          CadastroAcao(Icons.edit_outlined, 'Editar usuário',
              () => showUsuarioFormDialog(context, usuario: usuario)),
          CadastroAcao(
            usuario.isAtivo ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
            usuario.isAtivo ? 'Inativar usuário' : 'Reativar usuário',
            () => _confirmToggleAtivo(context, usuario),
          ),
          CadastroAcao(Icons.delete_outline, 'Excluir usuário',
              () => _confirmDelete(context, usuario),
              destrutiva: true),
        ]),
      ),
    );
  }

  void _confirmToggleAtivo(BuildContext context, UsuarioModel usuario) {
    final novoStatus = !usuario.isAtivo;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
              pop(dialogCtx);
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
