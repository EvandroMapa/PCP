import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_filter_widget.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/shimmer/kanban_top_bar_shimmer_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:flutter/material.dart';
import 'package:info_popup/info_popup.dart';

class KanbanTopBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final bool standalone;
  const KanbanTopBarWidget({this.standalone = false, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return _KanbanTopbarConcreteWidget(standalone: standalone);
  }
}

class _KanbanTopbarConcreteWidget extends StatefulWidget {
  final bool standalone;
  const _KanbanTopbarConcreteWidget({this.standalone = false});

  @override
  State<_KanbanTopbarConcreteWidget> createState() =>
      _KanbanTopbarConcreteWidgetState();
}

class _KanbanTopbarConcreteWidgetState
    extends State<_KanbanTopbarConcreteWidget> {
  late InfoPopupController controller;
  @override
  Widget build(BuildContext context) {
    return StreamOut<KanbanUtils>(
      loading: const KanbanTopBarShimmerWidget(),
      stream: kanbanCtrl.utilsStream.listen,
      builder: (_, utils) => AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        leading: widget.standalone
            ? null
            : Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: Icon(Icons.menu, color: AppColors.white),
                ),
              ),
        title: Text(
          'Kanban',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.standalone) ...[
                IconButton(
                  onPressed: () => openInNewTab('/kanban'),
                  icon: Icon(Icons.open_in_new, color: AppColors.white),
                  tooltip: 'Abrir em nova aba',
                ),
                const W(4),
              ],
              InfoPopupWidget(
                onControllerCreated: (value) {
                  controller = value;
                  utils.controller = value;
                  kanbanCtrl.utilsStream.update();
                },
                onAreaPressed: (e) {},
                dismissTriggerBehavior: PopupDismissTriggerBehavior.manuel,
                customContent: () => KanbanFilterWidget(utils),
                contentOffset: const Offset(-10, 0),
                infoPopupDismissed: () {},
                arrowTheme: InfoPopupArrowTheme(color: AppColors.white),
                child: Stack(
                  children: [
                    IconButton(
                      onPressed: () => controller.show(),
                      icon: Icon(
                        Icons.filter_list,
                        color: utils.hasFilter() ? Colors.redAccent : AppColors.white,
                      ),
                    ),
                    if (utils.hasFilter())
                      Positioned(
                        right: 8,
                        top: 0,
                        child: InkWell(
                          onTap: () {
                            utils.search.text = '';
                            utils.cliente = null;
                            utils.clienteEC.text = '';
                            utils.usuario = null;
                            utils.usuarioEC.text = '';
                            utils.localidadeEC.text = '';
                            utils.tag = null;
                            utils.tagEC.text = '';
                            controller.dismissInfoPopup();
                            kanbanCtrl.utilsStream.update();
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.close,
                                size: 10,
                                color: AppColors.primaryMain,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const W(4),
              IconButton(
                onPressed: () {
                  if (utils.view == KanbanViewMode.calendar) {
                    utils.view = KanbanViewMode.kanban;
                  } else {
                    utils.view = KanbanViewMode.calendar;
                  }
                  kanbanCtrl.utilsStream.update();
                },
                icon: Icon(
                  utils.view != KanbanViewMode.calendar
                      ? Icons.calendar_month
                      : Icons.view_kanban,
                  color: AppColors.white,
                ),
              ),
              const W(8),
              if (usuario.permission.pedido.contains(UserPermissionType.create))
                IconButton(
                  onPressed: () async {
                    await push(context, const PedidoCreatePage());
                    final pedidos = FirestoreClient.pedidos.data;
                    pedidos.sort((a, b) => a.id.compareTo(b.id));
                    kanbanCtrl.onAccept(pedidos.last.step, pedidos.last, 0);
                  },
                  icon: Icon(Icons.add, color: AppColors.white),
                ),
              const W(8),
            ],
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
    );
  }
}
