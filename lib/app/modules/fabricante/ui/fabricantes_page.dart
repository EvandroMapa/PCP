import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/fabricante/fabricante_controller.dart';
import 'package:aco_plus/app/modules/fabricante/fabricante_view_model.dart';
import 'package:aco_plus/app/modules/fabricante/ui/fabricante_create_page.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/material.dart';

class FabricantesPage extends StatefulWidget {
  const FabricantesPage({super.key});

  @override
  State<FabricantesPage> createState() => _FabricantesPageState();
}

class _FabricantesPageState extends State<FabricantesPage> {
  @override
  void initState() {
    setWebTitle('Fabricantes');
    FirestoreClient.fabricantes.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        IconButton(
          onPressed: () => push(context, const FabricanteCreatePage()),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<FabricanteModel>>(
      stream: FirestoreClient.fabricantes.dataStream.listen,
      builder: (_, todos) => StreamOut<FabricanteUtils>(
        stream: fabricanteCtrl.utilsStream.listen,
        builder: (_, utils) {
          final fabricantes = fabricanteCtrl
              .getFabricanteesFiltered(utils.search.text, todos)
              .toList();
          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                CadastroBusca(
                  hint: 'Buscar fabricante',
                  controller: utils.search,
                  contador: fabricantes.length == 1
                      ? '1 fabricante'
                      : '${fabricantes.length} fabricantes',
                  onChanged: () => fabricanteCtrl.utilsStream.update(),
                ),
                Expanded(
                  child: fabricantes.isEmpty
                      ? const EmptyData()
                      : CadastroLista(
                          onRefresh: () async =>
                              FirestoreClient.fabricantes.fetch(),
                          itens:
                              fabricantes.map(_itemFabricanteWidget).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemFabricanteWidget(FabricanteModel fabricante) {
    final ramo = fabricante.descricao?.trim() ?? '';
    return CadastroLinha(
      onTap: () =>
          push(context, FabricanteCreatePage(fabricante: fabricante)),
      leading: const CadastroIcone(Symbols.factory),
      titulo: fabricante.nome,
      selos: [if (ramo.isNotEmpty) CadastroSelo(ramo)],
      pares: [
        ('Contato', fabricante.contato ?? ''),
        ('Telefone', fabricante.telefone ?? ''),
        ('E-mail', fabricante.email ?? ''),
      ],
    );
  }
}
