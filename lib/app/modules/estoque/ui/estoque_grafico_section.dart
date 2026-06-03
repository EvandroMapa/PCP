import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class EstoqueGraficoSection extends StatefulWidget {
  const EstoqueGraficoSection({super.key});

  @override
  State<EstoqueGraficoSection> createState() => _EstoqueGraficoSectionState();
}

class _EstoqueGraficoSectionState extends State<EstoqueGraficoSection> {
  @override
  void initState() {
    setWebTitle('Estoque - Gráfico');
    relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    relatorioCtrl.onCreateRelatorioPedido();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: BackendClient.estoques.dataStream.listen,
      builder: (_, __) => StreamOut(
        stream: BackendClient.pedidosCompra.dataStream.listen,
        builder: (_, ___) => StreamOut(
          stream: FirestoreClient.pedidos.dataStream.listen,
          builder: (_, __) => StreamOut<RelatorioPedidoViewModel>(
            stream: relatorioCtrl.pedidoViewModelStream.listen,
            builder: (_, model) => _body(model),
          ),
        ),
      ),
    );
  }

  Widget _body(RelatorioPedidoViewModel model) {
    final produtos = BackendClient.bitolas.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    final Map<String, double> consumoMap = {};
    for (final p in produtos) {
      final total = relatorioCtrl.getPedidosTotalPorBitola(p);
      if (total > 0) consumoMap[p.id] = total;
    }

    double totalSaldo = 0, totalConsumo = 0, totalEmPedido = 0;
    for (final p in produtos) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      totalSaldo += estoque?.quantidade ?? 0.0;
      totalConsumo += consumoMap[p.id] ?? 0.0;
      totalEmPedido +=
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(p.id);
    }
    final totalProjetado = totalSaldo - totalConsumo + totalEmPedido;

    // Monta os dados do gráfico
    final List<_GraficoData> data = [];
    for (final p in produtos) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      final saldo = estoque?.quantidade ?? 0.0;
      final consumo = consumoMap[p.id] ?? 0.0;
      final emPedido =
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(p.id);
      if (saldo == 0 && consumo == 0 && emPedido == 0) continue;
      data.add(_GraficoData(
        label: p.nome,
        saldo: saldo,
        emPedido: emPedido,
        consumo: consumo,
        projetado: saldo + emPedido - consumo,
        estoqueMinimo: estoque?.estoqueMinimo ?? 0.0,
        estoqueIdeal: estoque?.estoqueIdeal ?? 0.0,
      ));
    }

    return Column(
      children: [
        // ── Cabeçalho ──────────────────────────────────────────────────────
        _header(totalSaldo, totalConsumo, totalEmPedido, totalProjetado),
        const Divider(height: 1),

        // ── Legenda ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legItem('Saldo Físico', const Color(0xFF2563EB)),
              const SizedBox(width: 14),
              _legItem('Em Pedido', const Color(0xFF0D9488)),
              const SizedBox(width: 14),
              _legItem('Consumo Previsto', const Color(0xFFF97316)),
            ],
          ),
        ),

        // ── Gráfico ────────────────────────────────────────────────────────
        Expanded(
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            plotAreaBorderWidth: 0,
            legend: Legend(
              isVisible: true,
              position: LegendPosition.top,
              overflowMode: LegendItemOverflowMode.wrap,
              toggleSeriesVisibility: true,
              textStyle:
                  TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            primaryXAxis: const CategoryAxis(
              labelRotation: -30,
              majorGridLines: MajorGridLines(width: 0),
              axisLine: AxisLine(width: 0.5),
            ),
            primaryYAxis: const NumericAxis(
              axisLine: AxisLine(width: 0),
              majorTickLines: MajorTickLines(size: 0),
              labelStyle: TextStyle(fontSize: 10),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              header: '',
              canShowMarker: true,
              format: 'series.name: point.y kg',
            ),
            series: <CartesianSeries>[
              StackedColumnSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.saldo,
                name: 'Saldo Físico',
                color: const Color(0xFF2563EB),
                groupName: 'disponivel',
                isVisibleInLegend: false,
                borderRadius: BorderRadius.zero,
              ),
              StackedColumnSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.emPedido,
                name: 'Em Pedido',
                color: const Color(0xFF0D9488),
                groupName: 'disponivel',
                isVisibleInLegend: false,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (dynamic d, dynamic point, dynamic series,
                      int pointIndex, int seriesIndex) {
                    final item = d as _GraficoData;
                    final total = item.saldo + item.emPedido;
                    if (total <= 0) return const SizedBox.shrink();
                    return Transform.translate(
                      offset: const Offset(0, -16),
                      child: Text(
                        '${(total / 1000).toStringAsFixed(2)} t',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
              StackedColumnSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.consumo,
                name: 'Consumo Previsto',
                color: const Color(0xFFF97316),
                groupName: 'consumo',
                isVisibleInLegend: false,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (dynamic d, dynamic point, dynamic series,
                      int pointIndex, int seriesIndex) {
                    final item = d as _GraficoData;
                    if (item.consumo <= 0) return const SizedBox.shrink();
                    return Transform.translate(
                      offset: const Offset(0, -16),
                      child: Text(
                        '${(item.consumo / 1000).toStringAsFixed(2)} t',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
              LineSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) => d.projetado,
                name: 'Saldo Projetado',
                color: const Color(0xFF16A34A),
                width: 2.5,
                dashArray: const [6, 3],
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 8,
                  width: 8,
                  shape: DataMarkerType.circle,
                  color: Color(0xFF16A34A),
                  borderColor: Colors.white,
                  borderWidth: 2,
                ),
              ),
              LineSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) =>
                    d.estoqueMinimo > 0 ? d.estoqueMinimo : null,
                name: 'Estoque Mínimo',
                initialIsVisible: false,
                color: const Color(0xFFEF4444),
                width: 2.0,
                dashArray: const [5, 4],
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 7,
                  width: 7,
                  shape: DataMarkerType.diamond,
                  color: Color(0xFFEF4444),
                  borderColor: Colors.white,
                  borderWidth: 1.5,
                ),
              ),
              LineSeries<_GraficoData, String>(
                dataSource: data,
                xValueMapper: (d, __) => d.label,
                yValueMapper: (d, __) =>
                    d.estoqueIdeal > 0 ? d.estoqueIdeal : null,
                name: 'Estoque Ideal',
                initialIsVisible: false,
                color: const Color(0xFF8B5CF6),
                width: 2.0,
                dashArray: const [5, 4],
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 7,
                  width: 7,
                  shape: DataMarkerType.diamond,
                  color: Color(0xFF8B5CF6),
                  borderColor: Colors.white,
                  borderWidth: 1.5,
                ),
              ),
            ],
          ),
        ),

        // ── Rodapé com totais ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Icon(Icons.functions_rounded, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('TOTAL',
                style: AppCss.minimumBold.setColor(Colors.grey[700]!)),
            const Spacer(),
            _totalItem('Saldo',
                '${(totalSaldo / 1000).toStringAsFixed(2)} t',
                const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            _totalItem(
                'Pedido',
                totalEmPedido > 0
                    ? '+${(totalEmPedido / 1000).toStringAsFixed(2)} t'
                    : '—',
                const Color(0xFF0D9488)),
            const SizedBox(width: 12),
            _totalItem('Consumo',
                '-${(totalConsumo / 1000).toStringAsFixed(2)} t',
                const Color(0xFFF97316)),
            const SizedBox(width: 12),
            _totalItem(
              'Projetado',
              '${(totalProjetado / 1000).toStringAsFixed(2)} t',
              totalProjetado < 0
                  ? Colors.red[700]!
                  : const Color(0xFF16A34A),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Cabeçalho compacto ──────────────────────────────────────────────────────

  Widget _header(double saldo, double consumo, double emPedido, double projetado) {
    final negativo = projetado < 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.primaryMain),
        const SizedBox(width: 6),
        Text('Gráfico de Posição',
            style: AppCss.minimumBold.setColor(AppColors.primaryMain)),
        const Spacer(),
        _kpi('Saldo', saldo.toKg(), Colors.blue[700]!),
        const SizedBox(width: 8),
        _kpi('Consumo', '-${consumo.toKg()}', Colors.orange[700]!),
        const SizedBox(width: 8),
        _kpi('Projetado', projetado.toKg(),
            negativo ? Colors.red[700]! : Colors.green[700]!),
      ]),
    );
  }

  Widget _kpi(String label, String valor, Color cor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label,
          style: AppCss.minimumRegular
              .setSize(9)
              .setColor(Colors.grey[500]!)),
      Text(valor, style: AppCss.minimumBold.setColor(cor).setSize(12)),
    ]);
  }

  Widget _legItem(String label, Color cor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12,
        height: 12,
        decoration:
            BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: AppCss.minimumRegular
              .setColor(Colors.grey[700]!)
              .setSize(11)),
    ]);
  }

  Widget _totalItem(String label, String valor, Color cor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label,
          style: AppCss.minimumRegular
              .setColor(Colors.grey[500]!)
              .setSize(9)),
      Text(valor, style: AppCss.minimumBold.setColor(cor).setSize(13)),
    ]);
  }
}

// ── Model de dados do gráfico ─────────────────────────────────────────────────

class _GraficoData {
  final String label;
  final double saldo;
  final double emPedido;
  final double consumo;
  final double projetado;
  final double estoqueMinimo;
  final double estoqueIdeal;

  _GraficoData({
    required this.label,
    required this.saldo,
    required this.emPedido,
    required this.consumo,
    required this.projetado,
    this.estoqueMinimo = 0,
    this.estoqueIdeal = 0,
  });
}
