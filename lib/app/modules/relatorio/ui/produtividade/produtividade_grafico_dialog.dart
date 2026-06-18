import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_produtividade_view_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Abre o dialog de gráficos de produtividade.
Future<void> showProdutividadeGraficoDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _ProdutividadeGraficoDialog(),
  );
}

enum _PeriodoTipo { semana, mes, ano, personalizado }

class _ProdutividadeGraficoDialog extends StatefulWidget {
  const _ProdutividadeGraficoDialog();

  @override
  State<_ProdutividadeGraficoDialog> createState() =>
      _ProdutividadeGraficoDialogState();
}

class _ProdutividadeGraficoDialogState
    extends State<_ProdutividadeGraficoDialog> {
  _PeriodoTipo _tipo = _PeriodoTipo.semana;
  late DateTime _dataRef;
  RelatorioProdutividadeModel? _relatorio;
  bool _carregando = true;

  // Cores para o gráfico de pizza (paleta vibrante)
  static const _coresPizza = [
    Color(0xFF2563EB), // azul
    Color(0xFF10B981), // verde
    Color(0xFFF59E0B), // amarelo
    Color(0xFFEF4444), // vermelho
    Color(0xFF8B5CF6), // roxo
    Color(0xFF06B6D4), // ciano
    Color(0xFFF97316), // laranja
    Color(0xFFEC4899), // rosa
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
  ];

  @override
  void initState() {
    super.initState();
    _dataRef = DateTime.now();
    _buscarDados();
  }

  DateTimeRange _calcularPeriodo() {
    switch (_tipo) {
      case _PeriodoTipo.semana:
        final diasDesdeSegunda = _dataRef.weekday - 1;
        final seg = DateTime(
            _dataRef.year, _dataRef.month, _dataRef.day - diasDesdeSegunda);
        final dom = seg.add(const Duration(days: 6));
        return DateTimeRange(
          start: seg,
          end: DateTime(dom.year, dom.month, dom.day, 23, 59, 59),
        );
      case _PeriodoTipo.mes:
        final primeiro = DateTime(_dataRef.year, _dataRef.month, 1);
        final ultimo = DateTime(_dataRef.year, _dataRef.month + 1, 0);
        return DateTimeRange(
          start: primeiro,
          end: DateTime(ultimo.year, ultimo.month, ultimo.day, 23, 59, 59),
        );
      case _PeriodoTipo.ano:
        return DateTimeRange(
          start: DateTime(_dataRef.year, 1, 1),
          end: DateTime(_dataRef.year, 12, 31, 23, 59, 59),
        );
      case _PeriodoTipo.personalizado:
        // O período personalizado já foi definido via DateRangePicker
        return _periodoCustom ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            );
    }
  }

  DateTimeRange? _periodoCustom;

  String _tituloNavegacao() {
    switch (_tipo) {
      case _PeriodoTipo.semana:
        final range = _calcularPeriodo();
        final fmt = DateFormat('dd/MM', 'pt_BR');
        return '${fmt.format(range.start)} — ${fmt.format(range.end)}';
      case _PeriodoTipo.mes:
        return DateFormat('MMMM yyyy', 'pt_BR').format(_dataRef);
      case _PeriodoTipo.ano:
        return _dataRef.year.toString();
      case _PeriodoTipo.personalizado:
        if (_periodoCustom != null) {
          final fmt = DateFormat('dd/MM/yy', 'pt_BR');
          return '${fmt.format(_periodoCustom!.start)} — ${fmt.format(_periodoCustom!.end)}';
        }
        return 'Selecione';
    }
  }

  void _navegarAnterior() {
    setState(() {
      switch (_tipo) {
        case _PeriodoTipo.semana:
          _dataRef = _dataRef.subtract(const Duration(days: 7));
          break;
        case _PeriodoTipo.mes:
          _dataRef = DateTime(_dataRef.year, _dataRef.month - 1, 1);
          break;
        case _PeriodoTipo.ano:
          _dataRef = DateTime(_dataRef.year - 1, 1, 1);
          break;
        case _PeriodoTipo.personalizado:
          return;
      }
    });
    _buscarDados();
  }

  void _navegarProximo() {
    setState(() {
      switch (_tipo) {
        case _PeriodoTipo.semana:
          _dataRef = _dataRef.add(const Duration(days: 7));
          break;
        case _PeriodoTipo.mes:
          _dataRef = DateTime(_dataRef.year, _dataRef.month + 1, 1);
          break;
        case _PeriodoTipo.ano:
          _dataRef = DateTime(_dataRef.year + 1, 1, 1);
          break;
        case _PeriodoTipo.personalizado:
          return;
      }
    });
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    final periodo = _calcularPeriodo();

    // Salva o período atual do ViewModel
    final vm = relatorioCtrl.produtividadeViewModelStream.value;
    final periodoOriginal = vm.periodo;

    // Troca temporariamente para calcular
    vm.periodo = periodo;
    relatorioCtrl.produtividadeViewModelStream.add(vm);
    await relatorioCtrl.onCreateRelatorioProdutividade();

    if (!mounted) return;
    setState(() {
      _relatorio = vm.relatorio;
      _carregando = false;
    });

    // Restaura o período original no ViewModel
    vm.periodo = periodoOriginal;
  }

  Future<void> _selecionarPeriodoCustom() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _periodoCustom ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      locale: const Locale('pt', 'BR'),
    );
    if (range != null) {
      _periodoCustom = DateTimeRange(
        start: range.start,
        end: DateTime(
            range.end.year, range.end.month, range.end.day, 23, 59, 59),
      );
      _buscarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSeletorPeriodo(),
            _buildNavegacao(),
            Flexible(
              child: _carregando
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _relatorio == null ||
                          (_relatorio!.porDia.isEmpty &&
                              _relatorio!.porBitola.isEmpty)
                      ? Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma produção neste período',
                                  style: AppCss.mediumRegular
                                      .setColor(Colors.grey[400]!),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKpis(),
                              const SizedBox(height: 20),
                              if (_relatorio!.porDia.isNotEmpty)
                                _buildGraficoBarras(),
                              if (_relatorio!.porBitola.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildGraficoPizza(),
                              ],
                            ],
                          ),
                        ),
            ),
            _buildRodape(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            'Gráfico de Produtividade',
            style: AppCss.mediumBold.setSize(15).setColor(Colors.white),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ── SELETOR DE PERÍODO ──────────────────────────────────
  Widget _buildSeletorPeriodo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: _PeriodoTipo.values.map((t) {
          final selecionado = _tipo == t;
          final label = switch (t) {
            _PeriodoTipo.semana => 'Semana',
            _PeriodoTipo.mes => 'Mês',
            _PeriodoTipo.ano => 'Ano',
            _PeriodoTipo.personalizado => 'Custom',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _tipo = t);
                if (t == _PeriodoTipo.personalizado) {
                  _selecionarPeriodoCustom();
                } else {
                  _dataRef = DateTime.now();
                  _buscarDados();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: selecionado
                      ? AppColors.primaryMain
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selecionado
                        ? AppColors.primaryMain
                        : Colors.grey[300]!,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selecionado ? FontWeight.w700 : FontWeight.w500,
                    color: selecionado ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── NAVEGAÇÃO ◀ ▶ ──────────────────────────────────────
  Widget _buildNavegacao() {
    final isCustom = _tipo == _PeriodoTipo.personalizado;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isCustom)
            IconButton(
              onPressed: _navegarAnterior,
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              splashRadius: 18,
              color: AppColors.primaryMain,
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _tituloNavegacao(),
              key: ValueKey('$_tipo-$_dataRef-$_periodoCustom'),
              style: AppCss.mediumBold.setSize(14),
            ),
          ),
          if (!isCustom)
            IconButton(
              onPressed: _navegarProximo,
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              splashRadius: 18,
              color: AppColors.primaryMain,
            ),
          if (isCustom)
            IconButton(
              onPressed: _selecionarPeriodoCustom,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              splashRadius: 18,
              color: AppColors.primaryMain,
            ),
        ],
      ),
    );
  }

  // ── KPIs ────────────────────────────────────────────────
  Widget _buildKpis() {
    final r = _relatorio!;
    final fmtMetros = NumberFormat('#,##0.00', 'pt_BR');
    return Row(
      children: [
        _kpiChip(
          icone: Icons.scale_outlined,
          label: 'Kg Total',
          valor: r.kgTotal.toKg(),
          cor: AppColors.primaryMain,
        ),
        const SizedBox(width: 10),
        _kpiChip(
          icone: Icons.straighten_outlined,
          label: 'Metros',
          valor: '${fmtMetros.format(r.metrosTotal)} m',
          cor: Colors.teal,
        ),
        const SizedBox(width: 10),
        _kpiChip(
          icone: Icons.factory_outlined,
          label: 'Produções',
          valor: r.qtdeProducoes.toString(),
          cor: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _kpiChip({
    required IconData icone,
    required String label,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 14, color: cor),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: cor)),
          ],
        ),
      ),
    );
  }

  // ── GRÁFICO DE BARRAS ──────────────────────────────────
  Widget _buildGraficoBarras() {
    final dados = _relatorio!.porDia;
    if (dados.isEmpty) return const SizedBox.shrink();

    final maxKg = dados.map((d) => d.kg).reduce((a, b) => a > b ? a : b);
    final maxY = (maxKg * 1.2).ceilToDouble();

    // Agrupar por mês se período é ano
    if (_tipo == _PeriodoTipo.ano) {
      return _buildGraficoBarrasAnual();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Produção por Dia (Kg)', style: AppCss.mediumBold.setSize(13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final item = dados[group.x.toInt()];
                    return BarTooltipItem(
                      '${DateFormat('dd/MM').format(item.data)}\n${item.kg.toKg()}',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}t'
                              : value.toInt().toString(),
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[400]),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dados.length) {
                        return const SizedBox.shrink();
                      }
                      // Mostrar no máximo ~10 labels
                      if (dados.length > 10 && idx % (dados.length ~/ 10 + 1) != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('dd/MM').format(dados[idx].data),
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[500]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(dados.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: dados[i].kg,
                      width: dados.length > 20 ? 8 : 16,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryMain.withValues(alpha: 0.7),
                          AppColors.primaryMain,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }

  Widget _buildGraficoBarrasAnual() {
    // Agrupar porDia em meses
    final Map<int, double> porMes = {};
    for (final d in _relatorio!.porDia) {
      porMes[d.data.month] = (porMes[d.data.month] ?? 0) + d.kg;
    }

    final meses = porMes.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (meses.isEmpty) return const SizedBox.shrink();

    final maxKg = meses.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = (maxKg * 1.2).ceilToDouble();

    final nomesMes = [
      '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Produção por Mês (Kg)', style: AppCss.mediumBold.setSize(13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final mes = meses[group.x.toInt()];
                    return BarTooltipItem(
                      '${nomesMes[mes.key]}\n${mes.value.toKg()}',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}t'
                              : value.toInt().toString(),
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[400]),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= meses.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          nomesMes[meses[idx].key],
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[500]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(meses.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: meses[i].value,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryMain.withValues(alpha: 0.7),
                          AppColors.primaryMain,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }

  // ── GRÁFICO DE PIZZA ──────────────────────────────────
  Widget _buildGraficoPizza() {
    final dados = _relatorio!.porBitola;
    if (dados.isEmpty) return const SizedBox.shrink();

    final total = dados.fold(0.0, (s, e) => s + e.kg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Distribuição por Bitola',
            style: AppCss.mediumBold.setSize(13)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pizza
            SizedBox(
              width: 180,
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: List.generate(dados.length, (i) {
                    final item = dados[i];
                    final pct = total > 0 ? (item.kg / total * 100) : 0.0;
                    return PieChartSectionData(
                      color: _coresPizza[i % _coresPizza.length],
                      value: item.kg,
                      title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                      radius: 44,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
                duration: const Duration(milliseconds: 500),
              ),
            ),
            const SizedBox(width: 20),
            // Legenda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(dados.length, (i) {
                  final item = dados[i];
                  final pct = total > 0 ? (item.kg / total * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _coresPizza[i % _coresPizza.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.bitola.descricaoReplaced}mm',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.kg.toKg(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── RODAPÉ ─────────────────────────────────────────────
  Widget _buildRodape() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
