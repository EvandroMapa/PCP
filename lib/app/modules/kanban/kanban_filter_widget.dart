import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_archiveds_page.dart';
import 'package:flutter/material.dart';

class KanbanFilterPanel extends StatefulWidget {
  final KanbanUtils utils;
  final VoidCallback onClose;

  const KanbanFilterPanel({
    required this.utils,
    required this.onClose,
    super.key,
  });

  @override
  State<KanbanFilterPanel> createState() => _KanbanFilterPanelState();
}

class _KanbanFilterPanelState extends State<KanbanFilterPanel> {
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _etiquetaKey = GlobalKey();

  KanbanUtils get utils => widget.utils;

  @override
  void initState() {
    super.initState();
    // Foco automático no campo de busca
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      // Selecionar texto existente
      final ctrl = utils.search.controller;
      if (ctrl.text.isNotEmpty) {
        ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: ctrl.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _limparFiltros() {
    utils.search.text = '';
    utils.tagsSelecionadas.clear();
    utils.tagEC.text = '';
    utils.usuario = null;
    utils.usuarioEC.text = '';
    // Mantém os campos legados limpos
    utils.cliente = null;
    utils.clienteEC.text = '';
    utils.localidadeEC.text = '';
    kanbanCtrl.utilsStream.update();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Filtros: responsivo ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 700;

              final searchField = SizedBox(
                height: 34,
                child: TextField(
                  focusNode: _searchFocus,
                  controller: utils.search.controller,
                  style: AppCss.smallRegular,
                  cursorColor: AppColors.primaryMain,
                  onChanged: (_) => kanbanCtrl.utilsStream.update(),
                  decoration: InputDecoration(
                    hintText: 'Buscar localizador...',
                    hintStyle: AppCss.minimumRegular
                        .setColor(Colors.grey[400]!),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.primaryMain,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                    ),
                    suffixIcon: utils.search.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              utils.search.text = '';
                              kanbanCtrl.utilsStream.update();
                              _searchFocus.requestFocus();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 28,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primaryMain.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              );

              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (utils.hasFilter())
                    _buildIconBtn(
                      icon: Icons.filter_list_off_rounded,
                      tooltip: 'Limpar filtros',
                      onTap: _limparFiltros,
                      color: Colors.redAccent,
                    ),
                  _buildIconBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    tooltip: 'Fechar filtros',
                    onTap: widget.onClose,
                  ),
                ],
              );

              if (isSmall) {
                // Layout vertical para celular
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 4),
                          actionButtons,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildEtiquetaSelector()),
                          const SizedBox(width: 8),
                          Expanded(child: _buildUsuarioSelector()),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // Layout horizontal (desktop)
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    const Spacer(),
                    SizedBox(width: 300, child: searchField),
                    const SizedBox(width: 8),
                    SizedBox(width: 300, child: _buildEtiquetaSelector()),
                    const SizedBox(width: 8),
                    SizedBox(width: 300, child: _buildUsuarioSelector()),
                    const SizedBox(width: 4),
                    actionButtons,
                  ],
                ),
              );
            },
          ),

          // ── Pedidos arquivados (se houver) ──
          _buildArquivadosLink(),
        ],
      ),
    );
  }

  // ── Seletor de Etiqueta (multi-select) ──
  Widget _buildEtiquetaSelector() {
    final selecionadas = utils.tagsSelecionadas;
    final isActive = selecionadas.isNotEmpty;

    String label;
    if (selecionadas.isEmpty) {
      label = 'Etiqueta';
    } else if (selecionadas.length == 1) {
      label = selecionadas.first.nome;
    } else {
      label = '${selecionadas.length} etiquetas';
    }

    return GestureDetector(
      key: _etiquetaKey,
      onTap: () => _mostrarEtiquetasPopup(),
      child: _buildChipSelector(
        icon: Icons.label_rounded,
        label: label,
        isActive: isActive,
        activeColor: selecionadas.length == 1 ? selecionadas.first.color : null,
        onClear: isActive
            ? () {
                setState(() {
                  utils.tagsSelecionadas.clear();
                  utils.tagEC.text = '';
                });
                kanbanCtrl.utilsStream.update();
              }
            : null,
      ),
    );
  }

  void _mostrarEtiquetasPopup() {
    final tags = FirestoreClient.tags.data;
    final RenderBox box =
        _etiquetaKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Stack(
              children: [
                // Fecha ao clicar fora
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  top: offset.dy + box.size.height + 4,
                  left: offset.dx,
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: Container(
                      width: 240,
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cabeçalho
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Filtrar etiquetas',
                                    style: AppCss.minimumBold.setColor(Colors.grey[700]!),
                                  ),
                                ),
                                if (utils.tagsSelecionadas.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        utils.tagsSelecionadas.clear();
                                      });
                                      setState(() {});
                                      kanbanCtrl.utilsStream.update();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        'Limpar',
                                        style: AppCss.minimumRegular
                                            .setColor(Colors.redAccent),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Lista de tags
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: tags.length,
                              itemBuilder: (_, i) {
                                final tag = tags[i];
                                final marcada = utils.tagsSelecionadas
                                    .any((t) => t.id == tag.id);
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      if (marcada) {
                                        utils.tagsSelecionadas
                                            .removeWhere((t) => t.id == tag.id);
                                      } else {
                                        utils.tagsSelecionadas.add(tag);
                                      }
                                    });
                                    setState(() {});
                                    kanbanCtrl.utilsStream.update();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: marcada
                                                ? tag.color
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: tag.color,
                                              width: 2,
                                            ),
                                          ),
                                          child: marcada
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            tag.nome,
                                            style: AppCss.smallRegular,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Seletor de Usuário ──
  Widget _buildUsuarioSelector() {
    final usuarios = FirestoreClient.usuarios.data;
    final usuarioSelecionado = utils.usuario;

    return PopupMenuButton<UsuarioModel?>(
      tooltip: 'Filtrar por usuário',
      offset: const Offset(0, 36),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (user) {
        setState(() {
          utils.usuario = user;
          utils.usuarioEC.text = user?.nome ?? '';
        });
        kanbanCtrl.utilsStream.update();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<UsuarioModel?>(
          onTap: () {
            setState(() {
              utils.usuario = null;
              utils.usuarioEC.text = '';
            });
            kanbanCtrl.utilsStream.update();
          },
          child: Row(
            children: [
              Icon(Icons.group_rounded, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Text(
                'Todos os usuários',
                style: AppCss.smallRegular.setColor(Colors.grey[600]!),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...usuarios.map(
          (user) => PopupMenuItem<UsuarioModel?>(
            value: user,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      AppColors.primaryMain.withValues(alpha: 0.1),
                  child: Text(
                    user.nome.isNotEmpty
                        ? user.nome[0].toUpperCase()
                        : '?',
                    style: AppCss.minimumBold
                        .setColor(AppColors.primaryMain),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.nome,
                    style: AppCss.smallRegular,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (usuarioSelecionado?.id == user.id)
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primaryMain,
                  ),
              ],
            ),
          ),
        ),
      ],
      child: _buildChipSelector(
        icon: Icons.person_rounded,
        label: usuarioSelecionado?.nome ?? 'Usuário',
        isActive: usuarioSelecionado != null,
        onClear: usuarioSelecionado != null
            ? () {
                setState(() {
                  utils.usuario = null;
                  utils.usuarioEC.text = '';
                });
                kanbanCtrl.utilsStream.update();
              }
            : null,
      ),
    );
  }

  // ── Chip visual do seletor ──
  Widget _buildChipSelector({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    VoidCallback? onClear,
  }) {
    final cor = activeColor ?? AppColors.primaryMain;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 34,
      padding: EdgeInsets.only(left: 8, right: isActive ? 3 : 8),
      decoration: BoxDecoration(
        color: isActive
            ? cor.withValues(alpha: 0.10)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? cor.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? cor : Colors.grey[500],
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: (isActive ? AppCss.minimumBold : AppCss.minimumRegular)
                  .setColor(isActive ? cor : Colors.grey[600]!),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          if (isActive && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: cor,
                ),
              ),
            )
          else
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: Colors.grey[500],
            ),
        ],
      ),
    );
  }

  // ── Botão ícone compacto ──
  Widget _buildIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: color ?? Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // ── Link de pedidos arquivados ──
  Widget _buildArquivadosLink() {
    final pedidos = _getPedidosArchiveds();
    if (pedidos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: () async {
            push(context, PedidosArchivedsPage());
            await Future.delayed(const Duration(milliseconds: 100));
            pedidoCtrl.utilsArquiveds.search.text = utils.search.text;
            pedidoCtrl.utilsArquiveds.showFilter = true;
            pedidoCtrl.utilsArquivedsStream.update();
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              'Encontrados ${pedidos.length} pedidos arquivados.',
              style: AppCss.minimumBold
                  .copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primaryMain,
                  )
                  .setColor(AppColors.primaryMain),
            ),
          ),
        ),
      ),
    );
  }

  List<PedidoModel> _getPedidosArchiveds() {
    final List<PedidoModel> pedidosFiltereds = [];
    for (PedidoModel pedido in FirestoreClient.pedidos.pedidosArchiveds) {
      if (utils.search.text.isNotEmpty &&
          pedido.localizador.toCompare
              .contains(utils.search.text.toCompare)) {
        pedidosFiltereds.add(pedido);
        continue;
      }
      if (utils.cliente != null &&
          utils.cliente!.id == pedido.cliente.id) {
        pedidosFiltereds.add(pedido);
        continue;
      }
    }
    return pedidosFiltereds;
  }
}
