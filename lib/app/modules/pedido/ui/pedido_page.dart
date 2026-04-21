import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/elemento/ui/elementos_tab.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
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
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_produtos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_status_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_steps_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_tags_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_timeline_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_top_bar.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_users_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_vinculados_widget.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';

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
      usuario.temAcessoElementos && !pedido.isMestre;

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

        // ── TabBar ───────────────────────────────────────────────────────
        Container(
          width: double.maxFinite,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.neutralLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: AppCss.mediumBold.copyWith(fontSize: 13),
              unselectedLabelStyle: AppCss.mediumRegular.copyWith(fontSize: 13),
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.neutralDark,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent, // remove a linha nativa
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primaryMain,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primaryMain.withValues(alpha: 0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4),
                ],
              ),
              tabs: [
                Tab(text: pedido.isMestre ? 'INFORMAÇÕES GERAIS' : 'DASHBOARD'),
                const Tab(text: 'PRODUTOS'),
                if (_lastShowElementos) const Tab(text: 'ELEMENTOS'),
              ],
            ),
          ),
        ),

        // ── Conteúdo das abas ─────────────────────────────────────────────
        Expanded(
          child: Container(
            color: const Color(0xFFE5E9EE),
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

  // ─── DESIGN SYSTEM: SECTION CARD ─────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? accentColor,
    Widget? trailing,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final color = accentColor ?? AppColors.primaryMain;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho da seção ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom:
                    BorderSide(color: color.withValues(alpha: 0.08), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppCss.mediumBold.copyWith(
                      fontSize: 13,
                      color: color.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          // ── Corpo da seção ──
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

  Widget _detalhesBody(PedidoModel pedido) {
    return Row(
      children: [
        _sidebar(
          currentIndex: _dashboardIdx,
          items: [
            _SidebarItemData(
                Icons.assignment_outlined, 'Identificação', 0),
            _SidebarItemData(
                Icons.analytics_outlined, 'Acompanhamento', 1),
            _SidebarItemData(Icons.attach_file_rounded, 'Anexos', 2),
            _SidebarItemData(Icons.checklist_rounded, 'Checklist', 3),
            _SidebarItemData(
                Icons.chat_bubble_outline_rounded, 'Comentários', 4),
            _SidebarItemData(Icons.timeline_rounded, 'Histórico', 5),
          ],
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

  /// Botão flutuante de relatório — aparece no canto superior direito de cada aba
  Widget _botaoRelatorio(
    PedidoModel pedido, {
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryMain.withValues(alpha: 0.20),
            ),
          ),
          child: Icon(Icons.picture_as_pdf_outlined,
              size: 14, color: AppColors.primaryMain),
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
                  final mestre = FirestoreClient.pedidos.getById(pedido.pai!);
                  if (isKanban) {
                    // No Kanban: troca o pedido selecionado → dispara didUpdateWidget
                    kanbanCtrl.setPedido(mestre);
                  } else {
                    // Em outras telas: empurra nova página
                    push(context, PedidoPage(pedido: mestre, reason: widget.reason));
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_left_rounded,
                          size: 18, color: Color(0xFF1E40AF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ir para o Pedido Mestre',
                          style: AppCss.minimumBold.copyWith(
                            color: const Color(0xFF1E40AF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: Color(0xFF1E40AF)),
                    ],
                  ),
                ),
              ),
            ),
          PedidoStatusWidget(pedido),
          const H(12),
          PedidoStepsWidget(pedido),
          const H(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PedidoTagsWidget(pedido)),
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
          const H(16),
          PedidoDescWidget(pedido),
          if (pedido.instrucoesEntrega.isNotEmpty ||
              pedido.instrucoesFinanceiras.isNotEmpty) ...[
            const H(16),
            if (pedido.instrucoesEntrega.isNotEmpty)
              PedidoEntregaWidget(pedido),
            if (pedido.instrucoesFinanceiras.isNotEmpty) ...[
              const H(12),
              PedidoFinancWidget(pedido),
            ],
          ],
        ],

        // ── 1: Acompanhamento (Gráficos de Produção) ──
        if (_dashboardIdx == 1) ...[
          if (!pedido.isAguardandoEntradaProducao()) ...[
            // ── Card: Corte & Dobra ──
            _producaoCard(
              icon: Icons.content_cut_outlined,
              title: 'CORTE & DOBRA',
              accentColor: const Color(0xFFD97706),
              totalKg: pedido.getQtdeTotal(),
              data: _buildCDGraphData(pedido),
            ),

            // ── Card: Armação (CDA) ──
            if (pedido.tipo == PedidoTipo.cda) ...[
              const H(16),
              _producaoCard(
                icon: Icons.construction_rounded,
                title: 'ARMAÇÃO',
                accentColor: const Color(0xFF059669),
                totalKg: _getCDATotalKg(pedido),
                data: _buildCDAGraphData(pedido),
              ),
            ],
          ],
          if (pedido.isAguardandoEntradaProducao())
            Container(
              margin: const EdgeInsets.symmetric(vertical: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.hourglass_empty_rounded,
                      size: 40, color: Colors.grey[300]),
                  const H(12),
                  Text('Aguardando Entrada em Produção',
                      style: AppCss.mediumRegular.setColor(Colors.grey)),
                ],
              ),
            ),
          // ── Mestre: apenas informativo ──
          if (pedido.isMestre)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 24, color: Color(0xFF92400E)),
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
          PedidoAnexosWidget(pedido),

        // ── 3: Checklist ──
        if (_dashboardIdx == 3)
          PedidoChecksWidget(pedido),

        // ── 4: Comentários ──
        if (_dashboardIdx == 4)
          PedidoCommentsWidget(pedido),

        // ── 5: Histórico ──
        if (_dashboardIdx == 5)
          if (pedido.histories.isNotEmpty)
            PedidoTimelineWidget(pedido: pedido),
      ],
    );
  }

  Widget _produtosBody(PedidoModel pedido) {
    return Container(
      color: AppColors.neutralLightest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Botão de relatório no topo direito
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _botaoRelatorio(
                  pedido,
                  label: pedido.isMestre
                      ? 'Relatório de Parciais'
                      : 'Relatório de Pedido',
                  onTap: () => pedido.isMestre
                      ? pedidoCtrl.onGeneratePDF(pedido,
                          type: RelatorioPedidoTipo.parciais)
                      : pedidoCtrl.onGeneratePDF(pedido,
                          type: RelatorioPedidoTipo.geral),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Pedido Mestre: tabela de saldo + cards dos parciais ──
                if (pedido.pedidosFilhos.isNotEmpty) ...[
                  PaiPedidoSaldoTableWidget(
                    mestre: pedido,
                    filhos: pedido.getPedidosFilhos(),
                  ),
                  const H(16),
                  PedidoFilhosWidget(
                      pedido: pedido, filhos: pedido.getPedidosFilhos()),
                ],

                // ── Produtos (Pedido Normal ou Parcial) ──
                if (pedido.pedidosFilhos.isEmpty) ...[
                  PedidoProdutosWidget(pedido),
                  if (pedido.getPedidosVinculados().isNotEmpty) ...[
                    const H(16),
                    PedidoVinculadosWidget(
                        pedido: pedido,
                        vinculados: pedido.getPedidosVinculados()),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _elementosBody(PedidoModel pedido) {
    return Container(
      color: AppColors.neutralLightest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Botão de relatório no topo direito
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _botaoRelatorio(
                  pedido,
                  label: 'Relatório de Elementos',
                  onTap: () => elementoCtrl.onGeneratePDF(pedido),
                ),
              ],
            ),
          ),
          Expanded(child: ElementosTab(pedido: pedido)),
        ],
      ),
    );
  }

  Widget _sidebar({
    required int currentIndex,
    required List<_SidebarItemData> items,
    required Function(int) onTap,
  }) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Preview da entidade (topo)
          Tooltip(
            message: widget.pedido.localizador,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryMain.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  widget.pedido.localizador.substring(0, 1).toUpperCase(),
                  style:
                      AppCss.minimumBold.setColor(AppColors.white).setSize(14),
                ),
              ),
            ),
          ),
          // ── Badge Mestre / Parcial ──
          if (widget.pedido.isMestre)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                ),
                child: Text(
                  'MESTRE',
                  style: AppCss.minimumBold.copyWith(
                      fontSize: 8,
                      color: const Color(0xFF92400E),
                      letterSpacing: 0.5),
                ),
              ),
            ),
          if (widget.pedido.isParcial)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFF3B82F6), width: 0.5),
                ),
                child: Text(
                  'PARCIAL',
                  style: AppCss.minimumBold.copyWith(
                      fontSize: 8,
                      color: const Color(0xFF1E40AF),
                      letterSpacing: 0.5),
                ),
              ),
            ),
          const SizedBox(height: 24),
          ...items.map((item) {
            final isSelected = currentIndex == item.index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Tooltip(
                message: item.label,
                preferBelow: false,
                waitDuration: const Duration(milliseconds: 300),
                child: InkWell(
                  onTap: () => onTap(item.index),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryMain.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color:
                                  AppColors.primaryMain.withValues(alpha: 0.20))
                          : null,
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primaryMain
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            );
          }),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.08),
                  accentColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppCss.mediumBold.copyWith(
                      fontSize: 13,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    totalKg.toKg(),
                    style: AppCss.minimumBold.copyWith(
                      fontSize: 12,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
          color: PedidoProdutoStatus.aguardandoProducao.color,
        ),
      if (produzindo > 0)
        ProducaoGraphData(
          label: 'Produzindo',
          pesoKg: produzindo,
          percentual: produzindo / total,
          color: PedidoProdutoStatus.produzindo.color,
        ),
      if (pronto > 0)
        ProducaoGraphData(
          label: 'Pronto',
          pesoKg: pronto,
          percentual: pronto / total,
          color: PedidoProdutoStatus.pronto.color,
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
          color: Colors.grey[400]!,
        ),
      if (armandoPeso > 0)
        ProducaoGraphData(
          label: 'Armando',
          pesoKg: armandoPeso,
          percentual: totalPeso > 0 ? armandoPeso / totalPeso : 0,
          color: Colors.amber[600]!,
        ),
      if (prontoPeso > 0)
        ProducaoGraphData(
          label: 'Pronto',
          pesoKg: prontoPeso,
          percentual: totalPeso > 0 ? prontoPeso / totalPeso : 0,
          color: Colors.green[600]!,
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

  _SidebarItemData(this.icon, this.label, this.index);
}
