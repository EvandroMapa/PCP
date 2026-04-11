import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/elemento/ui/elementos_tab.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pai/pai_pedido_corte_dobra_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pai/pai_pedido_filho_sinalizador_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pai/pai_pedido_produtos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pai/pai_pedido_sinalizador_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_anexos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_armacao_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_checks_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_comentarios_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_corte_dobra_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_desc_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_entrega_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_filhos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_financ_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_produtos_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_status_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_steps_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_tags_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_timeline_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_top_bar.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_users_widget.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_vinculados_widget.dart';
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
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: usuario.temAcessoElementos ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      pedidoCtrl.activeTabStream.add(_tabController.index);
    });
    if (widget.reason != PedidoInitReason.kanban) {
      setWebTitle('Pedido ${widget.pedido.localizador}');
    }
    pedidoCtrl.onInitPage(widget.pedido);
    notificacaoCtrl.onSetPedidoViewed(widget.pedido);
  }

  @override
  void dispose() {
    _tabController.dispose();
    pedidoCtrl.onDisposePage();
    pedidoCtrl.setPedido(null);
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
      builder: (_, pedido) =>
          isKanban ? _kanbanReasonWidget(pedido) : _pedidoReasonWidget(pedido),
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
        surfaceTintColor: Colors.transparent,
        child: _bodyWithTabs(pedido));
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
                  BoxShadow(color: AppColors.primaryMain.withValues(alpha: 0.2), offset: const Offset(0, 2), blurRadius: 4),
                ],
              ),
              tabs: [
                const Tab(text: 'DASHBOARD'),
                if (usuario.temAcessoElementos) const Tab(text: 'ELEMENTOS'),
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
                // Aba 1: Detalhes
                _detalhesBody(pedido),

                // Aba 2: Elementos
                if (usuario.temAcessoElementos) ElementosTab(pedido: pedido),
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
                bottom: BorderSide(color: color.withValues(alpha: 0.08), width: 1),
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

  // Compatibility wrapper
  Widget _buildCard({required List<Widget> children, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
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
        children: children,
      ),
    );
  }

  /// Conteúdo original da tela de detalhe do pedido
  Widget _detalhesBody(PedidoModel pedido) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Sinalizadores ──
        if (pedido.getPedidosFilhos().isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: PaiPedidoSinalizadorWidget()),
        if (pedido.pai != null && pedido.pai != '')
          Padding(padding: const EdgeInsets.only(bottom: 12), child: PaiPedidoFilhoSinalizadorWidget()),

        // ── Identificação ──
        _sectionCard(
          icon: Icons.assignment_outlined,
          title: 'IDENTIFICAÇÃO',
          accentColor: AppColors.primaryMain,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PedidoTagsWidget(pedido)),
                PedidoUsersWidget(pedido),
              ],
            ),
            const H(16),
            PedidoDescWidget(pedido),
          ],
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        ),

        // ── Produção (sem filhos) ──
        if (pedido.pedidosFilhos.isEmpty)
          _sectionCard(
            icon: Icons.precision_manufacturing_outlined,
            title: 'PRODUÇÃO',
            accentColor: const Color(0xFF0369A1), // sky-700
            children: [
              PedidoStatusWidget(pedido),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 1,
                color: Colors.grey.shade100,
              ),
              PedidoStepsWidget(pedido),
            ],
            contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          ),

        // ── Produtos (aguardando entrada) ──
        if (pedido.pedidosFilhos.isEmpty && pedido.isAguardandoEntradaProducao())
          _sectionCard(
            icon: Icons.inventory_2_outlined,
            title: 'PRODUTOS',
            accentColor: const Color(0xFF7C3AED), // violet-600
            children: [
              PedidoProdutosWidget(pedido),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),

        // ── Corte/Dobra + Produtos + Armação (em produção) ──
        if (pedido.pedidosFilhos.isEmpty && !pedido.isAguardandoEntradaProducao())
          _sectionCard(
            icon: Icons.content_cut_outlined,
            title: 'CORTE, DOBRA & ARMAÇÃO',
            accentColor: const Color(0xFFD97706), // amber-600
            children: [
              PedidoCorteDobraWidget(pedido),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 1,
                color: Colors.grey.shade100,
              ),
              PedidoProdutosWidget(pedido),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 1,
                color: Colors.grey.shade100,
              ),
              PedidoArmacaoWidget(pedido),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),

        // ── Pedido Pai (com filhos) ──
        if (pedido.pedidosFilhos.isNotEmpty)
          _sectionCard(
            icon: Icons.account_tree_outlined,
            title: 'PEDIDOS PARCIAIS',
            accentColor: const Color(0xFF059669), // emerald-600
            children: [
              PaiPedidoCorteDobraWidget(pedido),
              const H(16),
              PaiPedidoProdutosWidget(pedido),
              const H(16),
              PedidoFilhosWidget(pedido: pedido, filhos: pedido.getPedidosFilhos()),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),

        // ── Entrega & Financeiro ──
        if (pedido.instrucoesEntrega.isNotEmpty || pedido.instrucoesFinanceiras.isNotEmpty)
          _sectionCard(
            icon: Icons.local_shipping_outlined,
            title: 'ENTREGA & FINANCEIRO',
            accentColor: const Color(0xFF2563EB), // blue-600
            children: [
              if (pedido.instrucoesEntrega.isNotEmpty) ...[
                PedidoEntregaWidget(pedido),
                if (pedido.instrucoesFinanceiras.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 1,
                    color: Colors.grey.shade100,
                  ),
              ],
              if (pedido.instrucoesFinanceiras.isNotEmpty)
                PedidoFinancWidget(pedido),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),

        // ── Anexos ──
        _sectionCard(
          icon: Icons.attach_file_rounded,
          title: 'ANEXOS',
          accentColor: const Color(0xFF64748B), // slate-500
          children: [
            PedidoAnexosWidget(pedido),
          ],
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        ),

        // ── Checklist ──
        _sectionCard(
          icon: Icons.checklist_rounded,
          title: 'CHECKLIST',
          accentColor: const Color(0xFF16A34A), // green-600
          children: [
            PedidoChecksWidget(pedido),
          ],
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        ),

        // ── Vinculados ──
        if (pedido.pedidosFilhos.isEmpty)
          _sectionCard(
            icon: Icons.link_rounded,
            title: 'PEDIDOS VINCULADOS',
            accentColor: const Color(0xFF6366F1), // indigo-500
            children: [
              PedidoVinculadosWidget(pedido: pedido, vinculados: pedido.getPedidosVinculados()),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),

        // ── Comentários ──
        _sectionCard(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'COMENTÁRIOS',
          accentColor: const Color(0xFFEC4899), // pink-500
          children: [
            PedidoCommentsWidget(pedido),
          ],
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        ),

        // ── Histórico ──
        if (pedido.histories.isNotEmpty)
          _sectionCard(
            icon: Icons.timeline_rounded,
            title: 'HISTÓRICO',
            accentColor: const Color(0xFF78716C), // stone-500
            children: [
              PedidoTimelineWidget(pedido: pedido),
            ],
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          ),
      ],
    );
  }
}
