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
  bool _filtroAberto = false;

  void _toggleFiltro() {
    setState(() => _filtroAberto = !_filtroAberto);
  }

  void _fecharFiltro() {
    setState(() => _filtroAberto = false);
  }

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
                  if (!widget.standalone) ...[
                    IconButton(
                      onPressed: () => openInNewTab('/kanban'),
                      icon: Icon(Icons.open_in_new, color: AppColors.white),
                      tooltip: 'Abrir em nova aba',
                    ),
                    const W(4),
                  ],
                  // ── Botão de filtro ──
                  Stack(
                    children: [
                      IconButton(
                        onPressed: _toggleFiltro,
                        tooltip: _filtroAberto
                            ? 'Fechar filtros'
                            : 'Abrir filtros',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _filtroAberto
                                ? Icons.filter_list_off_rounded
                                : Icons.filter_list,
                            key: ValueKey(_filtroAberto),
                            color: utils.hasFilter()
                                ? Colors.redAccent
                                : AppColors.white,
                          ),
                        ),
                      ),
                      if (utils.hasFilter() && !_filtroAberto)
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
                              utils.tagsSelecionadas.clear();
                              utils.tagEC.text = '';
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
                          await push(context, const PedidoCreatePage());
                          final pedidos = FirestoreClient.pedidos.data;
                          if (pedidos.isEmpty) return;
                          pedidos.sort((a, b) => a.id.compareTo(b.id));
                          kanbanCtrl.onAccept(
                              pedidos.last.step, pedidos.last, 0);
                        } else if (val == 2) {
                          await showPedidoImportPdfDialog();
                        }
                      },
                    ),
                  const W(8),
                ],
              ),
            ],
            backgroundColor: AppColors.primaryMain,
          ),

          // ── Painel de filtro animado ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _filtroAberto
                ? KanbanFilterPanel(
                    utils: utils,
                    onClose: _fecharFiltro,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
