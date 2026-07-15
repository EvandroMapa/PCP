import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
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

class _OrdemCreatePageState extends State<OrdemCreatePage>
    with SingleTickerProviderStateMixin {
  bool _filtroExpandido = false;
  late bool _configExpandida;
  late TabController _tabController;

  // Snapshot do estado original para detectar mudanças
  Set<String> _produtosOriginais = {};
  String? _materiaPrimaOriginal;

  bool get _houveMudanca {
    if (!ordemCtrl.form.isEdit) return true; // criação sempre pergunta
    final produtosAtuais = ordemCtrl.form.produtos.map((e) => e.id).toSet();
    final mpAtual = ordemCtrl.form.materiaPrima?.id;
    return !_produtosOriginais.containsAll(produtosAtuais) ||
        !produtosAtuais.containsAll(_produtosOriginais) ||
        mpAtual != _materiaPrimaOriginal;
  }

  @override
  void initState() {
    setWebTitle(widget.ordem != null ? 'Editar Ordem' : 'Nova Ordem');
    ordemCtrl.onInitCreatePage(widget.ordem);
    // Começa colapsada se editando (já tem produto), expandida se criando
    _configExpandida = widget.ordem == null;
    // Salva snapshot do estado original
    if (widget.ordem != null) {
      _produtosOriginais = widget.ordem!.produtos.map((e) => e.id).toSet();
      _materiaPrimaOriginal = widget.ordem!.materiaPrima?.id;
    }
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (!_houveMudanca) {
              pop(context);
              return;
            }
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
    final todosDisponiveis = form.produto != null
        ? ordemCtrl.getPedidosPorProduto(form.produto!, ordem: widget.ordem)
        : <PedidoBitolaModel>[];
    final idsNaOrdem = form.produtos.map((e) => e.id).toSet();
    final naOrdem =
        todosDisponiveis.where((p) => idsNaOrdem.contains(p.id)).toList();
    final disponiveis =
        todosDisponiveis.where((p) => !idsNaOrdem.contains(p.id)).toList();
    final pesoNaOrdem = naOrdem.fold<double>(0, (s, p) => s + p.qtde);

    final mpSelecionada = form.materiaPrima != null &&
        form.materiaPrima!.id != 'register_unavailable';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Column(
          children: [
            // ── Configuração (sempre visível no topo) ──
            _secaoConfiguracao(form),
            Expanded(
              child: _conteudoPrincipal(
                form: form,
                isMobile: isMobile,
                disponiveis: disponiveis,
                naOrdem: naOrdem,
                mpSelecionada: mpSelecionada,
                pesoNaOrdem: pesoNaOrdem,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _conteudoPrincipal({
    required OrdemCreateModel form,
    required bool isMobile,
    required List<PedidoBitolaModel> disponiveis,
    required List<PedidoBitolaModel> naOrdem,
    required bool mpSelecionada,
    required double pesoNaOrdem,
  }) {
    if (form.produto == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 12),
              Text(
                'Selecione a bitola para começar',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      // ── Mobile: TabBar com duas abas ──
      return Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryMain,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: AppColors.primaryMain,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 15),
                      const SizedBox(width: 6),
                      Text('DISPONÍVEIS (${disponiveis.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text('NA ORDEM (${naOrdem.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _colunaDisponiveis(form, disponiveis, mpSelecionada),
                _colunaOrdem(form, naOrdem, pesoNaOrdem),
              ],
            ),
          ),
        ],
      );
    }

    // ── Desktop: Duas colunas lado a lado ──
    return Row(
      children: [
        Expanded(
          child: _colunaDisponiveis(form, disponiveis, mpSelecionada),
        ),
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(1, 0),
              ),
            ],
          ),
        ),
        Expanded(
          child: _colunaOrdem(form, naOrdem, pesoNaOrdem),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLUNA: NA ORDEM (esquerda)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _colunaOrdem(
      OrdemCreateModel form, List<PedidoBitolaModel> naOrdem, double peso) {
    return Column(
      children: [
        // Header da coluna
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: naOrdem.isNotEmpty ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'NA ORDEM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: naOrdem.isNotEmpty ? Colors.grey[700] : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: naOrdem.isNotEmpty
                      ? Colors.grey[100]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${naOrdem.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: naOrdem.isNotEmpty ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
              const Spacer(),
              // Botão remover todos
              if (naOrdem.isNotEmpty)
                Tooltip(
                  message: 'Remover todos',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: () {
                      final bloqueados = form.produtos
                          .where((p) =>
                              p.status.status == PedidoBitolaStatus.produzindo ||
                              p.status.status == PedidoBitolaStatus.pronto)
                          .length;
                      form.produtos.removeWhere((p) =>
                          p.status.status != PedidoBitolaStatus.produzindo &&
                          p.status.status != PedidoBitolaStatus.pronto);
                      ordemCtrl.formStream.update();
                      if (bloqueados > 0) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            icon: Icon(Icons.info_outline,
                                size: 40, color: Colors.orange[700]),
                            title: const Text('Itens mantidos na ordem'),
                            content: Text(
                              '$bloqueados ${bloqueados == 1 ? 'item foi mantido pois já está' : 'itens foram mantidos pois já estão'} em produção ou prontos e não podem ser removidos.',
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryMain),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendi',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 14, color: Colors.red[400]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Somatório destacado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.07),
            border: Border(
              bottom: BorderSide(color: const Color(0xFF1E293B).withValues(alpha: 0.10)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.scale_rounded, size: 14, color: const Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                'Total:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                peso.toKg(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        // Lista ou vazio
        Expanded(
          child: naOrdem.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[250]),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum pedido na ordem',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '← Clique nos itens disponíveis',
                          style: TextStyle(fontSize: 11, color: Colors.grey[350]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    ...naOrdem.map((produto) => _itemSelecionado(form, produto)),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLUNA: DISPONÍVEIS (esquerda)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _colunaDisponiveis(OrdemCreateModel form,
      List<PedidoBitolaModel> disponiveis, bool mpSelecionada) {
    final pesoDisponivel = disponiveis.fold<double>(0, (s, p) => s + p.qtde);

    return Column(
      children: [
        // Header da coluna
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: disponiveis.isNotEmpty ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'DISPONÍVEIS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: disponiveis.isNotEmpty ? Colors.grey[700] : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: disponiveis.isNotEmpty
                      ? Colors.grey[100]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${disponiveis.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: disponiveis.isNotEmpty ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Somatório disponível
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.07),
            border: Border(
              bottom: BorderSide(color: const Color(0xFF1E293B).withValues(alpha: 0.10)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.scale_rounded, size: 14, color: const Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                'Total:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                pesoDisponivel.toKg(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // Aviso: MP não selecionada
        if (!mpSelecionada)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.20), width: 1),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selecione a matéria prima para adicionar pedidos',
                  style: AppCss.minimumRegular
                      .setSize(11)
                      .setColor(Colors.orange[700]!),
                ),
              ),
            ]),
          ),

        // Barra de busca + ordenação
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              // Campo de busca
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search_rounded,
                      size: 18,
                      color: AppColors.primaryMain.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: form.localizador.controller,
                      onChanged: (_) => ordemCtrl.formStream.update(),
                      onTap: () => setState(() {
                        form.localizador.controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset:
                              form.localizador.controller.value.text.length,
                        );
                      }),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800]),
                      decoration: InputDecoration(
                        hintText: 'Buscar por localizador...',
                        hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[350]),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  // Botão ordenação
                  InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: () =>
                        setState(() => _filtroExpandido = !_filtroExpandido),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _filtroExpandido
                            ? AppColors.primaryMain.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        _filtroExpandido
                            ? Icons.tune_rounded
                            : Icons.sort_rounded,
                        size: 16,
                        color: _filtroExpandido
                            ? AppColors.primaryMain
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ]),
              ),

              // Ordenação expansível
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(
                        child: AppDropDown<SortType>(
                      label: 'Ordenar por',
                      item: form.sortType,
                      itens: SortType.values,
                      itemLabel: (e) => e.name,
                      onSelect: (e) {
                        form.sortType = e ?? SortType.alfabetic;
                        ordemCtrl.formStream.update();
                      },
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: AppDropDown<SortOrder>(
                      label: 'Direção',
                      item: form.sortOrder,
                      itens: SortOrder.values,
                      itemLabel: (e) => e.getName(form.sortType),
                      onSelect: (e) {
                        form.sortOrder = e ?? SortOrder.asc;
                        ordemCtrl.formStream.update();
                      },
                    )),
                  ]),
                ),
                crossFadeState: _filtroExpandido
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        Divider(height: 1, thickness: 1, color: const Color(0xFFE8ECF0)),

        // Lista de itens
        Expanded(
          child: disponiveis.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 40, color: Colors.green[200]),
                        const SizedBox(height: 10),
                        Text(
                          'Todos na ordem',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    ...disponiveis.map(
                        (produto) => _itemDisponivel(form, produto, mpSelecionada)),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 16, color: AppColors.primaryMain),
                  const SizedBox(width: 8),
                  Text('Configuração',
                      style: AppCss.minimumBold.setSize(13)),
                  const Spacer(),
                  // Resumo compacto quando colapsado
                  if (!_configExpandida && temProduto) ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        form.produto!.descricao,
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(AppColors.primaryMain),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (temMP) ...[
                      const SizedBox(width: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          form.materiaPrima!.corridaLote,
                          style: AppCss.minimumBold
                              .setSize(10)
                              .setColor(Colors.orange[700]!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (form.equipamento != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          form.equipamento!.descricao,
                          style: AppCss.minimumBold
                              .setSize(10)
                              .setColor(Colors.teal[700]!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _configExpandida ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: Colors.grey[400]),
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
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: const Color(0xFFEEF1F5)),
                  const SizedBox(height: 12),
                  AppDropDown<BitolaModel?>(
                    disable: form.isEdit && form.produtos.isNotEmpty,
                    label: 'Bitola',
                    item: form.produto,
                    itens: FirestoreClient.bitolas.data.toList()
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
                        (e) =>
                            e.produto.id == form.produto?.id &&
                            e.status == MateriaPrimaStatus.disponivel,
                      ),
                    ];
                    return AppDropDown<MateriaPrimaModel?>(
                      disable: form.produto == null,
                      label: 'Matéria Prima',
                      item: mps.firstWhereOrNull(
                          (e) => e?.id == form.materiaPrima?.id),
                      itens: mps,
                      itemLabel: (e) =>
                          '${e!.fabricanteModel.nome} - ${e.corridaLote}',
                      onSelect: (e) {
                        form.materiaPrima = e;
                        ordemCtrl.formStream.update();
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  AppDropDown<EquipamentoModel?>(
                    label: 'Equipamento',
                    item: form.equipamento,
                    itens: FirestoreClient.equipamentos.data.toList(),
                    itemLabel: (e) => e!.label,
                    onSelect: (e) {
                      form.equipamento = e;
                      ordemCtrl.formStream.update();
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: _configExpandida
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ITEM SELECIONADO (Na Ordem)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _itemSelecionado(OrdemCreateModel form, PedidoBitolaModel produto) {
    final jaProduzido =
        produto.status.status == PedidoBitolaStatus.produzindo ||
            produto.status.status == PedidoBitolaStatus.pronto;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (jaProduzido) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  icon: Icon(Icons.info_outline,
                      size: 40, color: Colors.orange[700]),
                  title: const Text('Item não pode ser removido'),
                  content: Text(
                    'Este item já está "${produto.status.status.label}" e não pode ser retirado da ordem.\n\nSe necessário, cancele a produção antes de editar a ordem.',
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMain),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              return;
            }
            form.produtos.removeWhere((e) => e.id == produto.id);
            ordemCtrl.formStream.update();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: jaProduzido ? Colors.grey[50] : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: jaProduzido
                    ? Colors.grey.withValues(alpha: 0.25)
                    : AppColors.primaryMain.withValues(alpha: 0.18),
              ),
            ),
            child: Row(children: [
              // Ícone: cadeado se bloqueado, check se normal
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: jaProduzido
                      ? Colors.grey[300]
                      : AppColors.primaryMain,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  jaProduzido ? Icons.lock_rounded : Icons.check_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(produto.pedido.localizador,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800]),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      _tipoBadge(produto),
                      const SizedBox(width: 4),
                      _statusBadge(produto.status.status),
                    ]),
                    if (produto.pedido.deliveryAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          Icon(Icons.event_outlined,
                              size: 13, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Entrega: ${produto.pedido.deliveryAt.text()}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700]),
                          ),
                        ]),
                      ),
                    Text(
                      '${produto.obra.descricao} - ${produto.pedido.descricao}',
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Peso
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: jaProduzido
                      ? Colors.grey.withValues(alpha: 0.08)
                      : AppColors.primaryMain.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  produto.qtde.toKg(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: jaProduzido
                        ? Colors.grey[500]
                        : AppColors.primaryMain,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Ícone: bloqueado ou remover
              Icon(
                jaProduzido
                    ? Icons.lock_outline_rounded
                    : Icons.close_rounded,
                size: 16,
                color:
                    jaProduzido ? Colors.grey[350] : Colors.red[300],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ITEM DISPONÍVEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _itemDisponivel(OrdemCreateModel form, PedidoBitolaModel produto,
      bool mpSelecionada) {
    final habilitado = produto.isAvailable && mpSelecionada;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEBEEF2)),
              ),
              child: Row(children: [
                // Checkbox vazio
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(produto.pedido.localizador,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800]),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _tipoBadge(produto),
                        const SizedBox(width: 4),
                        _statusBadge(produto.status.status),
                      ]),
                      if (produto.pedido.deliveryAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(children: [
                            Icon(Icons.event_outlined,
                                size: 13, color: Colors.orange[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Entrega: ${produto.pedido.deliveryAt.text()}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700]),
                            ),
                          ]),
                        ),
                      Text(
                        '${produto.obra.descricao} - ${produto.pedido.descricao}',
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Peso
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    produto.qtde.toKg(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Ícone adicionar
                Icon(Icons.add_circle_outline_rounded,
                    size: 18,
                    color: AppColors.primaryMain.withValues(alpha: 0.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _tipoBadge(PedidoBitolaModel produto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: produto.pedido.tipo.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        produto.pedido.tipo.label,
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: produto.pedido.tipo.foregroundColor),
      ),
    );
  }

  Widget _statusBadge(PedidoBitolaStatus status) {
    final Color cor;
    final Color corFundo;
    final IconData icone;

    switch (status) {
      case PedidoBitolaStatus.pronto:
        cor = const Color(0xFF16A34A);       // verde
        corFundo = const Color(0xFFDCFCE7);
        icone = Icons.check_circle_rounded;
        break;
      case PedidoBitolaStatus.produzindo:
        cor = const Color(0xFFEA580C);       // laranja
        corFundo = const Color(0xFFFFF7ED);
        icone = Icons.precision_manufacturing_rounded;
        break;
      default:
        cor = const Color(0xFF2563EB);       // azul
        corFundo = const Color(0xFFEFF6FF);
        icone = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cor.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 10, color: cor),
          const SizedBox(width: 3),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
