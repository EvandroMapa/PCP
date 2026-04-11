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
            color: const Color(0xFFF4F6F8),
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

  Widget _buildCard({required List<Widget> children, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 2,
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
        if (pedido.getPedidosFilhos().isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: PaiPedidoSinalizadorWidget()),
        if (pedido.pai != null && pedido.pai != '')
          Padding(padding: const EdgeInsets.only(bottom: 12), child: PaiPedidoFilhoSinalizadorWidget()),

        _buildCard(
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
        ),

        if (pedido.pedidosFilhos.isEmpty)
          _buildCard(
            children: [
              PedidoStatusWidget(pedido),
              const H(16),
              PedidoStepsWidget(pedido),
            ],
          ),

        if (pedido.pedidosFilhos.isEmpty && pedido.isAguardandoEntradaProducao())
          _buildCard(
            children: [
              PedidoProdutosWidget(pedido),
            ],
          ),

        if (pedido.pedidosFilhos.isEmpty && !pedido.isAguardandoEntradaProducao())
          _buildCard(
            children: [
              PedidoCorteDobraWidget(pedido),
              const H(16),
              PedidoProdutosWidget(pedido),
              const H(16),
              PedidoArmacaoWidget(pedido),
            ],
          ),

        if (pedido.pedidosFilhos.isNotEmpty)
          _buildCard(
            children: [
              PaiPedidoCorteDobraWidget(pedido),
              const H(16),
              PaiPedidoProdutosWidget(pedido),
              const H(16),
              PedidoFilhosWidget(pedido: pedido, filhos: pedido.getPedidosFilhos()),
            ],
          ),

        if (pedido.instrucoesEntrega.isNotEmpty || pedido.instrucoesFinanceiras.isNotEmpty)
          _buildCard(
            children: [
              if (pedido.instrucoesEntrega.isNotEmpty) ...[
                PedidoEntregaWidget(pedido),
                if (pedido.instrucoesFinanceiras.isNotEmpty) const H(16),
              ],
              if (pedido.instrucoesFinanceiras.isNotEmpty)
                PedidoFinancWidget(pedido),
            ],
          ),

        _buildCard(
          children: [
            PedidoAnexosWidget(pedido),
          ],
        ),

        _buildCard(
          children: [
            PedidoChecksWidget(pedido),
          ],
        ),

        if (pedido.pedidosFilhos.isEmpty)
          _buildCard(
            children: [
              PedidoVinculadosWidget(pedido: pedido, vinculados: pedido.getPedidosVinculados()),
            ],
          ),

        _buildCard(
          children: [
            PedidoCommentsWidget(pedido),
          ],
        ),

        if (pedido.histories.isNotEmpty)
          _buildCard(
            children: [
              PedidoTimelineWidget(pedido: pedido),
            ],
          ),
      ],
    );
  }
}
