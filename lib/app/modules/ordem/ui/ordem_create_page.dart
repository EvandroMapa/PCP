import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class OrdemCreatePage extends StatefulWidget {
  final OrdemModel? ordem;
  const OrdemCreatePage({this.ordem, super.key});

  @override
  State<OrdemCreatePage> createState() => _OrdemCreatePageState();
}

class _OrdemCreatePageState extends State<OrdemCreatePage> {
  bool _filtroExpandido = false;
  late bool _configExpandida;

  @override
  void initState() {
    setWebTitle(widget.ordem != null ? 'Editar Ordem' : 'Nova Ordem');
    ordemCtrl.onInitCreatePage(widget.ordem);
    // Começa colapsada se editando (já tem produto), expandida se criando
    _configExpandida = widget.ordem == null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (await showConfirmDialog(
              'Deseja realmente sair?',
              'Os dados da ordem serão perdidos.',
            )) {
              if (!mounted) return;
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          ordemCtrl.form.isEdit
              ? 'Editar Ordem ${widget.ordem?.localizator}'
              : 'Adicionar Ordem',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          if ((widget.ordem != null &&
                  usuario.permission.ordem.contains(UserPermissionType.update)) ||
              (widget.ordem == null &&
                  usuario.permission.ordem.contains(UserPermissionType.create)))
            IconLoadingButton(() async {
              await ordemCtrl.onConfirm(context, widget.ordem);
            }),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: ordemCtrl.formStream.listen,
        builder: (_, form) => _body(form),
      ),
    );
  }

  Widget _body(OrdemCreateModel form) {
    // Monta as duas listas
    final todosDisponiveis = form.produto != null
        ? ordemCtrl.getPedidosPorProduto(form.produto!, ordem: widget.ordem)
        : <PedidoProdutoModel>[];
    final idsNaOrdem = form.produtos.map((e) => e.id).toSet();
    final naOrdem = todosDisponiveis.where((p) => idsNaOrdem.contains(p.id)).toList();
    final disponiveis = todosDisponiveis.where((p) => !idsNaOrdem.contains(p.id)).toList();
    final pesoNaOrdem = naOrdem.fold<double>(0, (s, p) => s + p.qtde);

    final mpSelecionada = form.materiaPrima != null &&
        form.materiaPrima!.id != 'register_unavailable';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _secaoConfiguracao(form),
              if (form.produto != null) ...[
                _secaoNaOrdem(form, naOrdem, pesoNaOrdem),
                _secaoDisponiveis(form, disponiveis, mpSelecionada),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        _bottomBar(naOrdem, pesoNaOrdem, form),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURAÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _secaoConfiguracao(OrdemCreateModel form) {
    final temProduto = form.produto != null;
    final temMP = form.materiaPrima != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header clicável
          InkWell(
            borderRadius: _configExpandida
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            onTap: () => setState(() => _configExpandida = !_configExpandida),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 16, color: AppColors.primaryMain),
                  const SizedBox(width: 8),
                  Text('Configuração', style: AppCss.minimumBold.setSize(13)),
                  const Spacer(),
                  // Resumo compacto quando colapsado
                  if (!_configExpandida && temProduto) ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        form.produto!.descricao,
                        style: AppCss.minimumBold.setSize(11).setColor(AppColors.primaryMain),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (temMP) ...[
                      const SizedBox(width: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          form.materiaPrima!.corridaLote,
                          style: AppCss.minimumBold.setSize(10).setColor(Colors.orange[700]!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _configExpandida ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo expansível
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Divider(height: 1, thickness: 1, color: const Color(0xFFEEF1F5)),
                  const SizedBox(height: 12),
                  AppDropDown<ProdutoModel?>(
                    disable: form.isEdit && form.produtos.isNotEmpty,
                    label: 'Produto',
                    item: form.produto,
                    itens: FirestoreClient.produtos.data.toList()
                      ..sort((a, b) {
                        final cmp = a.sortIndex.compareTo(b.sortIndex);
                        return cmp != 0 ? cmp : a.number.compareTo(b.number);
                      }),
                    itemLabel: (e) => e!.descricao,
                    onSelect: (e) {
                      form.produto = e;
                      form.produtos.clear();
                      form.materiaPrima = null;
                      ordemCtrl.formStream.update();
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (_) {
                    final mps = <MateriaPrimaModel?>[
                      MateriaPrimaModel.empty(),
                      ...FirestoreClient.materiaPrimas.data.where(
                        (e) => e.produto.id == form.produto?.id && e.status == MateriaPrimaStatus.disponivel,
                      ),
                    ];
                    return AppDropDown<MateriaPrimaModel?>(
                      disable: form.produto == null,
                      label: 'Matéria Prima',
                      item: mps.firstWhereOrNull((e) => e?.id == form.materiaPrima?.id),
                      itens: mps,
                      itemLabel: (e) => '${e!.fabricanteModel.nome} - ${e.corridaLote}',
                      onSelect: (e) {
                        form.materiaPrima = e;
                        ordemCtrl.formStream.update();
                      },
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _configExpandida ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // SEÇÃO: NA ORDEM (selecionados)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _secaoNaOrdem(OrdemCreateModel form, List<PedidoProdutoModel> naOrdem, double peso) {
    if (naOrdem.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryMain.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da seção
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryMain),
              ),
              const SizedBox(width: 8),
              Text(
                'NA ORDEM',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: AppColors.primaryMain),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${naOrdem.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryMain)),
              ),
              const Spacer(),
              // Peso total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(peso.toKg(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryMain)),
              ),
              const SizedBox(width: 6),
              // Botão limpar todos
              Tooltip(
                message: 'Remover todos',
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () {
                    form.produtos.clear();
                    ordemCtrl.formStream.update();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.playlist_remove_rounded, size: 14, color: Colors.red[400]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),

          // Lista de itens selecionados
          ...naOrdem.map((produto) => _itemSelecionado(form, produto)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _itemSelecionado(OrdemCreateModel form, PedidoProdutoModel produto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            form.produtos.removeWhere((e) => e.id == produto.id);
            ordemCtrl.formStream.update();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              // Ícone check preenchido
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 10),
              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(produto.pedido.localizador, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[800])),
                      const SizedBox(width: 6),
                      _tipoBadge(produto),
                    ]),
                    Text(
                      '${produto.cliente.nome} · ${produto.obra.descricao}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Peso
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(produto.qtde.toKg(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryMain)),
              ),
              const SizedBox(width: 6),
              // Botão remover
              Icon(Icons.close_rounded, size: 16, color: Colors.red[300]),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEÇÃO: DISPONÍVEIS (não selecionados)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _secaoDisponiveis(OrdemCreateModel form, List<PedidoProdutoModel> disponiveis, bool mpSelecionada) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: título + badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Icon(Icons.inbox_outlined, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'DISPONÍVEIS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.grey[400]),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Text('${disponiveis.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600])),
              ),
            ]),
          ),

          // Aviso: MP não selecionada
          if (!mpSelecionada)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 13, color: Colors.orange[400]),
                const SizedBox(width: 6),
                Text(
                  'Selecione a matéria prima para adicionar pedidos',
                  style: AppCss.minimumRegular.setSize(11).setColor(Colors.orange[600]!),
                ),
              ]),
            ),

          // Filtro de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 16, color: Colors.grey[350]),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: form.localizador.controller,
                    onChanged: (_) => ordemCtrl.formStream.update(),
                    onTap: () => setState(() {
                      form.localizador.controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: form.localizador.controller.value.text.length,
                      );
                    }),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Buscar por localizador...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[350]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => setState(() => _filtroExpandido = !_filtroExpandido),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _filtroExpandido ? AppColors.primaryMain.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    _filtroExpandido ? Icons.tune_rounded : Icons.sort_rounded,
                    size: 16,
                    color: _filtroExpandido ? AppColors.primaryMain : Colors.grey[400],
                  ),
                ),
              ),
            ]),
          ),

          // Ordenação expansível
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(children: [
                Expanded(child: AppDropDown<SortType>(
                  label: 'Ordenar por', item: form.sortType, itens: SortType.values,
                  itemLabel: (e) => e.name,
                  onSelect: (e) { form.sortType = e ?? SortType.alfabetic; ordemCtrl.formStream.update(); },
                )),
                const SizedBox(width: 10),
                Expanded(child: AppDropDown<SortOrder>(
                  label: 'Direção', item: form.sortOrder, itens: SortOrder.values,
                  itemLabel: (e) => e.getName(form.sortType),
                  onSelect: (e) { form.sortOrder = e ?? SortOrder.asc; ordemCtrl.formStream.update(); },
                )),
              ]),
            ),
            crossFadeState: _filtroExpandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // Divider sutil
          Divider(height: 1, thickness: 1, color: const Color(0xFFE8ECF0)),

          // Itens
          if (disponiveis.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: Column(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.green[200]),
                  const SizedBox(height: 6),
                  Text('Todos os pedidos já estão na ordem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                ]),
              ),
            )
          else
            ...disponiveis.map((produto) => _itemDisponivel(form, produto, mpSelecionada)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }



  Widget _itemDisponivel(OrdemCreateModel form, PedidoProdutoModel produto, bool mpSelecionada) {
    final habilitado = produto.isAvailable && mpSelecionada;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Opacity(
        opacity: habilitado ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: habilitado
                ? () {
                    form.produtos.add(produto);
                    ordemCtrl.formStream.update();
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEBEEF2)),
              ),
              child: Row(children: [
                // Checkbox vazio
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(produto.pedido.localizador, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        const SizedBox(width: 6),
                        _tipoBadge(produto),
                      ]),
                      Row(children: [
                        Expanded(
                          child: Text(
                            '${produto.cliente.nome} · ${produto.obra.descricao}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (produto.pedido.deliveryAt != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.event_outlined, size: 10, color: Colors.grey[350]),
                          const SizedBox(width: 2),
                          Text(produto.pedido.deliveryAt.text(), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Peso
                Text(produto.qtde.toKg(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(width: 6),
                // Ícone adicionar
                Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primaryMain.withValues(alpha: 0.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM BAR (resumo compacto)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _bottomBar(List<PedidoProdutoModel> naOrdem, double peso, OrdemCreateModel form) {
    if (form.produto == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Icon(
            naOrdem.isNotEmpty ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: naOrdem.isNotEmpty ? AppColors.primaryMain : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            naOrdem.isNotEmpty
                ? '${naOrdem.length} pedido${naOrdem.length > 1 ? 's' : ''}'
                : 'Nenhum pedido selecionado',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: naOrdem.isNotEmpty ? Colors.grey[800] : Colors.grey[400],
            ),
          ),
          if (naOrdem.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text('·', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            const SizedBox(width: 6),
            Text(peso.toKg(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryMain)),
          ],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _tipoBadge(PedidoProdutoModel produto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: produto.pedido.tipo.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        produto.pedido.tipo.label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: produto.pedido.tipo.foregroundColor),
      ),
    );
  }
}
