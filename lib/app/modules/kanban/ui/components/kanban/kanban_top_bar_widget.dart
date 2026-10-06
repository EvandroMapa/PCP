import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_notification_bell.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_filtros_bar.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/shimmer/kanban_top_bar_shimmer_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:flutter/material.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_import_pdf_dialog.dart';

class KanbanTopBarWidget extends StatelessWidget {
  final bool standalone;
  const KanbanTopBarWidget({this.standalone = false, super.key});

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
  @override
  Widget build(BuildContext context) {
    return StreamOut<KanbanUtils>(
      loading: const KanbanTopBarShimmerWidget(),
      stream: kanbanCtrl.utilsStream.listen,
      builder: (_, utils) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── AppBar ──
          AppBar(
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
                  _alternarVisao(utils),
                  const W(8),
                  if (usuario.permission.pedido
                      .contains(UserPermissionType.create))
                    PopupMenuButton<int>(
                      tooltip: 'Criar Pedido',
                      icon: Icon(Icons.add, color: AppColors.white),
                      color: AppColors.white,
                      surfaceTintColor: AppColors.white,
                      offset: const Offset(0, 40),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.edit_document,
                                  size: 20, color: AppColors.primaryMain),
                              const W(8),
                              Text('Criar Cartão Manualmente',
                                  style: AppCss.minimumBold.setSize(13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 2,
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf,
                                  size: 20, color: AppColors.primaryMain),
                              const W(8),
                              Text('Criar Cartão via PDF',
                                  style: AppCss.minimumBold.setSize(13)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) async {
                        if (val == 1) {
                          // Antes: ordenava todos os pedidos pelo id (que é
                          // aleatório) e "movia" o último, mexendo num pedido
                          // qualquer. Agora só o pedido criado agora vai
                          // para o topo da etapa; cancelou, não faz nada.
                          final antes = FirestoreClient.pedidos.data
                              .map((e) => e.id)
                              .toSet();
                          await push(context, const PedidoCreatePage());
                          final novos = FirestoreClient.pedidos.data
                              .where((e) => !antes.contains(e.id))
                              .toList();
                          if (novos.length != 1) return;
                          final novo = novos.first;
                          kanbanCtrl.onAccept(novo.step, novo, 0);
                        } else if (val == 2) {
                          await showPedidoImportPdfDialog();
                        }
                      },
                    ),
                  const W(8),
                  const AppNotificationBell(),
                  const W(8),
                ],
              ),
            ],
            backgroundColor: AppColors.primaryMain,
          ),

          // ── Barra única de filtros (quadro e calendário) ──
          KanbanFiltrosBar(utils: utils),
        ],
      ),
    );
  }

  Widget _alternarVisao(KanbanUtils utils) {
    Widget opcao(String texto, IconData icon, KanbanViewMode modo) {
      final ativo = utils.view == modo;
      return InkWell(
        onTap: ativo
            ? null
            : () {
                utils.view = modo;
                kanbanCtrl.utilsStream.update();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: ativo ? Colors.white : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: ativo ? AppColors.primaryMain : Colors.white70),
              const W(6),
              Text(
                texto,
                style: AppCss.minimumBold.setSize(12.5).setColor(
                    ativo ? AppColors.primaryMain : Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opcao('Quadro', Icons.view_kanban, KanbanViewMode.kanban),
          opcao('Calendário', Icons.calendar_month, KanbanViewMode.calendar),
        ],
      ),
    );
  }
}
