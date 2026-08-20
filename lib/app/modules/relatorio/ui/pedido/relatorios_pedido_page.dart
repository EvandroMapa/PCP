import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RelatoriosPedidoPage extends StatefulWidget {
  const RelatoriosPedidoPage({super.key});

  @override
  State<RelatoriosPedidoPage> createState() => _RelatoriosPedidoPageState();
}

class _RelatoriosPedidoPageState extends State<RelatoriosPedidoPage> {
  @override
  void initState() {
    setWebTitle('AçoPlus - Relatório de Consumo');
    relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    relatorioCtrl.onCreateRelatorioPedido();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        StreamOut(
          stream: relatorioCtrl.pedidoViewModelStream.listen,
          builder: (_, model) => IconButton(
            tooltip: model.showFilter ? 'Ocultar Filtros' : 'Mostrar Filtros',
            onPressed: () {
              model.showFilter = !model.showFilter;
              relatorioCtrl.pedidoViewModelStream.update();
            },
            icon: Icon(
              model.showFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
          ),
        ),
        StreamOut(
          stream: relatorioCtrl.pedidoViewModelStream.listen,
          builder: (_, model) => IconButton(
            tooltip: 'Exportar PDF',
            onPressed: model.relatorio != null
                ? () => relatorioCtrl.onExportRelatorioPedidoPDF(
                      relatorioCtrl.pedidoViewModel,
                    )
                : null,
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: model.relatorio != null ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<RelatorioPedidoViewModel>(
      stream: relatorioCtrl.pedidoViewModelStream.listen,
      builder: (_, model) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consumo Estimado',
                      style: AppCss.largeBold.setSize(22).setColor(const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text('Previsão e distribuição de matéria-prima por pedido e bitola',
                      style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtros colapsáveis
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: model.showFilter
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _filterWidget(model),
            ),
          ),

          // KPIs no topo
          if (model.relatorio != null) ...[
            _kpisWidget(model),
            const SizedBox(height: 16),
          ],

          // Seção de Totais e Resumo por Bitola
          if ([RelatorioPedidoTipo.totaisPedidos, RelatorioPedidoTipo.totais]
              .contains(model.tipo)) ...[
            _totaisWidget(model),
            const SizedBox(height: 20),
          ],

          // Seção de Consumo Detalhado por Pedido
          if ([RelatorioPedidoTipo.totaisPedidos, RelatorioPedidoTipo.pedidos]
              .contains(model.tipo)) ...[
            _pedidosWidget(model),
          ],
        ],
      ),
    );
  }

  // ─── KPIs ──────────────────────────────────────────────────────────────────

  Widget _kpisWidget(RelatorioPedidoViewModel model) {
    final totalKg = relatorioCtrl.getPedidosTotal();
    final qtdPedidos = model.relatorio?.pedidos.length ?? 0;
    
    // Contagem de bitolas ativas
    int qtdBitolasAtivas = 0;
    for (final b in FirestoreClient.bitolas.data) {
      if (relatorioCtrl.getPedidosTotalPorBitola(b) > 0) qtdBitolasAtivas++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard(
              icon: Icons.scale_outlined,
              iconBg: AppColors.primaryMain.withValues(alpha: 0.1),
              iconColor: AppColors.primaryMain,
              title: 'Volume Previsto',
              value: totalKg.toKg(),
              width: isCompact ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
            ),
            _kpiCard(
              icon: Icons.receipt_long_outlined,
              iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              iconColor: const Color(0xFF2563EB),
              title: 'Pedidos na Fila',
              value: '$qtdPedidos pedidos',
              width: isCompact ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
            ),
            _kpiCard(
              icon: Icons.view_in_ar_outlined,
              iconBg: const Color(0xFF10B981).withValues(alpha: 0.1),
              iconColor: const Color(0xFF059669),
              title: 'Bitolas Distintas',
              value: '$qtdBitolasAtivas bitolas',
              width: isCompact ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    style: AppCss.mediumBold
                        .setSize(16)
                        .setColor(const Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTRO ────────────────────────────────────────────────────────────────

  Widget _filterWidget(RelatorioPedidoViewModel model) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryMain),
              const SizedBox(width: 8),
              Text('Filtros Avançados',
                  style: AppCss.mediumBold.setSize(14).setColor(const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          AppDropDown<ClienteModel?>(
            label: 'Cliente',
            hasFilter: true,
            item: model.cliente,
            itens: [null, ...FirestoreClient.clientes.data],
            itemLabel: (e) => e?.nome ?? 'TODOS OS CLIENTES',
            onSelect: (e) {
              model.cliente = e;
              model.status.clear();
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const SizedBox(height: 14),
          AppDropDownList<PedidoBitolaStatus>(
            label: 'Status da Bitola',
            addeds: model.status,
            itens: PedidoBitolaStatus.values,
            itemLabel: (e) => e.label,
            itemColor: (e) => e.color.withValues(alpha: 0.1),
            onChanged: () {
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const SizedBox(height: 14),
          AppDropDownList<BitolaModel>(
            label: 'Bitolas',
            addeds: model.produtos,
            itens: FirestoreClient.bitolas.data,
            itemLabel: (e) => e.descricao,
            onChanged: () {
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppDropDown<SortType>(
                  label: 'Ordenar por',
                  item: model.sortType,
                  itens: model.sortTypes,
                  itemLabel: (e) => e.name,
                  onSelect: (e) {
                    model.sortType = e ?? SortType.alfabetic;
                    relatorioCtrl.pedidoViewModelStream.add(model);
                    relatorioCtrl.onCreateRelatorioPedido();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropDown<SortOrder>(
                  label: 'Ordem',
                  item: model.sortOrder,
                  itens: SortOrder.values,
                  itemLabel: (e) => e.name,
                  onSelect: (e) {
                    model.sortOrder = e ?? SortOrder.asc;
                    relatorioCtrl.pedidoViewModelStream.add(model);
                    relatorioCtrl.onCreateRelatorioPedido();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppDropDown<RelatorioPedidoTipo>(
            label: 'Visualização',
            item: model.tipo,
            itens: RelatorioPedidoTipo.values,
            itemLabel: (e) => e.label,
            onSelect: (e) {
              model.tipo = e!;
              relatorioCtrl.pedidoViewModelStream.update();
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
        ],
      ),
    );
  }

  // ─── TOTAIS & MIX ──────────────────────────────────────────────────────────

  Widget _totaisWidget(RelatorioPedidoViewModel model) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.donut_small_rounded,
                        size: 18, color: AppColors.primaryMain),
                  ),
                  const SizedBox(width: 10),
                  Text('Distribuição por Status',
                      style: AppCss.mediumBold
                          .setSize(15)
                          .setColor(const Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total: ${relatorioCtrl.getPedidosTotal().toKg()}',
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(AppColors.primaryMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _barraPercentualWidget(),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.layers_outlined,
                    size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Text('Resumo por Bitola',
                  style: AppCss.mediumBold
                      .setSize(15)
                      .setColor(const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          for (final produto in FirestoreClient.bitolas.data.toList()
            ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex)))
            Builder(
              builder: (context) {
                double totalBitola =
                    relatorioCtrl.getPedidosTotalPorBitola(produto);
                if (totalBitola <= 0) return const SizedBox.shrink();
                final isExpanded =
                    model.expandedProdutosIds.contains(produto.id);
                final totalGeral = relatorioCtrl.getPedidosTotal();
                final percTotal = totalGeral > 0 ? (totalBitola / totalGeral) * 100 : 0.0;

                return Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (isExpanded) {
                          model.expandedProdutosIds.remove(produto.id);
                        } else {
                          model.expandedProdutosIds.add(produto.id);
                        }
                        relatorioCtrl.pedidoViewModelStream.update();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? const Color(0xFFF8FAFC)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExpanded
                                ? AppColors.primaryMain.withValues(alpha: 0.3)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  produto.descricaoReplaced,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryMain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Bitola ${produto.descricaoReplaced} mm',
                                style: AppCss.minimumBold
                                    .setSize(13)
                                    .setColor(const Color(0xFF1E293B)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${percTotal.toStringAsFixed(1)}%',
                                style: AppCss.minimumBold
                                    .setSize(11)
                                    .setColor(const Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              totalBitola.toKg(),
                              style: AppCss.minimumBold
                                  .setSize(13)
                                  .setColor(AppColors.primaryMain),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      _bitolaDetalheWidget(model, produto, totalBitola),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _bitolaDetalheWidget(RelatorioPedidoViewModel model,
      BitolaModel produto, double totalBitola) {
    List<PedidoModel> pedidos = model.relatorio!.pedidos
        .where((p) => p.produtos.any((pr) => pr.produto.id == produto.id))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        border: Border(
          left: BorderSide(color: AppColors.primaryMain, width: 3),
          top: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        child: Column(
          children: pedidos.asMap().entries.map((entry) {
            int index = entry.key;
            PedidoModel pedido = entry.value;
            double qtde = pedido.produtos
                .where((p) => p.produto.id == produto.id)
                .fold(0, (prev, curr) => prev + curr.qtde);
            double percent = totalBitola > 0 ? (qtde / totalBitola) * 100 : 0;
            bool isOdd = index % 2 != 0;

            return Column(
              children: [
                if (index > 0)
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Container(
                  color: isOdd ? const Color(0xFFF8FAFC) : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          pedido.localizador,
                          style: AppCss.minimumBold
                              .setSize(11)
                              .setColor(const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pedido.cliente.nome,
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(const Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            qtde.toKg(),
                            style: AppCss.minimumBold
                                .setSize(12)
                                .setColor(AppColors.primaryMain),
                          ),
                          Text(
                            '${percent.toStringAsFixed(1)}% da bitola',
                            style: AppCss.minimumRegular
                                .setSize(9)
                                .setColor(Colors.grey[500]!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _barraPercentualWidget() {
    double total = relatorioCtrl.getPedidosTotal();
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: PedidoBitolaStatus.values.map((status) {
                double qtde = relatorioCtrl.getPedidosTotalPorStatus(status);
                if (qtde <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: (qtde * 100).toInt(),
                  child: Container(
                    color: status.color,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: PedidoBitolaStatus.values.map((status) {
            double qtde = relatorioCtrl.getPedidosTotalPorStatus(status);
            if (qtde <= 0) return const SizedBox.shrink();
            double percent = (qtde / total) * 100;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: status.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${status.label}: ${qtde.toKg()} (${percent.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── CONSUMO DETALHADO POR PEDIDO ──────────────────────────────────────────

  Widget _pedidosWidget(RelatorioPedidoViewModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            Text('Consumo Detalhado por Pedido',
                style: AppCss.mediumBold
                    .setSize(16)
                    .setColor(const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 12),
        ...model.relatorio!.pedidos.map((e) => itemRelatorio(e)),
      ],
    );
  }

  Widget itemRelatorio(PedidoModel pedido) {
    if (pedido.produtos.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pedido.localizador,
                    style: AppCss.minimumBold.setSize(11).setColor(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.cliente.nome.toUpperCase(),
                        style: AppCss.minimumBold
                            .setSize(13)
                            .setColor(const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Criado em ${DateFormat('dd/MM/yyyy HH:mm').format(pedido.createdAt)} · ${pedido.tipo.label}',
                        style: AppCss.minimumRegular
                            .setSize(10)
                            .setColor(Colors.grey[500]!),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pedido.getQtdeTotal().toKg(),
                    style: AppCss.minimumBold
                        .setSize(13)
                        .setColor(AppColors.primaryMain),
                  ),
                ),
              ],
            ),
          ),

          // Corpo do Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pedido.deliveryAt != null || pedido.descricao.isNotEmpty) ...[
                  Row(
                    children: [
                      if (pedido.deliveryAt != null) ...[
                        Icon(Icons.event_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Entrega: ${pedido.deliveryAt!.text()}',
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (pedido.descricao.isNotEmpty) ...[
                        Icon(Icons.notes_rounded,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pedido.descricao,
                            style: AppCss.minimumRegular
                                .setSize(12)
                                .setColor(const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                ],

                // Lista de Bitolas
                for (final produto in pedido.produtos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: produto.status.status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bitola ${produto.produto.descricaoReplaced} mm',
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(const Color(0xFF334155)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                produto.qtde.toKg(),
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(const Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: produto.status.status.color
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  produto.status.status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: produto.status.status.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
