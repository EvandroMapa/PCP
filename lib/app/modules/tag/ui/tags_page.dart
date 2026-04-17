import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
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
          IconButton(
            onPressed: () => push(context, const TagCreatePage()),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<TagModel>>(
        stream: FirestoreClient.tags.dataStream.listen,
        builder: (_, __) => StreamOut<TagUtils>(
          stream: tagCtrl.utilsStream.listen,
          builder: (_, utils) {
            final tags =
                tagCtrl.getTagsFiltered(utils.search.text, __).toList();
            tags.sort(
                (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppField(
                    hint: 'Pesquisar',
                    controller: utils.search,
                    suffixIcon: Icons.search,
                    onChanged: (_) => tagCtrl.utilsStream.update(),
                  ),
                ),
                Expanded(
                  child: tags.isEmpty
                      ? const EmptyData()
                      : RefreshIndicator(
                          onRefresh: () async => FirestoreClient.tags.fetch(),
                          child: ListView.builder(
                            itemCount: tags.length,
                            itemBuilder: (_, i) => _itemTagWidget(tags[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemTagWidget(TagModel tag) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () => push(context, TagCreatePage(tag: tag)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: tag.color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.neutralMedium),
          ),
        ),
        title: Text(tag.nome, style: AppCss.mediumBold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag.isDefaultCD)
              Text(
                'Vinculada automaticamente a pedidos de Corte e Dobra',
                style: AppCss.minimumBold.setColor(AppColors.secondary),
              ),
            if (tag.isDefaultCDA)
              Text(
                'Vinculada automaticamente a pedidos de Armado',
                style: AppCss.minimumBold.setColor(AppColors.secondary),
              ),
            if (tag.descricao.isNotEmpty)
              Text(tag.descricao, style: AppCss.minimumRegular),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon:
                  Icon(Icons.edit_outlined, color: Colors.blue[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => push(context, TagCreatePage(tag: tag)),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, color: Colors.red[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => tagCtrl.onDelete(context, tag),
            ),
          ],
        ),
      ),
    );
  }
}
