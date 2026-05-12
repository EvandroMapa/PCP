import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/cliente/cliente_controller.dart';
import 'package:aco_plus/app/modules/cliente/cliente_view_model.dart';
import 'package:aco_plus/app/modules/cliente/ui/cliente_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
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
      builder: (_, __) => StreamOut<ClienteUtils>(
        stream: clienteCtrl.utilsStream.listen,
        builder: (_, utils) {
          final clientes =
              clienteCtrl.getClienteesFiltered(utils.search.text, __).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppField(
                  hint: 'Pesquisar',
                  controller: utils.search,
                  suffixIcon: Icons.search,
                  onChanged: (_) => clienteCtrl.utilsStream.update(),
                ),
              ),
              Expanded(
                child: clientes.isEmpty
                    ? const EmptyData()
                    : RefreshIndicator(
                        onRefresh: () async => FirestoreClient.clientes.fetch(),
                        child: ListView.separated(
                          itemCount: clientes.length,
                          separatorBuilder: (_, i) => const Divisor(),
                          itemBuilder: (_, i) =>
                              _itemClienteWidget(clientes[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  ListTile _itemClienteWidget(ClienteModel cliente) {
    return ListTile(
      onTap: () => push(context, ClienteCreatePage(cliente: cliente)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title:
          Text('${cliente.codigo} - ${cliente.nome}', style: AppCss.mediumBold),
      subtitle: Text(
          'Tel: ${cliente.telefone} - Qtd. Obras: ${cliente.obras.length}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => push(context, ClienteCreatePage(cliente: cliente)),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => clienteCtrl.onDelete(context, cliente),
          ),
        ],
      ),
    );
  }
}

