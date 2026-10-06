import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
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

/// Barra única de filtros do Kanban (quadro e calendário): busca,
/// Atrasados, Sem data, Etiqueta e Responsável, todos no mesmo formato de
/// pílula. Ativo = pílula escura com "×" para limpar.
class KanbanFiltrosBar extends StatefulWidget {
  final KanbanUtils utils;
  const KanbanFiltrosBar({required this.utils, super.key});

  @override
  State<KanbanFiltrosBar> createState() => _KanbanFiltrosBarState();
}

class _KanbanFiltrosBarState extends State<KanbanFiltrosBar> {
  final GlobalKey _etiquetaKey = GlobalKey();

  KanbanUtils get utils => widget.utils;

  void _atualizar() => kanbanCtrl.utilsStream.update();

  void _limparTudo() {
    utils.soAtrasados = false;
    utils.soSemData = false;
    utils.search.text = '';
    utils.tagsSelecionadas.clear();
    utils.tagEC.text = '';
    utils.usuario = null;
    utils.usuarioEC.text = '';
    utils.cliente = null;
    utils.clienteEC.text = '';
    utils.localidadeEC.text = '';
    _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    // Contagens dentro dos outros filtros (etiqueta, responsável, busca)
    final base = BackendClient.pedidos.pepidosUnarchiveds
        .where((p) => utils.isPedidoVisibleFiltered(p, ignorarRapidos: true));
    final qtdAtrasados = base.where(KanbanUtils.isAtrasado).length;
    final qtdSemData =
        base.where((p) => p.deliveryAt == null && !p.isEntregue).length;
    final arquivados = _arquivadosEncontrados();

    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutralLight)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _busca(),
          _pilula(
            icon: Icons.warning_amber_rounded,
            texto: 'Atrasados ($qtdAtrasados)',
            ativo: utils.soAtrasados,
            corAlerta: qtdAtrasados > 0 ? AppColors.statusCritico : null,
            onTap: () {
              utils.soAtrasados = !utils.soAtrasados;
              if (utils.soAtrasados) utils.soSemData = false;
              _atualizar();
            },
            onLimpar: () {
              utils.soAtrasados = false;
              _atualizar();
            },
          ),
          _pilula(
            icon: Icons.event_busy,
            texto: 'Sem data ($qtdSemData)',
            ativo: utils.soSemData,
            onTap: () {
              utils.soSemData = !utils.soSemData;
              if (utils.soSemData) utils.soAtrasados = false;
              _atualizar();
            },
            onLimpar: () {
              utils.soSemData = false;
              _atualizar();
            },
          ),
          _etiqueta(),
          _responsavel(),
          if (utils.hasFilter())
            _link(
              icon: Icons.close_rounded,
              texto: 'Limpar filtros',
              onTap: _limparTudo,
            ),
          if (arquivados.isNotEmpty)
            _link(
              icon: Icons.inventory_2_outlined,
              texto:
                  '${arquivados.length} arquivados também batem com a busca',
              cor: AppColors.primaryMain,
              onTap: () async {
                push(context, PedidosArchivedsPage());
                await Future.delayed(const Duration(milliseconds: 100));
                pedidoCtrl.utilsArquiveds.search.text = utils.search.text;
                pedidoCtrl.utilsArquiveds.showFilter = true;
                pedidoCtrl.utilsArquivedsStream.update();
              },
            ),
        ],
      ),
    );
  }

  /// Link discreto (sem fundo), para ações secundárias da barra
  Widget _link({
    required IconData icon,
    required String texto,
    required VoidCallback onTap,
    Color? cor,
  }) {
    final c = cor ?? AppColors.neutralDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      hoverColor: AppColors.neutralLightest,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 5),
            Text(texto, style: AppCss.minimumBold.setSize(12.5).setColor(c)),
          ],
        ),
      ),
    );
  }

  // ── Pílula padrão: branca; ativa = escura com "×" ─────────────────────────
  Widget _pilula({
    required IconData icon,
    required String texto,
    required bool ativo,
    required VoidCallback onTap,
    VoidCallback? onLimpar,
    Color? corAlerta,
    Color? corAtiva,
    Key? key,
  }) {
    final fundoAtivo = corAtiva ?? corAlerta ?? AppColors.primaryMain;
    final corTexto = ativo ? Colors.white : (corAlerta ?? AppColors.neutralDark);
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        padding: EdgeInsets.only(left: 11, right: ativo ? 4 : 12),
        decoration: BoxDecoration(
          color: ativo ? fundoAtivo : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: ativo
                  ? fundoAtivo
                  : (corAlerta?.withValues(alpha: 0.5) ??
                      AppColors.neutralLight)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: corTexto),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: AppCss.minimumBold.setSize(12.5).setColor(corTexto),
              ),
            ),
            if (ativo && onLimpar != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onLimpar,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Busca no mesmo formato de pílula ─────────────────────────────────────
  Widget _busca() {
    final temTexto = utils.search.text.isNotEmpty;
    return SizedBox(
      width: 260,
      height: 32,
      child: TextField(
        controller: utils.search.controller,
        style: AppCss.minimumRegular.setSize(13),
        cursorColor: AppColors.primaryMain,
        onChanged: (_) => _atualizar(),
        decoration: InputDecoration(
          hintText: 'Buscar localizador ou pedido financeiro',
          hintStyle: AppCss.minimumRegular
              .setSize(12.5)
              .setColor(AppColors.neutralMedium),
          prefixIcon:
              Icon(Icons.search_rounded, size: 17, color: AppColors.neutralDark),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          suffixIcon: temTexto
              ? InkWell(
                  onTap: () {
                    utils.search.text = '';
                    _atualizar();
                  },
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.neutralMedium),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 30),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: temTexto ? AppColors.brandSoft : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: AppColors.neutralLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(
                color: temTexto ? AppColors.primaryMain : AppColors.neutralLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: AppColors.primaryMain, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Etiqueta (várias) ────────────────────────────────────────────────────
  Widget _etiqueta() {
    final sel = utils.tagsSelecionadas;
    final texto = sel.isEmpty
        ? 'Etiqueta'
        : sel.length == 1
            ? 'Etiqueta: ${sel.first.nome}'
            : '${sel.length} etiquetas';
    return _pilula(
      key: _etiquetaKey,
      icon: Icons.label_rounded,
      texto: sel.isEmpty ? '$texto  ▾' : texto,
      ativo: sel.isNotEmpty,
      corAtiva: sel.length == 1 ? sel.first.color : null,
      onTap: _mostrarEtiquetas,
      onLimpar: () {
        utils.tagsSelecionadas.clear();
        utils.tagEC.text = '';
        _atualizar();
      },
    );
  }

  void _mostrarEtiquetas() {
    final tags = FirestoreClient.tags.data;
    final box = _etiquetaKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Stack(
          children: [
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
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: Container(
                  width: 250,
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Filtrar por etiqueta',
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(AppColors.neutralMedium),
                              ),
                            ),
                            if (utils.tagsSelecionadas.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setDialogState(
                                      () => utils.tagsSelecionadas.clear());
                                  _atualizar();
                                },
                                style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                child: const Text('Limpar'),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
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
                                _atualizar();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
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
                                            color: tag.color, width: 2),
                                      ),
                                      child: marcada
                                          ? const Icon(Icons.check_rounded,
                                              size: 10, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(tag.nome,
                                          style: AppCss.smallRegular,
                                          overflow: TextOverflow.ellipsis),
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
        ),
      ),
    );
  }

  // ── Responsável (usuário do pedido) ──────────────────────────────────────
  final GlobalKey _responsavelKey = GlobalKey();

  Widget _responsavel() {
    final sel = utils.usuario;
    return _pilula(
      key: _responsavelKey,
      icon: Icons.person_rounded,
      texto: sel == null ? 'Responsável  ▾' : 'Responsável: ${sel.nome}',
      ativo: sel != null,
      onTap: _mostrarResponsaveis,
      onLimpar: () {
        utils.usuario = null;
        utils.usuarioEC.text = '';
        _atualizar();
      },
    );
  }

  Future<void> _mostrarResponsaveis() async {
    final box =
        _responsavelKey.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(0, box.size.height + 4));
    final sel = utils.usuario;
    final escolhido = await showMenu<Object>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        PopupMenuItem<Object>(
          value: 'todos',
          child: Text('Todos os responsáveis',
              style: AppCss.smallRegular.setColor(AppColors.neutralDark)),
        ),
        const PopupMenuDivider(height: 1),
        // Só usuários ativos (o já escolhido continua aparecendo)
        ...FirestoreClient.usuarios.data
            .where((u) => u.isEscolhivelNaPlataforma || u.id == sel?.id)
            .map(
          (user) => PopupMenuItem<Object>(
            value: user,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.neutralLightest,
                  child: Text(
                    user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                    style:
                        AppCss.minimumBold.setColor(AppColors.neutralDark),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(user.nome,
                      style: AppCss.smallRegular,
                      overflow: TextOverflow.ellipsis),
                ),
                if (sel?.id == user.id)
                  Icon(Icons.check_rounded,
                      size: 16, color: AppColors.primaryMain),
              ],
            ),
          ),
        ),
      ],
    );
    if (escolhido == null) return;
    final user = escolhido is UsuarioModel ? escolhido : null;
    utils.usuario = user;
    utils.usuarioEC.text = user?.nome ?? '';
    _atualizar();
  }

  /// Pedidos arquivados que batem com a busca (para não "sumirem")
  List<PedidoModel> _arquivadosEncontrados() {
    if (utils.search.text.isEmpty) return [];
    return FirestoreClient.pedidos.pedidosArchiveds
        .where((p) =>
            p.localizador.toCompare.contains(utils.search.text.toCompare))
        .toList();
  }
}
