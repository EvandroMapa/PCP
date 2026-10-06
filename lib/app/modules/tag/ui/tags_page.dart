import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/tag/tag_controller.dart';
import 'package:aco_plus/app/modules/tag/tag_view_model.dart';
import 'package:aco_plus/app/modules/tag/ui/tag_create_page.dart';
import 'package:flutter/material.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_lista.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  @override
  void initState() {
    setWebTitle('Etiquetas');
    tagCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Etiquetas',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          CadastroBotaoNovo('Nova etiqueta',
              onTap: () => push(context, const TagCreatePage())),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<TagModel>>(
        stream: FirestoreClient.tags.dataStream.listen,
        builder: (_, todas) => StreamOut<TagUtils>(
          stream: tagCtrl.utilsStream.listen,
          builder: (_, utils) {
            final tags =
                tagCtrl.getTagsFiltered(utils.search.text, todas).toList();
            tags.sort(
                (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
            return Container(
              color: AppColors.neutralLightest,
              child: Column(
                children: [
                  CadastroBusca(
                    hint: 'Buscar etiqueta',
                    controller: utils.search,
                    contador: tags.length == 1
                        ? '1 etiqueta'
                        : '${tags.length} etiquetas',
                    onChanged: () => tagCtrl.utilsStream.update(),
                  ),
                  Expanded(
                    child: tags.isEmpty
                        ? const EmptyData()
                        : CadastroLista(
                            onRefresh: () async => FirestoreClient.tags.fetch(),
                            itens: tags.map(_itemTagWidget).toList(),
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

  Widget _itemTagWidget(TagModel tag) {
    return CadastroLinha(
      onTap: () => push(context, TagCreatePage(tag: tag)),
      leading: CadastroCor(tag.color),
      titulo: tag.nome,
      selos: [
        if (tag.isDefaultCD) const CadastroSelo('Automática em pedidos CD'),
        if (tag.isDefaultCDA) const CadastroSelo('Automática em pedidos CDA'),
      ],
      pares: [('Descrição', tag.descricao)],
      trailing: CadastroMenu([
        CadastroAcao(Icons.edit_outlined, 'Editar etiqueta',
            () => push(context, TagCreatePage(tag: tag))),
        CadastroAcao(Icons.delete_outline, 'Excluir etiqueta',
            () => tagCtrl.onDelete(context, tag),
            destrutiva: true),
      ]),
    );
  }
}
