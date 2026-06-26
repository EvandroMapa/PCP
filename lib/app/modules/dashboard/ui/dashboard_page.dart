import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/dashboard/dashboard_controller.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_elementos_page.dart';
import 'package:aco_plus/app/modules/dashboard/ui/mapa_obras_page.dart';

import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/ponta/ponta_model.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:material_symbols_icons/symbols.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List<PontaBitolaGrupo> _pontasGrupos = [];
  double _totalPontasKg = 0.0;
  bool _pontasCarregando = true;
  int _modoDash = 0; // 0 = Gestão a Vista, 1 = Mapa Pátio, 2 = Mapa de Obras
  bool _mostrarGraficoEstoque = false;
  bool _considerarPedidoSemData = true;

  @override
  void initState() {
    setWebTitle('AçoPlus - Planejamento e controle de Produção');
    super.initState();
    _carregarPontas();
  }

  Future<void> _carregarPontas() async {
    try {
      final data = await SupabaseService.client.from('pontas').select();
      final pontas = data.map((e) => PontaModel.fromSupabaseMap(e)).toList();

      final Map<String, PontaBitolaGrupo> mapa = {};
      for (final p in pontas) {
        mapa.putIfAbsent(
          p.bitolaId,
          () => PontaBitolaGrupo(
            bitolaId: p.bitolaId,
            bitolaDescricao: p.bitolaDescricao,
            pontas: [],
          ),
        );
        mapa[p.bitolaId]!.pontas.add(p);
      }

      final grupos = mapa.values.toList();
      double total = 0.0;
      for (final g in grupos) {
        total += g.totalPeso;
      }
      if (mounted) setState(() { _pontasGrupos = grupos; _totalPontasKg = total; _pontasCarregando = false; });
    } catch (_) {
      if (mounted) setState(() => _pontasCarregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(child: switch (_modoDash) {
          1 => _mapaParqueWidget(),
          2 => const MapaObrasWidget(),
          _ => body(),
        }),
      ],
    );
  }

  Widget body() {
    return StreamOut(
      stream: FirestoreClient.pedidos.pedidosUnarchivedsStream.listen,
      builder: (_, pedidos) => StreamOut(
        stream: FirestoreClient.ordens.dataStream.listen,
        builder: (_, __) => StreamOut(
          stream: dashCtrl.utilsStream.listen,
          builder: (_, utils) => LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                color: const Color(0xFFCBD5E1),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _kpiCards(pedidos),
                    const H(12),
                    _pontasStripWidget(),
                    const H(16),
                    if (constraints.maxWidth < 1000) ...[
                      // 1 Coluna (Mobile)
                      _ordemProducaoWidget(),
                      const H(16),
                      _armacaoWidget(pedidos),
                      const H(16),
                      _consumoBitolaWidget(),
                    ] else if (constraints.maxWidth < 1450) ...[
                      // 2 Colunas (Telas Médias)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ordemProducaoWidget()),
                          const W(16),
                          Expanded(child: _armacaoWidget(pedidos)),
                        ],
                      ),
                      const H(16),
                      _consumoBitolaWidget(),
                    ] else ...[
                      // 3 Colunas (Telas Grandes)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ordemProducaoWidget()),
                          const W(16),
                          Expanded(child: _armacaoWidget(pedidos)),
                          const W(16),
                          Expanded(child: _consumoBitolaWidget()),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kpiCards(List<PedidoModel> pedidos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalKg = pedidos
        .where((p) => p.step.isConsiderarTotalProducao)
        .fold(0.0, (sum, p) => sum + p.getQtdeTotal());

    final pedidosHoje = pedidos
        .where((p) => p.deliveryAt != null && p.deliveryAt!.isSameDay(today))
        .toList();
    final pedidosAtrasados = pedidos
        .where((p) =>
            !p.isEntregue &&
            p.deliveryAt != null &&
            p.deliveryAt!.isBefore(today) &&
            !p.deliveryAt!.isSameDay(today))
        .toList();
    final pedidosNovos = pedidos
        .where(
            (p) => p.createdAt.isAfter(now.subtract(const Duration(days: 1))))
        .toList();

    return LayoutBuilder(builder: (context, constraints) {
      double cardWidth;
      if (constraints.maxWidth < 700) {
        cardWidth = constraints.maxWidth;
      } else if (constraints.maxWidth < 1100) {
        cardWidth = (constraints.maxWidth - 24) / 2;
      } else {
        cardWidth = (constraints.maxWidth - 72) / 4;
      }

      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _cardKPI('TOTAL EM PRODUÇÃO', totalKg.toKg(), Symbols.factory,
              AppColors.primaryMain, cardWidth,
              subtitle:
                  'Total de pedidos que está sendo processado na planta atualmente'),
          _cardKPI('ENTREGAS HOJE', pedidosHoje.length.toString(),
              Symbols.local_shipping, AppColors.success, cardWidth,
              onTap: () => _showPedidosDialog(
                  context,
                  'Entregas Hoje',
                  '${pedidosHoje.length} pedido(s) com entrega prevista para hoje',
                  pedidosHoje,
                  AppColors.success,
                  Symbols.local_shipping)),
          _cardKPI('PEDIDOS ATRASADOS', pedidosAtrasados.length.toString(),
              Symbols.warning, AppColors.error, cardWidth,
              onTap: () => _showPedidosDialog(
                  context,
                  'Pedidos Atrasados',
                  '${pedidosAtrasados.length} pedido(s) com prazo vencido',
                  pedidosAtrasados,
                  AppColors.error,
                  Symbols.warning)),
          _cardKPI('NOVOS (24H)', pedidosNovos.length.toString(),
              Symbols.new_releases, AppColors.secondary, cardWidth,
              onTap: () => _showPedidosDialog(
                  context,
                  'Novos (24h)',
                  '${pedidosNovos.length} pedido(s) criado(s) nas últimas 24 horas',
                  pedidosNovos,
                  AppColors.secondary,
                  Symbols.new_releases)),
        ],
      );
    });
  }


  Widget _cardKPI(
      String label, String value, IconData icon, Color color, double width,
      {String? subtitle, VoidCallback? onTap}) {
    return Container(
      width: width,
      height: 155,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: onTap != null ? color.withAlpha(80) : Colors.grey[400]!,
            width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          mouseCursor: onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: AppCss.minimumBold
                                  .setSize(12)
                                  .setColor(Colors.grey[500]!)),
                          if (subtitle != null) ...[
                            const H(3),
                            Text(
                              subtitle,
                              style: AppCss.minimumRegular
                                  .setSize(10)
                                  .setColor(Colors.grey[400]!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const W(8),
                    Icon(icon, color: color.withAlpha(200), size: 22),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value,
                        style: AppCss.largeBold
                            .setSize(26)
                            .setColor(AppColors.primaryMain)),
                    if (onTap != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ver lista',
                                style: AppCss.minimumBold
                                    .setSize(10)
                                    .setColor(color)),
                            const W(3),
                            Icon(Icons.arrow_forward_ios,
                                size: 9, color: color),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPedidosDialog(
    BuildContext context,
    String titulo,
    String subtitulo,
    List<PedidoModel> pedidos,
    Color cor,
    IconData icone,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: BoxDecoration(
                  color: cor.withAlpha(12),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cor.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icone, color: cor, size: 20),
                    ),
                    const W(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: AppCss.mediumBold.setSize(16)),
                          const H(2),
                          Text(subtitulo,
                              style: AppCss.minimumRegular
                                  .setSize(12)
                                  .setColor(Colors.grey[500]!)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20, color: Colors.grey[400]),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              // ── Lista ──────────────────────────────────────────
              Flexible(
                child: pedidos.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Nenhum pedido encontrado.',
                          style: AppCss.mediumRegular
                              .setColor(Colors.grey[400]!),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: pedidos.length,
                        separatorBuilder: (_, __) => const H(8),
                        itemBuilder: (_, i) {
                          final p = pedidos[i];
                          final d = p.deliveryAt;
                          final dateStr = d != null
                              ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
                              : '—';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cor.withAlpha(20),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: AppCss.minimumBold
                                          .setSize(12)
                                          .setColor(cor),
                                    ),
                                  ),
                                ),
                                const W(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.localizador,
                                          style: AppCss.mediumBold
                                              .setSize(14)),
                                      const H(2),
                                      Text(
                                        p.cliente.nome,
                                        style: AppCss.minimumRegular
                                            .setSize(12)
                                            .setColor(Colors.grey[500]!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const W(12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      p.getQtdeTotal().toKg(),
                                      style: AppCss.mediumBold
                                          .setSize(13)
                                          .setColor(
                                              AppColors.primaryMain),
                                    ),
                                    const H(3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 11,
                                            color: Colors.grey[400]),
                                        const W(3),
                                        Text(
                                          dateStr,
                                          style: AppCss.minimumRegular
                                              .setSize(11)
                                              .setColor(
                                                  Colors.grey[500]!),
                                        ),
                                      ],
                                    ),
                                    const H(2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.step.color.withAlpha(25),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.step.name,
                                        style: AppCss.minimumBold
                                            .setSize(10)
                                            .setColor(p.step.color),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pontasStripWidget() {
    if (_pontasCarregando) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_pontasGrupos.isEmpty) return const SizedBox.shrink();

    // Ordenar por descrição
    final grupos = List<PontaBitolaGrupo>.from(_pontasGrupos);
    grupos.sort((a, b) => a.bitolaDescricao.compareTo(b.bitolaDescricao));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.flip_to_back, size: 18, color: Colors.teal[700]),
          const W(8),
          Text('PONTAS',
              style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[700]!)),
          const W(6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_totalPontasKg.toStringAsFixed(1)} kg',
              style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[800]!),
            ),
          ),
          const W(12),
          Container(width: 1, height: 24, color: Colors.grey[200]),
          const W(12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: grupos.map((g) {
                  // Extrair só a descrição curta (ex: "8.0mm")
                  final descCurta = g.bitolaDescricao.split(' - ').length > 1
                      ? g.bitolaDescricao.split(' - ').last.trim()
                      : g.bitolaDescricao;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            descCurta,
                            style: AppCss.minimumBold.setSize(11).setColor(Colors.grey[700]!),
                          ),
                          const W(6),
                          Text(
                            '${g.totalPeso.toStringAsFixed(1)} kg',
                            style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[700]!),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _consumoBitolaWidget() {
    final consumoMap = dashCtrl.getConsumoEstimado(considerarPedidoSemData: _considerarPedidoSemData);
    final produtos = FirestoreClient.bitolas.data
        .where((p) => consumoMap.containsKey(p.id))
        .toList();

    produtos.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    double totalGeral = 0;
    for (var p in produtos) {
      totalGeral += consumoMap[p.id] ?? 0.0;
    }

    return Container(
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 400;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _mostrarGraficoEstoque
                              ? Icons.bar_chart_rounded
                              : Symbols.analytics,
                          color: AppColors.primaryMain,
                          size: 20,
                        ),
                        const W(8),
                        Expanded(
                          child: Text(
                            _mostrarGraficoEstoque
                                ? 'POSIÇÃO DE ESTOQUE'
                                : 'CONSUMO ESTIMADO',
                            style: AppCss.mediumBold.setSize(isSmall ? 14 : 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_mostrarGraficoEstoque)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMain.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              totalGeral.toKg(),
                              style: AppCss.minimumBold
                                  .setSize(12)
                                  .setColor(AppColors.primaryMain),
                            ),
                          ),
                        const W(6),
                        Tooltip(
                          message: _mostrarGraficoEstoque
                              ? 'Ver consumo estimado'
                              : 'Ver gráfico de estoque',
                          preferBelow: false,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(
                                () => _mostrarGraficoEstoque = !_mostrarGraficoEstoque),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _mostrarGraficoEstoque
                                    ? AppColors.primaryMain.withAlpha(20)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _mostrarGraficoEstoque
                                      ? AppColors.primaryMain.withAlpha(50)
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Icon(
                                _mostrarGraficoEstoque
                                    ? Icons.list_alt_rounded
                                    : Icons.bar_chart_rounded,
                                size: 16,
                                color: _mostrarGraficoEstoque
                                    ? AppColors.primaryMain
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const H(8),
                    if (isSmall) ...[
                      Text(
                        _mostrarGraficoEstoque
                            ? 'Saldo + pedidos em aberto vs. consumo'
                            : 'Matéria-prima que será baixada do estoque',
                        style: AppCss.minimumRegular.setSize(11).setColor(Colors.grey[500]!),
                      ),
                      const H(6),
                      _checkboxSemData(),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _mostrarGraficoEstoque
                                  ? 'Saldo + pedidos em aberto vs. consumo'
                                  : 'Matéria-prima que será baixada do estoque',
                              style: AppCss.minimumRegular.setSize(11).setColor(Colors.grey[500]!),
                            ),
                          ),
                          const W(8),
                          _checkboxSemData(),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _mostrarGraficoEstoque
                  ? _estoqueChartContent(key: const ValueKey('chart'))
                  : _consumoListContent(
                      key: const ValueKey('lista'),
                      produtos: produtos,
                      consumoMap: consumoMap,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkboxSemData() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_outlined, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text('Considerar pedido sem data',
            style: AppCss.minimumBold
                .setColor(_considerarPedidoSemData
                    ? Colors.grey[700]!
                    : Colors.grey[400]!)
                .setSize(11)),
        SizedBox(
          height: 24,
          child: Checkbox(
            value: _considerarPedidoSemData,
            activeColor: const Color(0xFF2563EB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (v) {
              setState(() => _considerarPedidoSemData = v ?? true);
            },
          ),
        ),
      ]),
    );
  }

  Widget _consumoListContent({
    required Key key,
    required List produtos,
    required Map consumoMap,
  }) {
    if (produtos.isEmpty) {
      return Center(
        key: key,
        child: Text('Nenhum consumo pendente.',
            style: AppCss.mediumRegular.setColor(Colors.grey[400]!)),
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: produtos.length,
      itemBuilder: (_, i) {
        final p = produtos[i];
        final peso = (consumoMap[p.id] ?? 0.0) as double;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.descricao,
                      style: AppCss.mediumBold.setSize(13)),
                  Text(peso.toKg(),
                      style: AppCss.mediumBold
                          .setSize(13)
                          .setColor(AppColors.primaryMain)),
                ],
              ),
              const H(5),
              LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(
                    AppColors.primaryMain.withAlpha(25)),
                minHeight: 3,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _estoqueChartContent({required Key key}) {
    final todosProdutos = BackendClient.bitolas.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    final consumoMap = dashCtrl.getConsumoEstimado(considerarPedidoSemData: _considerarPedidoSemData);
    final List<_DashEstoqueData> data = [];
    double tSaldo = 0, tPedido = 0, tConsumo = 0;

    for (final p in todosProdutos) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      final saldo = estoque?.quantidade ?? 0.0;
      final consumo = consumoMap[p.id] ?? 0.0;
      final emPedido =
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(p.id);
      if (saldo == 0 && consumo == 0 && emPedido == 0) continue;
      final projetado = saldo + emPedido - consumo;
      data.add(_DashEstoqueData(
        label: p.nome,
        saldo: saldo,
        emPedido: emPedido,
        consumo: consumo,
        projetado: projetado,
      ));
      tSaldo += saldo;
      tPedido += emPedido;
      tConsumo += consumo;
    }
    final tProjetado = tSaldo + tPedido - tConsumo;

    return Column(
      key: key,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chartLeg('Saldo', const Color(0xFF1565C0)),
              const W(10),
              _chartLeg('Pedido', const Color(0xFF00897B)),
              const W(10),
              _chartLeg('Consumo', const Color(0xFFE65100)),
              const W(10),
              _chartLegLine('Projetado', const Color(0xFF1B5E20)),
            ],
          ),
        ),
        Expanded(
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(8, 8, 16, 4),
            plotAreaBorderWidth: 0,
            primaryXAxis: const CategoryAxis(
              labelRotation: -30,
              majorGridLines: MajorGridLines(width: 0),
              axisLine: AxisLine(width: 0.5),
              labelStyle: TextStyle(fontSize: 10),
            ),
            primaryYAxis: const NumericAxis(
              axisLine: AxisLine(width: 0),
              majorTickLines: MajorTickLines(size: 0),
              labelStyle: TextStyle(fontSize: 10),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              header: '',
              format: 'series.name: point.y kg',
            ),
            series: <CartesianSeries>[
              StackedColumnSeries<_DashEstoqueData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.saldo,
                name: 'Saldo',
                color: const Color(0xFF1565C0),
                groupName: 'disponivel',
                borderRadius: BorderRadius.zero,
              ),
              StackedColumnSeries<_DashEstoqueData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.emPedido,
                name: 'Pedido',
                color: const Color(0xFF00897B),
                groupName: 'disponivel',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              StackedColumnSeries<_DashEstoqueData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.consumo,
                name: 'Consumo',
                color: const Color(0xFFE65100),
                groupName: 'consumo',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              LineSeries<_DashEstoqueData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.projetado,
                name: 'Projetado',
                color: const Color(0xFF1B5E20),
                width: 2.0,
                dashArray: const [6, 3],
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 6,
                  width: 6,
                  borderColor: Colors.white,
                  borderWidth: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Icon(Icons.functions_rounded, size: 14, color: Colors.grey[600]),
            const W(6),
            Text('TOTAL',
                style: AppCss.minimumBold.setSize(10).setColor(Colors.grey[700]!)),
            const Spacer(),
            _chartTotal('Saldo', tSaldo.toKg(), const Color(0xFF1565C0)),
            const W(10),
            _chartTotal('Pedido', tPedido > 0 ? '+${tPedido.toKg()}' : '---',
                const Color(0xFF00897B)),
            const W(10),
            _chartTotal('Consumo', '-${tConsumo.toKg()}', const Color(0xFFE65100)),
            const W(10),
            _chartTotal('Projetado', tProjetado.toKg(),
                tProjetado < 0 ? Colors.red[700]! : const Color(0xFF1B5E20)),
          ]),
        ),
      ],
    );
  }

  Widget _chartLeg(String label, Color cor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
            color: cor, borderRadius: BorderRadius.circular(2)),
      ),
      const W(3),
      Text(label,
          style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(10)),
    ]);
  }

  Widget _chartLegLine(String label, Color cor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 2, color: cor),
      const W(2),
      Container(
        width: 5, height: 5,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const W(3),
      Text(label,
          style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(10)),
    ]);
  }

  Widget _chartTotal(String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: AppCss.minimumRegular.setColor(Colors.grey[500]!).setSize(8)),
        Text(valor,
            style: AppCss.minimumBold.setColor(cor).setSize(11)),
      ],
    );
  }

  Widget _ordemProducaoWidget() => StreamOut<List<OrdemModel>>(
        stream: FirestoreClient.ordens.ordensNaoArquivadasStream.listen,
        builder: (_, ordens) {
          List<OrdemModel> ordensFiltradas = ordens.toList();
          ordensFiltradas.removeWhere((element) => element.freezed.isFreezed);
          ordensFiltradas = ordensFiltradas
              .where((element) => element.status != PedidoBitolaStatus.pronto)
              .toList();

          return Container(
            height: 450,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[400]!, width: 1.0),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Symbols.reorder, color: AppColors.primaryMain, size: 20),
                      const W(8),
                      Expanded(
                        child: Text('ESTEIRA DE PRODUÇÃO',
                            style: AppCss.mediumBold.setSize(16),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const W(8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryMain.withAlpha(25),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${ordensFiltradas.length} ORDENS',
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(AppColors.primaryMain)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ordensFiltradas.isEmpty
                      ? Center(
                          child: Text('Nenhuma ordem em produção agora.',
                              style: AppCss.mediumRegular
                                  .setColor(Colors.grey[400]!)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: ordensFiltradas.length,
                          itemBuilder: (_, i) => _ordemProducaoItemWidget(
                              context, ordensFiltradas[i], i),
                        ),
                ),
              ],
            ),
          );
        },
      );

  Widget _ordemProducaoItemWidget(
    BuildContext context,
    OrdemModel ordem,
    int index,
  ) {
    final aneis = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _progressChartWidget(PedidoBitolaStatus.aguardandoProducao,
            ordem.getPrcntgAguardando(), ordem.freezed.isFreezed),
        const W(8),
        _progressChartWidget(PedidoBitolaStatus.produzindo,
            ordem.getPrcntgProduzindo(), ordem.freezed.isFreezed),
        const W(8),
        _progressChartWidget(PedidoBitolaStatus.pronto,
            ordem.getPrcntgPronto(), ordem.freezed.isFreezed),
      ],
    );

    return InkWell(
      onTap: () => push(context, OrdemPage(ordem.id)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 340;
            if (isNarrow) {
              // Layout vertical para celular
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: Colors.grey[100], shape: BoxShape.circle),
                        child: Center(
                            child: Text('${index + 1}º',
                                style: AppCss.minimumBold.setSize(11))),
                      ),
                      const W(10),
                      Expanded(
                        child: Text(
                          ordem.localizator,
                          style: AppCss.mediumBold.setSize(13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        ordem.produtos.fold(0.0, (sum, p) => sum + p.qtde).toKg(),
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(AppColors.primaryMain),
                      ),
                    ],
                  ),
                  const H(10),
                  Center(child: aneis),
                ],
              );
            }
            // Layout horizontal (tablet/desktop)
            return Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.grey[100], shape: BoxShape.circle),
                  child: Center(
                      child: Text('${index + 1}º',
                          style: AppCss.minimumBold.setSize(12))),
                ),
                const W(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ordem.localizator,
                        style: AppCss.mediumBold.setSize(14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const H(4),
                      Text(
                        ordem.produto.nome,
                        style: AppCss.mediumBold
                            .setSize(12)
                            .setColor(AppColors.primaryMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const H(2),
                      Text(
                        ordem.produtos.fold(0.0, (sum, p) => sum + p.qtde).toKg(),
                        style: AppCss.mediumBold
                            .setSize(12)
                            .setColor(AppColors.primaryMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const W(16),
                aneis,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _progressChartWidget(
    PedidoBitolaStatus status,
    double porcentagem,
    bool isFreezed,
  ) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: porcentagem,
              backgroundColor:
                  (isFreezed ? Colors.grey[600]! : status.color).withAlpha(50),
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(
                isFreezed ? Colors.grey[600]! : status.color,
              ),
            ),
          ),
          Text(
            '${(porcentagem * 100).percent}%',
            style: AppCss.mediumBold.setSize(13).setColor(Colors.black),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ARMAÇÃO
  // ═══════════════════════════════════════════════════
  Widget _armacaoWidget(List<PedidoModel> allPedidos) {
    final pedidosArmacao =
        allPedidos.where((p) => p.step.isExibirArmacao).toList();

    pedidosArmacao.sort((a, b) =>
        (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));

    return Container(
      height: 450,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Symbols.construction, color: Colors.orange[800], size: 20),
                const W(8),
                Expanded(
                  child: Text('ARMAÇÃO', style: AppCss.mediumBold.setSize(16),
                      overflow: TextOverflow.ellipsis),
                ),
                const W(8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pedidosArmacao.length} PEDIDOS',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(Colors.orange[800]!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidosArmacao.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum pedido em armação no momento.',
                      style: AppCss.mediumRegular.setColor(Colors.grey[400]!),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: pedidosArmacao.length,
                    itemBuilder: (_, i) =>
                        _armacaoItemWidget(context, pedidosArmacao[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _armacaoItemWidget(
    BuildContext context,
    PedidoModel pedido,
    int index,
  ) {
    final resumo = pedido.armacaoResumo['details'] as Map? ?? {};
    final totalQtd = pedido.armacaoResumo['total_qtd'] ?? 0;
    final totalPeso = (pedido.armacaoResumo['total_peso'] ?? 0.0).toDouble();

    final aguardando = resumo['aguardando'] ?? {};
    final armando = resumo['armando'] ?? {};
    final pronto = resumo['pronto'] ?? {};

    final prcAguardando = (aguardando['prcnt_qtd'] ?? 0.0).toDouble();
    final prcArmando = (armando['prcnt_qtd'] ?? 0.0).toDouble();
    final prcPronto = (pronto['prcnt_qtd'] ?? 0.0).toDouble();

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final aneis = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _armacaoCircle(
                    prcAguardando,
                    Colors.blue.shade700,
                    '${((aguardando['qtd'] ?? 0.0).toDouble()).round()} pc',
                    '${((aguardando['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
                const W(6),
                _armacaoCircle(
                    prcArmando,
                    Colors.orange.shade800,
                    '${((armando['qtd'] ?? 0.0).toDouble()).round()} pc',
                    '${((armando['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
                const W(6),
                _armacaoCircle(
                    prcPronto,
                    Colors.green.shade700,
                    '${((pronto['qtd'] ?? 0.0).toDouble()).round()} pc',
                    '${((pronto['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
              ],
            );

            final isNarrow = constraints.maxWidth < 340;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(Colors.orange[800]!),
                          ),
                        ),
                      ),
                      const W(10),
                      Expanded(
                        child: Tooltip(
                          message: pedido.cliente.nome,
                          child: Text(
                            pedido.localizador,
                            style: AppCss.mediumBold.setSize(13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        '${totalPeso.toStringAsFixed(0)} kg',
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(AppColors.primaryMain),
                      ),
                    ],
                  ),
                  const H(10),
                  Center(child: aneis),
                ],
              );
            }
            return Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppCss.minimumBold
                          .setSize(12)
                          .setColor(Colors.orange[800]!),
                    ),
                  ),
                ),
                const W(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: pedido.cliente.nome,
                        child: Text(
                          pedido.localizador,
                          style: AppCss.mediumBold.setSize(14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const H(4),
                      Text(
                        '$totalQtd elementos',
                        style: AppCss.minimumRegular
                            .setSize(12)
                            .setColor(Colors.grey[600]!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const H(2),
                      Text(
                        '${totalPeso.toStringAsFixed(1)} kg',
                        style: AppCss.mediumBold
                            .setSize(12)
                            .setColor(AppColors.primaryMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pedido.descricao.isNotEmpty) ...[
                        const H(2),
                        Text(
                          pedido.descricao,
                          style: AppCss.minimumRegular
                              .setSize(11)
                              .setColor(Colors.grey[500]!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const W(8),
                aneis,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _armacaoCircle(
      double porcentagem, Color color, String qtdLabel, String kgLabel) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: porcentagem,
                    backgroundColor: color.withAlpha(40),
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '${(porcentagem * 100).round()}%',
                  style: AppCss.mediumBold.setSize(13).setColor(Colors.black),
                ),
              ],
            ),
          ),
          const H(3),
          Text(
            qtdLabel,
            style: AppCss.minimumBold.setSize(11).setColor(Colors.grey[700]!),
          ),
          Text(
            kgLabel,
            style:
                AppCss.minimumRegular.setSize(10).setColor(Colors.grey[500]!),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  APP BAR COM TOGGLE
  // ═══════════════════════════════════════════════════
  Widget _buildAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 20, vertical: isSmall ? 8 : 12),
          decoration: BoxDecoration(
            color: AppColors.primaryMain,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(width: isSmall ? 4 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (_modoDash) {
                        1 => 'Mapa Pátio',
                        2 => 'Mapa de Obras',
                        _ => 'Gestão a Vista',
                      },
                      style: AppCss.mediumBold.setSize(isSmall ? 15 : 20).setColor(Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isSmall)
                      Text(
                        switch (_modoDash) {
                          1 => 'Visão geral do parque logístico',
                          2 => 'Obras com pedidos ativos no mapa',
                          _ => 'Monitoramento em tempo real de produção e consumo',
                        },
                        style: AppCss.minimumRegular.setSize(12).setColor(Colors.white.withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toggleBtn(0, Icons.dashboard_outlined, 'Gestão', isSmall),
                    _toggleBtn(1, Icons.map_outlined, 'Pátio', isSmall),
                    _toggleBtn(2, Icons.location_on_outlined, 'Obras', isSmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggleBtn(int modo, IconData icon, String label, [bool isSmall = false]) {
    final sel = _modoDash == modo;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => setState(() => _modoDash = modo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.5)),
              if (!isSmall) ...[
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.5))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  MAPA DE PEDIDOS (PARQUE COMPLETO)
  // ═══════════════════════════════════════════════════

  static const _coresPatios = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFEC4899),
  ];

  Widget _mapaParqueWidget() {
    final comp = PreferencesService.parqueComprimento.value;
    final larg = PreferencesService.parqueLargura.value;

    if (comp <= 0 || larg <= 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
            const H(16),
            Text('Parque log\u00edstico n\u00e3o configurado.', style: AppCss.mediumRegular.setColor(Colors.grey[400]!)),
          ],
        ),
      );
    }

    final patios = FirestoreClient.patios.data
        .where((p) => p.parqueX != null && p.parqueY != null)
        .toList();

    final pedidosAtivos = FirestoreClient.pedidos.data
        .where((p) => !p.isArchived)
        .toList();

    return Container(
      color: const Color(0xFFCBD5E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final cellW = maxW / comp;
            final cellH = maxH / larg;
            final cellSize = cellW < cellH ? cellW : cellH;
            final totalW = cellSize * comp;
            final totalH = cellSize * larg;

            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: Center(
              child: Container(
                width: totalW,
                height: totalH,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(
                    size: Size(totalW, totalH),
                    painter: _DashParqueGridPainter(comprimento: comp, largura: larg, cellSize: cellSize),
                    child: Stack(
                      children: patios.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final patio = entry.value;
                        final cor = _coresPatios[idx % _coresPatios.length];

                        final boxes = FirestoreClient.boxes.data
                            .where((b) => b.patioId == patio.id)
                            .toList();

                        return Positioned(
                          left: patio.parqueX! * cellSize,
                          top: patio.parqueY! * cellSize,
                          width: patio.comprimento * cellSize,
                          height: patio.largura * cellSize,
                          child: _patioComBoxes(patio, boxes, cor, cellSize, pedidosAtivos),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _patioComBoxes(PatioModel patio, List<BoxModel> boxes, Color cor, double parqueCellSize, List pedidosAtivos) {
    // Cell size relativo ao p\u00e1tio (pixels por metro dentro do p\u00e1tio)
    final patioCellSize = parqueCellSize; // 1 metro = 1 cellSize

    return Stack(
      children: [
        // Fundo do pátio
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // Nome do pátio no topo
          Positioned(
            left: 4, top: 2,
            child: Text(
              patio.nome,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cor.withValues(alpha: 0.5)),
            ),
          ),
          // Boxes
          ...boxes.map((box) {
            final alocacoes = FirestoreClient.pedidoBoxes.data
                .where((pb) => pb.boxId == box.id)
                .toList();
            final localizadores = alocacoes
                .map((pb) => pedidosAtivos.where((p) => p.id == pb.pedidoId).firstOrNull?.localizador)
                .where((l) => l != null)
                .cast<String>()
                .toList();
            final temPedido = localizadores.isNotEmpty;

            return Positioned(
              left: box.x * patioCellSize,
              top: box.y * patioCellSize,
              width: box.comprimento * patioCellSize,
              height: box.largura * patioCellSize,
              child: Tooltip(
                message: 'Box ${box.nome}${localizadores.isNotEmpty ? '\n${localizadores.join(', ')}' : ''}',
                child: Container(
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: temPedido ? box.color.withValues(alpha: 0.25) : box.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: temPedido ? box.color.withValues(alpha: 0.5) : box.color.withValues(alpha: 0.15),
                      width: temPedido ? 0.8 : 0.3,
                    ),
                  ),
                  child: ClipRect(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                box.nome,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: box.color.withValues(alpha: temPedido ? 0.9 : 0.5)),
                              ),
                              if (localizadores.isNotEmpty)
                                ...localizadores.map((loc) => Text(
                                  loc,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cor),
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        // Borda do pátio (por cima de tudo)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: cor.withValues(alpha: 0.35), width: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashParqueGridPainter extends CustomPainter {
  final int comprimento, largura;
  final double cellSize;
  _DashParqueGridPainter({required this.comprimento, required this.largura, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 0.3;
    for (int i = 0; i <= largura; i++) {
      canvas.drawLine(Offset(0, i * cellSize), Offset(size.width, i * cellSize), paint);
    }
    for (int i = 0; i <= comprimento; i++) {
      canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class _DashEstoqueData {
  final String label;
  final double saldo;
  final double emPedido;
  final double consumo;
  final double projetado;

  _DashEstoqueData({
    required this.label,
    required this.saldo,
    required this.emPedido,
    required this.consumo,
    required this.projetado,
  });
}
