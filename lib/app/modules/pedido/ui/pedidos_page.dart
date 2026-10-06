
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
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
    setWebTitle(widget.standalone
        ? 'AçoPlus - Pedidos'
        : 'AçoPlus - Planejamento e controle de Produção');
    pedidoCtrl.onInit();
    if (!widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        baseCtrl.appBarActionsStream.add(<Widget>[
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
          // Atrasados contados antes dos atalhos, para o número não sumir
          final atrasados = pedidos.where(_atrasado).length;
          if (utils.tipos.isNotEmpty) {
            pedidos =
                pedidos.where((p) => utils.tipos.contains(p.tipo)).toList();
          }
          if (utils.soAtrasados) {
            pedidos = pedidos.where(_atrasado).toList();
          }
          if (utils.ordenacaoEscolhida) pedidoCtrl.onSortPedidos(pedidos);
          Widget body = RefreshIndicator(
            onRefresh: () async => await FirestoreClient.pedidos.fetch(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Busca sempre visível + contagem
                Row(
                  children: [
                    Expanded(
                      child: AppField(
                        hint: 'Buscar pedido, cliente ou obra',
                        controller: utils.search,
                        suffixIcon: Icons.search,
                        onChanged: (_) => pedidoCtrl.utilsStream.update(),
                      ),
                    ),
                    const W(16),
                    Text(
                      pedidos.length == 1
                          ? '1 pedido'
                          : '${pedidos.length} pedidos',
                      style: AppCss.minimumBold
                          .setSize(13)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ],
                ),
                const H(10),
                _atalhos(utils, atrasados),
                const H(12),
                Visibility(
                  visible: utils.showFilter,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.neutralLight),
                    ),
                    child: Column(
                      children: [
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
                                  utils.ordenacaoEscolhida = true;
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
                                  utils.ordenacaoEscolhida = true;
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
                        separatorBuilder: (_, i) => const H(10),
                        itemBuilder: (_, i) => PedidoItemWidget(
                          pedido: pedidos[i],
                          asCard: true,
                          onTap: (pedido) => push(
                            PedidoPage(
                              pedido: pedido,
                              reason: PedidoInitReason.page,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
          body = ColoredBox(color: AppColors.neutralLightest, child: body);
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

  /// Entrega vencida e ainda não entregue
  bool _atrasado(PedidoModel p) {
    if (p.deliveryAt == null || p.isEntregue) return false;
    final now = DateTime.now();
    return p.deliveryAt!.isBefore(DateTime(now.year, now.month, now.day));
  }

  // ── Atalhos sempre à mostra: atrasados, tipo, entrega, mais filtros ──────
  Widget _atalhos(PedidoUtils utils, int atrasados) {
    Widget chip(String texto,
        {required bool ativo, required VoidCallback onTap, Color? cor}) {
      final c = cor ?? AppColors.primaryMain;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ativo ? c : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ativo ? c : AppColors.neutralLight),
          ),
          child: Text(
            texto,
            style: AppCss.minimumBold
                .setSize(12.5)
                .setColor(ativo ? Colors.white : (cor ?? AppColors.neutralDark)),
          ),
        ),
      );
    }

    void tipo(PedidoTipo t) {
      if (!utils.tipos.remove(t)) utils.tipos.add(t);
      pedidoCtrl.utilsStream.update();
    }

    final porEntrega = utils.ordenacaoEscolhida &&
        utils.sortType == SortType.deliveryAt &&
        utils.sortOrder == SortOrder.asc;
    final filtrosNoPainel = [
      utils.steps.isNotEmpty,
      utils.tag != null,
      utils.localidadeEC.text.isNotEmpty,
    ].where((e) => e).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          'Atrasados $atrasados',
          ativo: utils.soAtrasados,
          cor: atrasados > 0 ? AppColors.statusCritico : null,
          onTap: () {
            utils.soAtrasados = !utils.soAtrasados;
            pedidoCtrl.utilsStream.update();
          },
        ),
        chip('CD',
            ativo: utils.tipos.contains(PedidoTipo.cd),
            onTap: () => tipo(PedidoTipo.cd)),
        chip('CDA',
            ativo: utils.tipos.contains(PedidoTipo.cda),
            onTap: () => tipo(PedidoTipo.cda)),
        chip('Outros',
            ativo: utils.tipos.contains(PedidoTipo.outros),
            onTap: () => tipo(PedidoTipo.outros)),
        chip(
          'Entrega mais próxima primeiro',
          ativo: porEntrega,
          onTap: () {
            if (porEntrega) {
              utils.ordenacaoEscolhida = false;
            } else {
              utils.sortType = SortType.deliveryAt;
              utils.sortOrder = SortOrder.asc;
              utils.ordenacaoEscolhida = true;
            }
            pedidoCtrl.utilsStream.update();
          },
        ),
        chip(
          filtrosNoPainel == 0 ? 'Mais filtros' : 'Mais filtros ($filtrosNoPainel)',
          ativo: utils.showFilter,
          onTap: () {
            utils.showFilter = !utils.showFilter;
            pedidoCtrl.utilsStream.update();
          },
        ),
      ],
    );
  }
}
