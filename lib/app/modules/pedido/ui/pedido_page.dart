import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/elemento/ui/elementos_tab.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pai/pai_pedido_saldo_table_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_anexos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_checks_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_comentarios_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_desc_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_entrega_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_filhos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_financ_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_producao_graph_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_bitolas_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_status_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_steps_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_tags_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_timeline_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_top_bar.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_users_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_vinculados_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_localizacao_widget.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:material_symbols_icons/symbols.dart';

enum PedidoInitReason { page, kanban, archived }

class PedidoPage extends StatefulWidget {
  final PedidoModel pedido;
  final PedidoInitReason reason;
  final Function()? onDelete;

  const PedidoPage({
    required this.pedido,
    required this.reason,
    this.onDelete,
    super.key,
  });

  @override
  State<PedidoPage> createState() => _PedidoPageState();
}

class _PedidoPageState extends State<PedidoPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late TabController _tabController;
  int _dashboardIdx = 0;
  late bool _lastShowElementos;

  bool _computeShowElementos(PedidoModel pedido) =>
      !pedido.isMestre;

  @override
  void initState() {
    super.initState();
    _lastShowElementos = _computeShowElementos(widget.pedido);
    _tabController =
        TabController(length: _lastShowElementos ? 3 : 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      pedidoCtrl.activeTabStream.add(_tabController.index);
    });
    if (widget.reason != PedidoInitReason.kanban) {
      setWebTitle('Pedido ${widget.pedido.localizador}');
    }
    pedidoCtrl.onInitPage(widget.pedido);
    notificacaoCtrl.onSetPedidoViewed(widget.pedido);
  }

  /// Recria o TabController se o estado de visibilidade da aba Elementos mudar.
  void _syncTabController(PedidoModel pedido) {
    final show = _computeShowElementos(pedido);
    if (show != _lastShowElementos) {
      _lastShowElementos = show;
      final currentIdx = _tabController.index;
      _tabController.dispose();
      _tabController =
          TabController(length: show ? 3 : 2, vsync: this);
      _tabController.index = currentIdx.clamp(0, _tabController.length - 1);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) return;
        pedidoCtrl.activeTabStream.add(_tabController.index);
      });
    }
  }

  @override
  void didUpdateWidget(PedidoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quando o Kanban troca o pedido selecionado (ex: ir para o mestre),
    // precisamos reiniciar o polling e o stream para o novo pedido
    if (oldWidget.pedido.id != widget.pedido.id) {
      pedidoCtrl.onInitPage(widget.pedido);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    pedidoCtrl.onDisposePage();
    pedidoCtrl.setPedido(null);
    elementoCtrl
        .onDispose(); // Limpa estado interno dos elementos e listener em tempo real
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool get isKanban => widget.reason == PedidoInitReason.kanban;
  bool get isArchived => widget.reason == PedidoInitReason.archived;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamOut(
      stream: pedidoCtrl.pedidoStream.listen,
      builder: (_, pedido) {
        _syncTabController(pedido);
        return isKanban
            ? _kanbanReasonWidget(pedido)
            : _pedidoReasonWidget(pedido);
      },
    );
  }

  AppScaffold _pedidoReasonWidget(PedidoModel pedido) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: PedidoTopBar(
        pedido: pedido,
        reason: widget.reason,
        onDelete: widget.onDelete,
      ),
      body: _bodyWithTabs(pedido),
    );
  }

  Widget _kanbanReasonWidget(PedidoModel pedido) {
    return Material(
        surfaceTintColor: Colors.transparent, child: _bodyWithTabs(pedido));
  }

  Widget _bodyWithTabs(PedidoModel pedido) {
    return Column(
      children: [
        if (isKanban)
          PedidoTopBar(
            pedido: pedido,
            reason: widget.reason,
            onDelete: widget.onDelete,
          ),

        // ── Abas ─────────────────────────────────────────────────────────
        Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.neutralLight)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: AppCss.minimumBold.setSize(13.5),
            unselectedLabelStyle: AppCss.minimumBold.setSize(13.5),
            labelColor: AppColors.black,
            unselectedLabelColor: AppColors.neutralMedium,
            indicatorColor: AppColors.brand,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              _tab(Symbols.space_dashboard, 'Visão geral'),
              _tab(Symbols.stacks, 'Bitolas', pedido.produtos.length),
              if (_lastShowElementos)
                _tab(Symbols.layers, 'Elementos', pedido.elementos.length),
            ],
          ),
        ),

        // ── Conteúdo das abas ─────────────────────────────────────────────
        Expanded(
          child: Container(
            color: AppColors.neutralLightest,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Aba 1: Dashboard
                _detalhesBody(pedido),

                // Aba 2: Produtos
                _produtosBody(pedido),

                // Aba 3: Elementos
                if (_lastShowElementos)
                  _elementosBody(pedido),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Aba com ícone, nome e contagem opcional
  Tab _tab(IconData icon, String label, [int? count]) => Tab(
        height: 46,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(label),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.neutralLightest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(AppColors.neutralDark),
                ),
              ),
            ],
          ],
        ),
      );

  // ─── DESIGN SYSTEM: SECTION CARD ─────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: AppCss.minimumBold.setSize(14)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: contentPadding ?? const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESUMO NUMÉRICO (topo da Visão geral) ───────────────────────────────
  Widget _resumoKpis(PedidoModel pedido) {
    final kpis = <Widget>[
      _kpi(
        titulo: 'Peso total',
        valor: pedido.getQtdeTotal().toKg(),
        legenda: pedido.produtos.length == 1
            ? '1 bitola'
            : '${pedido.produtos.length} bitolas',
      ),
      _kpi(
        titulo: 'Corte e dobra',
        valor: pedido.isAguardandoEntradaProducao()
            ? '—'
            : '${(pedido.getPrcntgPronto() * 100).percent}%',
        legenda: pedido.isAguardandoEntradaProducao()
            ? 'aguardando entrada na produção'
            : 'pronto',
        barra: pedido.isAguardandoEntradaProducao()
            ? null
            : [
                (pedido.getPrcntgPronto(), AppColors.statusPronto),
                (pedido.getPrcntgProduzindo(), AppColors.statusProduzindo),
              ],
      ),
      if (pedido.tipo == PedidoTipo.cda && _getCDATotalKg(pedido) > 0)
        _kpiArmacao(pedido),
      _kpiEntrega(pedido),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final porLinha = constraints.maxWidth >= 900
          ? kpis.length
          : constraints.maxWidth >= 520
              ? 2
              : 1;
      const gap = 12.0;
      final largura =
          (constraints.maxWidth - gap * (porLinha - 1)) / porLinha;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: kpis.map((k) => SizedBox(width: largura, child: k)).toList(),
      );
    });
  }

  Widget _kpi({
    required String titulo,
    required String valor,
    required String legenda,
    Color? corLegenda,
    List<(double, Color)>? barra,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: AppCss.minimumBold
                .setSize(11)
                .setColor(AppColors.neutralMedium)
                .copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Text(valor, style: AppCss.largeBold.setSize(21)),
          if (barra != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Container(
                  color: AppColors.neutralLight,
                  child: Row(
                    children: [
                      for (final (pct, cor) in barra)
                        if (pct > 0)
                          Flexible(
                            flex: (pct * 1000).round().clamp(1, 1000),
                            child: Container(color: cor),
                          ),
                      if (barra.fold(0.0, (a, b) => a + b.$1) < 0.999)
                        Flexible(
                          flex: ((1 - barra.fold(0.0, (a, b) => a + b.$1)) *
                                  1000)
                              .round()
                              .clamp(1, 1000),
                          child: const SizedBox.expand(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            legenda,
            style: AppCss.minimumRegular
                .setSize(12)
                .setColor(corLegenda ?? AppColors.neutralMedium)
                .copyWith(
                    fontWeight:
                        corLegenda != null ? FontWeight.w600 : FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _kpiArmacao(PedidoModel pedido) {
    final resumo = pedido.armacaoResumo;
    final total = _getCDATotalKg(pedido);
    final details = resumo['details'] as Map<String, dynamic>? ?? {};
    final prontoPeso = ((details['pronto']?['peso'] ?? 0) as num).toDouble();
    final armandoPeso =
        ((details['armando']?['peso'] ?? 0) as num).toDouble();
    final totalQtd = ((resumo['total_qtd'] ?? 0) as num).toInt();
    final prontoQtd = ((details['pronto']?['qtd'] ?? 0) as num).toInt();
    final pct = total > 0 ? prontoPeso / total : 0.0;
    return _kpi(
      titulo: 'Armação',
      valor: '${(pct * 100).percent}%',
      legenda: '$prontoQtd de $totalQtd peças prontas',
      barra: [
        (pct, AppColors.statusPronto),
        (total > 0 ? armandoPeso / total : 0.0, AppColors.statusProduzindo),
      ],
    );
  }

  Widget _kpiEntrega(PedidoModel pedido) {
    final entrega = pedido.deliveryAt;
    if (entrega == null) {
      return _kpi(titulo: 'Entrega', valor: '—', legenda: 'sem data definida');
    }
    final hoje = DateTime.now();
    final dias = DateTime(entrega.year, entrega.month, entrega.day)
        .difference(DateTime(hoje.year, hoje.month, hoje.day))
        .inDays;
    String legenda;
    Color? cor;
    if (pedido.isEntregue) {
      legenda = 'entregue';
    } else if (dias < 0) {
      legenda = '${-dias == 1 ? '1 dia' : '${-dias} dias'} de atraso';
      cor = AppColors.statusCritico;
    } else if (dias == 0) {
      legenda = 'hoje';
      cor = const Color(0xFFB45309);
    } else {
      legenda = 'em ${dias == 1 ? '1 dia' : '$dias dias'}';
    }
    return _kpi(
      titulo: 'Entrega',
      valor: entrega.ddMMyyyy(),
      legenda: legenda,
      corLegenda: cor,
    );
  }

  Widget _detalhesBody(PedidoModel pedido) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final checksFeitos = pedido.checks.where((e) => e.isCheck).length;
        final items = [
          _SidebarItemData(Symbols.assignment, 'Identificação', 0),
          _SidebarItemData(Symbols.monitoring, 'Acompanhamento', 1),
          _SidebarItemData(Symbols.attach_file, 'Anexos', 2,
              contador: pedido.archives.isEmpty
                  ? null
                  : '${pedido.archives.length}'),
          _SidebarItemData(Symbols.checklist, 'Checklist', 3,
              contador: pedido.checks.isEmpty
                  ? null
                  : '$checksFeitos/${pedido.checks.length}'),
          _SidebarItemData(Symbols.chat_bubble, 'Comentários', 4,
              contador: pedido.comments.isEmpty
                  ? null
                  : '${pedido.comments.length}'),
          _SidebarItemData(Symbols.location_on, 'Localização', 5),
          _SidebarItemData(Symbols.history, 'Histórico', 6),
        ];

        if (isMobile) {
          return Column(
            children: [
              _sidebarHorizontal(
                currentIndex: _dashboardIdx,
                items: items,
                onTap: (i) => setState(() => _dashboardIdx = i),
              ),
              Expanded(
                child: Container(
                  color: AppColors.neutralLightest,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_dashboardIdx),
                      child: _dashboardContent(pedido),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            _sidebar(
              currentIndex: _dashboardIdx,
              items: items,
              onTap: (i) => setState(() => _dashboardIdx = i),
            ),
            Expanded(
              child: Container(
                color: AppColors.neutralLightest,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_dashboardIdx),
                    child: _dashboardContent(pedido),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Botão de relatório PDF (contorno, com rótulo curto). Com [altura],
  /// acompanha os botões das barras de ação (36 px)
  Widget _botaoRelatorio(
    PedidoModel pedido, {
    required String label,
    required VoidCallback onTap,
    double? altura,
  }) {
    final raio = altura == null ? 7.0 : 10.0;
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(raio),
        child: Container(
          height: altura,
          padding: altura == null
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(raio),
            border: Border.all(color: AppColors.neutralLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  size: 15, color: AppColors.neutralDark),
              const SizedBox(width: 5),
              Text('Relatório',
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(AppColors.neutralDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardContent(PedidoModel pedido) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 0: Identificação ──
        if (_dashboardIdx == 0) ...[
          // ── Link para Pedido Mestre (se parcial) ──
          if (pedido.isParcial)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  // BackendClient.pedidos busca em ambas as listas: ativos e arquivados
                  final mestre = BackendClient.pedidos.getById(pedido.pai!);
                  if (mestre.localizador.startsWith('NOTFOUND')) return;
                  if (isKanban) {
                    // 1. Trava o stream PRIMEIRO (evita race condition com _listenGlobalPedidos)
                    pedidoCtrl.onInitPage(mestre);
                    // 2. Atualiza o Kanban (vai disparar didUpdateWidget → onInitPage novamente, é idempotente)
                    kanbanCtrl.setPedido(mestre);
                  } else {
                    push(context, PedidoPage(pedido: mestre, reason: widget.reason));
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_left_rounded,
                          size: 18, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ir para o Pedido Mestre',
                          style: AppCss.minimumBold.copyWith(
                            color: const Color(0xFF1D4ED8),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: Color(0xFF1D4ED8)),
                    ],
                  ),
                ),
              ),
            ),
          _resumoKpis(pedido),
          const H(14),
          _sectionCard(
            icon: Symbols.flag,
            title: 'Situação',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PedidoUsersWidget(pedido),
                const SizedBox(width: 8),
                _botaoRelatorio(
                  pedido,
                  label: 'Relatório de Pedido',
                  onTap: () => pedidoCtrl.onGeneratePDF(pedido,
                      type: RelatorioPedidoTipo.geral),
                ),
              ],
            ),
            children: [
              PedidoStatusWidget(pedido),
              const H(12),
              PedidoStepsWidget(pedido),
              const H(12),
              PedidoTagsWidget(pedido),
            ],
          ),
          _sectionCard(
            icon: Symbols.apartment,
            title: 'Cliente, obra e entrega',
            children: [PedidoDescWidget(pedido)],
          ),
          if (pedido.instrucoesEntrega.isNotEmpty ||
              pedido.instrucoesFinanceiras.isNotEmpty)
            _sectionCard(
              icon: Symbols.local_shipping,
              title: 'Instruções',
              children: [
                if (pedido.instrucoesEntrega.isNotEmpty)
                  PedidoEntregaWidget(pedido),
                if (pedido.instrucoesEntrega.isNotEmpty &&
                    pedido.instrucoesFinanceiras.isNotEmpty)
                  const H(12),
                if (pedido.instrucoesFinanceiras.isNotEmpty)
                  PedidoFinancWidget(pedido),
              ],
            ),
        ],

        // ── 1: Acompanhamento (Gráficos de Produção) ──
        if (_dashboardIdx == 1) ...[
          // ── Card: Corte & Dobra ──
          if (pedido.isAguardandoEntradaProducao())
            _aguardandoProducaoCard()
          else
            _producaoCard(
              icon: Symbols.content_cut,
              title: 'Corte e dobra',
              accentColor: AppColors.neutralDark,
              totalKg: pedido.getQtdeTotal(),
              data: _buildCDGraphData(pedido),
            ),

          // ── Card: Armação (CDA) — aparece assim que houver armação,
          // mesmo com o corte ainda aguardando ──
          if (pedido.tipo == PedidoTipo.cda &&
              (!pedido.isAguardandoEntradaProducao() ||
                  _getCDATotalKg(pedido) > 0)) ...[
            const H(16),
            _producaoCard(
              icon: Symbols.construction,
              title: 'Armação',
              accentColor: AppColors.neutralDark,
              totalKg: _getCDATotalKg(pedido),
              data: _buildCDAGraphData(pedido),
            ),
          ],
          // ── Mestre: apenas informativo ──
          if (pedido.isMestre)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.statusAtencao.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 20, color: Color(0xFF92400E)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Este pedido é Mestre — a produção acontece nos pedidos parciais.',
                      style: AppCss.mediumRegular.copyWith(
                        color: const Color(0xFF92400E),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // ── 2: Anexos ──
        if (_dashboardIdx == 2)
          _painel(PedidoAnexosWidget(pedido)),

        // ── 3: Checklist ──
        if (_dashboardIdx == 3)
          _painel(PedidoChecksWidget(pedido)),

        // ── 4: Comentários ──
        if (_dashboardIdx == 4)
          _painel(PedidoCommentsWidget(pedido)),

        // ── 5: Localização ──
        if (_dashboardIdx == 5)
          _painel(PedidoLocalizacaoWidget(pedido)),

        // ── 6: Histórico ──
        if (_dashboardIdx == 6)
          _painel(
            pedido.histories.isNotEmpty
                ? PedidoTimelineWidget(pedido: pedido)
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhum registro no histórico.',
                      style: AppCss.minimumRegular
                          .setSize(13)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
          ),
      ],
    );
  }

  /// Fundo branco para as seções que já vêm prontas (anexos, checklist...),
  /// no mesmo padrão dos cartões da Identificação
  Widget _painel(Widget child) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: child,
    );
  }

  Widget _produtosBody(PedidoModel pedido) {
    final relatorio = _botaoRelatorio(
      pedido,
      label: pedido.isMestre ? 'Relatório de Parciais' : 'Relatório de Pedido',
      onTap: () => pedido.isMestre
          ? pedidoCtrl.onGeneratePDF(pedido,
              type: RelatorioPedidoTipo.parciais)
          : pedidoCtrl.onGeneratePDF(pedido,
              type: RelatorioPedidoTipo.geral),
    );
    return Container(
      color: AppColors.neutralLightest,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Pedido Mestre: tabela de saldo + cards dos parciais ──
          if (pedido.pedidosFilhos.isNotEmpty) ...[
            Align(alignment: Alignment.centerRight, child: relatorio),
            const H(12),
            PaiPedidoSaldoTableWidget(
              mestre: pedido,
              // Usa BackendClient (Supabase) para garantir todos os filhos —
              // getPedidosFilhos() usa FirestoreClient (legado) e pode retornar
              // lista incompleta quando os filhos não estão no cache local.
              filhos: pedido.pedidosFilhos
                  .map((id) => BackendClient.pedidos.getById(id))
                  .where((f) => !f.localizador.startsWith('NOTFOUND'))
                  .toList(),
            ),
            const H(16),
            PedidoFilhosWidget(
                pedido: pedido, filhos: pedido.getTodosFilhos()),
          ],

          // ── Produtos (Pedido Normal ou Parcial): relatório no cabeçalho ──
          if (pedido.pedidosFilhos.isEmpty) ...[
            PedidoProdutosWidget(pedido, acao: relatorio),
            if (pedido.getPedidosVinculados().isNotEmpty) ...[
              const H(16),
              PedidoVinculadosWidget(
                  pedido: pedido,
                  vinculados: pedido.getPedidosVinculados()),
            ],
          ],
        ],
      ),
    );
  }

  Widget _elementosBody(PedidoModel pedido) {
    return Container(
      color: AppColors.neutralLightest,
      child: ElementosTab(
        pedido: pedido,
        // Relatório entra na barra de ações, junto do Comparativo
        acaoExtra: _botaoRelatorio(
          pedido,
          label: 'Relatório de Elementos',
          altura: 36,
          onTap: () => elementoCtrl.onGeneratePDF(pedido),
        ),
      ),
    );
  }

  Widget _sidebar({
    required int currentIndex,
    required List<_SidebarItemData> items,
    required Function(int) onTap,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.neutralLight)),
      ),
      child: ListView(
        children: items.map((item) {
          final ativo = currentIndex == item.index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: InkWell(
              onTap: () => onTap(item.index),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: ativo ? AppColors.brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 19,
                      color: ativo ? AppColors.brand : AppColors.neutralDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppCss.minimumRegular.setSize(13.5).copyWith(
                              color: AppColors.black,
                              fontWeight:
                                  ativo ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                    if (item.contador != null)
                      Text(
                        item.contador!,
                        style: AppCss.minimumRegular
                            .setSize(11.5)
                            .setColor(AppColors.neutralMedium),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SIDEBAR HORIZONTAL (MOBILE) ──────────────────────────────────────────
  Widget _sidebarHorizontal({
    required int currentIndex,
    required List<_SidebarItemData> items,
    required Function(int) onTap,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutralLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: items.map((item) {
            final ativo = currentIndex == item.index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
              child: InkWell(
                onTap: () => onTap(item.index),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ativo ? AppColors.brandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: ativo ? AppColors.brand : AppColors.neutralLight),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 16,
                          color:
                              ativo ? AppColors.brand : AppColors.neutralDark),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: AppCss.minimumBold.setSize(12).setColor(
                            ativo ? AppColors.black : AppColors.neutralDark),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── CORTE E DOBRA AINDA NÃO COMEÇOU ──────────────────────────────────────
  Widget _aguardandoProducaoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(Symbols.content_cut,
                    size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Text('Corte e dobra', style: AppCss.minimumBold.setSize(14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(Symbols.hourglass_empty,
                    size: 36, color: AppColors.neutralMedium),
                const H(10),
                Text(
                  'Aguardando entrada na produção',
                  style: AppCss.mediumRegular
                      .setSize(14)
                      .setColor(AppColors.neutralMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD DE PRODUÇÃO ESTILIZADO ──────────────────────────────────────────
  Widget _producaoCard({
    required IconData icon,
    required String title,
    required Color accentColor,
    required double totalKg,
    required List<ProducaoGraphData> data,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: AppCss.minimumBold.setSize(14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neutralLightest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    totalKg.toKg(),
                    style: AppCss.minimumBold.setSize(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Barra de progresso linear ──
          if (data.isNotEmpty)
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Row(
                  children: data.map((d) {
                    return Expanded(
                      flex: (d.percentual * 1000).round().clamp(1, 1000),
                      child: Container(color: d.color),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── Donuts de progresso ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: PedidoProducaoGraphWidget(
              totalKg: totalKg,
              data: data,
            ),
          ),

          // ── Legenda com peso ──
          if (data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: data.map((d) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: d.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        d.pesoKg.toKg(),
                        style: AppCss.minimumRegular.copyWith(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─── DADOS PARA O GRÁFICO DE PRODUÇÃO CD ─────────────────────────────────
  List<ProducaoGraphData> _buildCDGraphData(PedidoModel pedido) {
    final total = pedido.getQtdeTotal();
    if (total <= 0) return [];

    final aguardando = pedido.getQtdeAguardandoProducao();
    final produzindo = pedido.getQtdeProduzindo();
    final pronto = pedido.getQtdePronto();

    return [
      if (aguardando > 0)
        ProducaoGraphData(
          label: 'Aguardando',
          pesoKg: aguardando,
          percentual: aguardando / total,
          color: PedidoBitolaStatus.aguardandoProducao.color,
        ),
      if (produzindo > 0)
        ProducaoGraphData(
          label: 'Produzindo',
          pesoKg: produzindo,
          percentual: produzindo / total,
          color: PedidoBitolaStatus.produzindo.color,
        ),
      if (pronto > 0)
        ProducaoGraphData(
          label: 'Pronto',
          pesoKg: pronto,
          percentual: pronto / total,
          color: PedidoBitolaStatus.pronto.color,
        ),
    ];
  }

  // ─── DADOS PARA O GRÁFICO DE PRODUÇÃO CDA ────────────────────────────────
  List<ProducaoGraphData> _buildCDAGraphData(PedidoModel pedido) {
    final resumo = pedido.armacaoResumo;
    final totalPeso = ((resumo['total_peso'] ?? 0) as num).toDouble();
    if (totalPeso <= 0) return [];

    final details = resumo['details'] as Map<String, dynamic>? ?? {};

    final aguardandoPeso =
        ((details['aguardando']?['peso'] ?? 0) as num).toDouble();
    final armandoPeso = ((details['armando']?['peso'] ?? 0) as num).toDouble();
    final prontoPeso = ((details['pronto']?['peso'] ?? 0) as num).toDouble();

    return [
      if (aguardandoPeso > 0)
        ProducaoGraphData(
          label: 'Aguardando',
          pesoKg: aguardandoPeso,
          percentual: totalPeso > 0 ? aguardandoPeso / totalPeso : 0,
          color: AppColors.statusAguardando,
        ),
      if (armandoPeso > 0)
        ProducaoGraphData(
          label: 'Armando',
          pesoKg: armandoPeso,
          percentual: totalPeso > 0 ? armandoPeso / totalPeso : 0,
          color: AppColors.statusProduzindo,
        ),
      if (prontoPeso > 0)
        ProducaoGraphData(
          label: 'Pronto',
          pesoKg: prontoPeso,
          percentual: totalPeso > 0 ? prontoPeso / totalPeso : 0,
          color: AppColors.statusPronto,
        ),
    ];
  }

  double _getCDATotalKg(PedidoModel pedido) {
    return ((pedido.armacaoResumo['total_peso'] ?? 0) as num).toDouble();
  }
}

class _SidebarItemData {
  final IconData icon;
  final String label;
  final int index;

  /// Ex.: "3" anexos, "2/5" checklist — mostra onde há conteúdo
  final String? contador;

  _SidebarItemData(this.icon, this.label, this.index, {this.contador});
}
