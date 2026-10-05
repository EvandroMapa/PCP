import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/cliente/cliente_controller.dart';
import 'package:aco_plus/app/modules/cliente/cliente_view_model.dart';
import 'package:aco_plus/app/modules/cliente/ui/cliente_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  @override
  void initState() {
    setWebTitle('Clientes');
    FirestoreClient.clientes.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        if (usuario.permission.cliente.contains(UserPermissionType.create))
          IconButton(
            onPressed: () => push(context, const ClienteCreatePage()),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<ClienteModel>>(
      stream: FirestoreClient.clientes.dataStream.listen,
      builder: (_, todos) => StreamOut<ClienteUtils>(
        stream: clienteCtrl.utilsStream.listen,
        builder: (_, utils) {
          final clientes =
              clienteCtrl.getClienteesFiltered(utils.search.text, todos).toList();
          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                CadastroBusca(
                  hint: 'Buscar por nome, telefone ou obra',
                  controller: utils.search,
                  contador: clientes.length == 1
                      ? '1 cliente'
                      : '${clientes.length} clientes',
                  onChanged: () => clienteCtrl.utilsStream.update(),
                ),
                Expanded(
                  child: clientes.isEmpty
                      ? const EmptyData()
                      : CadastroLista(
                          onRefresh: () async =>
                              FirestoreClient.clientes.fetch(),
                          itens: clientes.map(_itemClienteWidget).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemClienteWidget(ClienteModel cliente) {
    final cidade = [cliente.endereco.localidade, cliente.endereco.estado]
        .where((e) => e.trim().isNotEmpty)
        .join(' / ');
    final obras = cliente.obras.length;
    return CadastroLinha(
      onTap: () => push(context, ClienteCreatePage(cliente: cliente)),
      leading: const CadastroIcone(Symbols.person),
      titulo: cliente.nome,
      selos: [CadastroSelo('Cód. ${cliente.codigo}')],
      pares: [
        ('Telefone', cliente.telefone),
        ('Cidade', cidade),
        ('Obras', obras == 0 ? 'nenhuma' : '$obras'),
      ],
      // Excluir no menu, longe de um clique acidental
      trailing: PopupMenuButton<String>(
        tooltip: 'Mais ações',
        icon: Icon(Icons.more_vert, color: AppColors.neutralMedium),
        onSelected: (acao) => acao == 'editar'
            ? push(context, ClienteCreatePage(cliente: cliente))
            : clienteCtrl.onDelete(context, cliente),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'editar',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Editar cliente'),
            ]),
          ),
          PopupMenuItem(
            value: 'excluir',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Excluir cliente',
                  style: TextStyle(color: AppColors.error)),
            ]),
          ),
        ],
      ),
    );
  }
}
