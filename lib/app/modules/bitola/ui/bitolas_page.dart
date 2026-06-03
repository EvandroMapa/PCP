import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/bitola/bitola_controller.dart';
import 'package:aco_plus/app/modules/bitola/bitola_view_model.dart';
import 'package:aco_plus/app/modules/bitola/ui/bitola_create_page.dart';
import 'package:flutter/material.dart';

class BitolasPage extends StatefulWidget {
  const BitolasPage({super.key});

  @override
  State<BitolasPage> createState() => _BitolasPageState();
}

class _BitolasPageState extends State<BitolasPage> {
  @override
  void initState() {
    setWebTitle('Bitolas');
    FirestoreClient.bitolas.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        IconButton(
          onPressed: () => push(context, const BitolaCreatePage()),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<BitolaModel>>(
      stream: FirestoreClient.bitolas.dataStream.listen,
      builder: (_, __) => StreamOut<BitolaUtils>(
        stream: bitolaCtrl.utilsStream.listen,
        builder: (_, utils) {
          final produtos =
              bitolaCtrl.getProdutoesFiltered(utils.search.text, __).toList()
                ..sort((a, b) {
                  final cmp = a.sortIndex.compareTo(b.sortIndex);
                  if (cmp != 0) return cmp;
                  return a.number.compareTo(b.number);
                });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppField(
                  hint: 'Pesquisar',
                  controller: utils.search,
                  suffixIcon: Icons.search,
                  onChanged: (_) => bitolaCtrl.utilsStream.update(),
                ),
              ),
              Expanded(
                child: produtos.isEmpty
                    ? const EmptyData()
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: produtos.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = produtos.removeAt(oldIndex);
                          produtos.insert(newIndex, item);
                          bitolaCtrl.onReorder(produtos);
                        },
                        itemBuilder: (_, i) =>
                            _itemProdutoWidget(produtos[i], i),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemProdutoWidget(BitolaModel produto, int index) {
    return Container(
      key: ValueKey(produto.id),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () => push(context, BitolaCreatePage(produto: produto)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: ReorderableDragStartListener(
          index: index,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(Icons.drag_handle, color: Colors.grey[400], size: 24),
          ),
        ),
        title: Text(produto.nome, style: AppCss.mediumBold),
        subtitle: Text(produto.descricao),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.neutralMedium,
        ),
      ),
    );
  }
}

