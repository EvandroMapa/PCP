import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuario_tipo_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';

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
        title: const Text('Perfis de acesso'),
        actions: [
          CadastroBotaoNovo('Novo perfil',
              onTap: () => showUsuarioTipoFormDialog(context)),
        ],
      ),
      body: StreamOut<List<UsuarioTipoModel>>(
        stream: usuarioTipoCtrl.tiposStream.listen,
        builder: (_, tipos) {
          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      tipos.length == 1 ? '1 perfil' : '${tipos.length} perfis',
                      style: AppCss.minimumBold
                          .setSize(12.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
                ),
                Expanded(
                  child: CadastroLista(
                    itens: tipos.map((tipo) => _itemTipo(tipo)).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemTipo(UsuarioTipoModel tipo) {
    final papel = tipo.isAdministrador
        ? 'Administrador'
        : tipo.isOperador
            ? 'Operador'
            : tipo.isArmador
                ? 'Armador'
                : 'Gestor';
    return CadastroLinha(
      onTap: () => showUsuarioTipoFormDialog(context, tipo: tipo),
      leading: const CadastroIcone(Symbols.badge),
      titulo: tipo.nome,
      selos: [
        CadastroSelo(papel),
        if (tipo.isPermitirElementos) const CadastroSelo('Elementos'),
        if (tipo.isPermitirExcluirPedido) const CadastroSelo('Exclui pedido'),
        if (tipo.isPermitirAjusteEstoque) const CadastroSelo('Ajusta estoque'),
      ],
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, 'Editar perfil',
            () => showUsuarioTipoFormDialog(context, tipo: tipo)),
        CadastroAcao(Icons.delete_outline, 'Excluir perfil',
            () => _confirmDelete(context, tipo),
            destrutiva: true),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, UsuarioTipoModel tipo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Perfil'),
        content: Text('Deseja realmente excluir o perfil "${tipo.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => pop(context), child: const Text('Cancelar')),
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
