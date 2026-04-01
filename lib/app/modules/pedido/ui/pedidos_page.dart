import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_item_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_create_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_archiveds_page.dart';
import 'package:aco_plus/app/modules/pedido/view_models/pedido_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class PedidosPage extends StatefulWidget {
  final bool standalone;
  const PedidosPage({this.standalone = false, super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  @override
  void initState() {
    if (!widget.standalone) setWebTitle('Pedidos');
    pedidoCtrl.onInit();
    if (!widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        baseCtrl.appBarActionsStream.add([
          IconButton(
            onPressed: () => openInNewTab('/pedidos'),
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'Abrir em nova aba',
          ),
          IconButton(
            onPressed: () => push(context, const PedidosArchivedsPage()),
            icon: const Icon(Icons.archive_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              pedidoCtrl.utils.showFilter = !pedidoCtrl.utils.showFilter;
              pedidoCtrl.utilsStream.update();
            },
            icon: const Icon(Icons.sort, color: Colors.white),
          ),
          if (usuario.permission.pedido.contains(UserPermissionType.create))
            IconButton(
              onPressed: () => push(context, const PedidoCreatePage()),
              icon: const Icon(Icons.add, color: Colors.white),
            ),
        ]);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PedidoModel>>(
      stream: FirestoreClient.pedidos.pedidosUnarchivedsStream.listen,
      builder: (_, pedidos) => StreamOut<PedidoUtils>(
        stream: pedidoCtrl.utilsStream.listen,
        builder: (_, utils) {
          pedidos = pedidoCtrl
              .getPedidosFiltered(
                utils.search.text,
                FirestoreClient.pedidos.pepidosUnarchiveds
                    .map((e) => e.copyWith())
                    .toList(),
              )
              .toList();
          if (utils.localidadeEC.text.isNotEmpty) {
            pedidos = pedidos
                .where(
                  (pedido) =>
                      pedido.obra.endereco?.localidade.toCompare.contains(
                        utils.localidadeEC.text.toCompare,
                      ) ??
                      false,
                )
                .toList();
          }
          if (utils.steps.isNotEmpty) {
            pedidos = pedidos
                .where(
                  (pedido) =>
                      utils.steps.map((e) => e.id).contains(pedido.step.id),
                )
                .toList();
          }
          if (utils.tag != null) {
            pedidos = pedidos
                .where((pedido) =>
                    pedido.tags.any((tag) => tag.id == utils.tag!.id))
                .toList();
          }
          Widget body = RefreshIndicator(
            onRefresh: () async => await FirestoreClient.pedidos.fetch(),
            child: ListView(
              children: [
                Visibility(
                  visible: utils.showFilter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        AppField(
                          hint: 'Pesquisar',
                          controller: utils.search,
                          suffixIcon: Icons.search,
                          onChanged: (_) => pedidoCtrl.utilsStream.update(),
                        ),
                        const H(16),
                        AppField(
                          hint: 'Buscar por cidade',
                          controller: utils.localidadeEC,
                          onChanged: (_) => pedidoCtrl.utilsStream.update(),
                        ),
                        const H(16),
                        AppDropDownList<StepModel>(
                          label: 'Etapas',
                          itemColor: (e) => e.color,
                          itens: FirestoreClient.steps.data,
                          addeds: utils.steps,
                          itemLabel: (e) => e.name,
                          onChanged: () {
                            pedidoCtrl.utilsStream.update();
                          },
                        ),
                        const H(16),
                        AppDropDown<TagModel?>(
                          label: 'Tag',
                          hasFilter: false,
                          item: utils.tag,
                          itens: FirestoreClient.tags.data,
                          itemLabel: (e) => e?.nome ?? 'Selecionar tag',
                          onSelect: (e) {
                            utils.tag = e;
                            pedidoCtrl.utilsStream.update();
                          },
                        ),
                        const H(16),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropDown<SortType>(
                                label: 'Ordernar por',
                                hasFilter: false,
                                item: utils.sortType,
                                itens: const [
                                  SortType.createdAt,
                                  SortType.deliveryAt,
                                  SortType.localizator,
                                  SortType.client,
                                ],
                                itemLabel: (e) => e.name,
                                onSelect: (e) {
                                  utils.sortType = e ?? SortType.localizator;
                                  pedidoCtrl.utilsStream.update();
                                },
                              ),
                            ),
                            const W(16),
                            Expanded(
                              child: AppDropDown<SortOrder>(
                                hasFilter: false,
                                label: 'Ordernar',
                                item: utils.sortOrder,
                                itens: SortOrder.values,
                                itemLabel: (e) => e.getName(utils.sortType),
                                onSelect: (e) {
                                  utils.sortOrder = e ?? SortOrder.asc;
                                  pedidoCtrl.utilsStream.update();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                pedidos.isEmpty
                    ? const EmptyData()
                    : ListView.separated(
                        itemCount: pedidos.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 200,
                        separatorBuilder: (_, i) => Divisor(),
                        itemBuilder: (_, i) {
                          log('${pedidos[i].localizador} - ${pedidos[i].pedidosVinculados.toString()}');
                          return PedidoItemWidget(
                            pedido: pedidos[i],
                            onTap: (pedido) => push(
                              PedidoPage(
                                pedido: pedido,
                                reason: PedidoInitReason.page,
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
          if (widget.standalone) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Pedidos',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.primaryMain,
                actions: [
                  IconButton(
                    onPressed: () =>
                        push(context, const PedidosArchivedsPage()),
                    icon:
                        const Icon(Icons.archive_outlined, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      pedidoCtrl.utils.showFilter =
                          !pedidoCtrl.utils.showFilter;
                      pedidoCtrl.utilsStream.update();
                    },
                    icon: const Icon(Icons.sort, color: Colors.white),
                  ),
                  if (usuario.permission.pedido
                      .contains(UserPermissionType.create))
                    IconButton(
                      onPressed: () => push(context, const PedidoCreatePage()),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                ],
              ),
              body: body,
            );
          }
          return body;
        },
      ),
    );
  }
}
