import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_view_model.dart';
import 'package:aco_plus/app/modules/equipamento/ui/equipamento_create_page.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

class EquipamentosPage extends StatefulWidget {
  const EquipamentosPage({super.key});

  @override
  State<EquipamentosPage> createState() => _EquipamentosPageState();
}

class _EquipamentosPageState extends State<EquipamentosPage> {
  @override
  void initState() {
    setWebTitle('Equipamentos');
    FirestoreClient.equipamentos.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        IconButton(
          onPressed: () => push(context, const EquipamentoCreatePage()),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<EquipamentoModel>>(
      stream: FirestoreClient.equipamentos.dataStream.listen,
      builder: (_, todos) => StreamOut<EquipamentoUtils>(
        stream: equipamentoCtrl.utilsStream.listen,
        builder: (_, utils) {
          final equipamentos = equipamentoCtrl
              .getEquipamentosFiltered(utils.search.text, todos)
              .toList();
          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                CadastroBusca(
                  hint: 'Buscar equipamento',
                  controller: utils.search,
                  contador: equipamentos.length == 1
                      ? '1 equipamento'
                      : '${equipamentos.length} equipamentos',
                  onChanged: () => equipamentoCtrl.utilsStream.update(),
                ),
                Expanded(
                  child: equipamentos.isEmpty
                      ? const EmptyData()
                      : CadastroLista(
                          onRefresh: () async =>
                              FirestoreClient.equipamentos.fetch(),
                          itens: equipamentos
                              .map(_itemEquipamentoWidget)
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemEquipamentoWidget(EquipamentoModel equipamento) {
    return CadastroLinha(
      onTap: () =>
          push(context, EquipamentoCreatePage(equipamento: equipamento)),
      leading: const CadastroIcone(Symbols.precision_manufacturing),
      titulo: equipamento.descricao,
      selos: [
        if (equipamento.codigo.trim().isNotEmpty)
          CadastroSelo(equipamento.codigo.trim()),
      ],
    );
  }
}
