import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/ui/produtividade/produtividade_grafico_dialog.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_produtividade_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RelatorioProdutividadePage extends StatefulWidget {
  const RelatorioProdutividadePage({super.key});

  @override
  State<RelatorioProdutividadePage> createState() =>
      _RelatorioProdutividadePageState();
}

class _RelatorioProdutividadePageState
    extends State<RelatorioProdutividadePage> {
  static final _fmtMetros = NumberFormat('#,##0.00', 'pt_BR');

  @override
  void initState() {
    setWebTitle('AçoPlus - Produtividade CD');
    relatorioCtrl.produtividadeViewModelStream
        .add(RelatorioProdutividadeViewModel());
    relatorioCtrl.onCreateRelatorioProdutividade();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        StreamOut(
          stream: relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            tooltip: 'Visualizar Gráfico',
            onPressed: model.relatorio != null
                ? () => showProdutividadeGraficoDialog(context)
                : null,
            icon: Icon(
              Icons.bar_chart_rounded,
              color: model.relatorio != null ? Colors.white : Colors.white54,
            ),
          ),
        ),
        StreamOut(
          stream: relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            tooltip: model.mostrarFiltro ? 'Ocultar Filtros' : 'Mostrar Filtros',
            onPressed: () {
              model.mostrarFiltro = !model.mostrarFiltro;
              relatorioCtrl.produtividadeViewModelStream.update();
            },
            icon: Icon(
              model.mostrarFiltro ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
          ),
        ),
        StreamOut(
          stream: relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            tooltip: 'Exportar PDF',
            onPressed: model.relatorio != null
                ? () => relatorioCtrl.onExportRelatorioProdutividadePDF()
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
    return StreamOut<RelatorioProdutividadeViewModel>(
      stream: relatorioCtrl.produtividadeViewModelStream.listen,
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
                  Text('Produtividade CD',
                      style: AppCss.largeBold.setSize(22).setColor(const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text('Indicadores de fabricação, rendimento em peso e metragem linear',
                      style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtros
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: model.mostrarFiltro
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _filtroWidget(model),
            ),
          ),

          // Conteúdo
          if (model.relatorio != null && model.relatorio!.kgTotal > 0) ...[
            _kpisWidget(model.relatorio!),
            const SizedBox(height: 20),
            if (model.relatorio!.porBitola.isNotEmpty) ...[
              _porBitolaWidget(model.relatorio!),
              const SizedBox(height: 20),
            ],
            if (model.relatorio!.porDia.isNotEmpty) ...[
              _porDiaWidget(model.relatorio!),
              const SizedBox(height: 20),
            ],
          ] else
            Container(
              padding: const EdgeInsets.all(40),
              margin: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(Icons.assessment_outlined,
                          size: 28, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nenhuma produção encontrada no período selecionado',
                      style: AppCss.mediumBold
                          .setSize(15)
                          .setColor(const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tente ajustar o intervalo de datas ou selecionar outros operadores e bitolas.',
                      style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── FILTROS ──────────────────────────────────────────────

  Widget _filtroWidget(RelatorioProdutividadeViewModel model) {
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
              Text('Filtros de Produtividade',
                  style: AppCss.mediumBold.setSize(14).setColor(const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          // Período
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final range = await _mostrarDialogPeriodo(context, model.periodo);
              if (range != null) {
                model.periodo = range;
                relatorioCtrl.produtividadeViewModelStream.add(model);
                relatorioCtrl.onCreateRelatorioProdutividade();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 18, color: AppColors.primaryMain),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Período de Apuração',
                          style: AppCss.minimumRegular
                              .setSize(10)
                              .setColor(Colors.grey[500]!)),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(model.periodo.start)}  →  ${DateFormat('dd/MM/yyyy').format(model.periodo.end)}',
                        style: AppCss.minimumBold
                            .setSize(13)
                            .setColor(const Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_outlined,
                      size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Operador
          AppDropDown<UsuarioModel?>(
            label: 'Operador Responsável',
            hasFilter: true,
            item: model.operador,
            itens: [null, ...FirestoreClient.usuarios.data],
            itemLabel: (e) => e?.nome ?? 'TODOS OS OPERADORES',
            onSelect: (e) {
              model.operador = e;
              relatorioCtrl.produtividadeViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioProdutividade();
            },
          ),
          const SizedBox(height: 14),
          // Bitolas
          AppDropDownList<BitolaModel>(
            label: 'Bitolas Filtradas',
            addeds: model.bitolas,
            itens: FirestoreClient.bitolas.data,
            itemLabel: (e) => e.descricao,
            onChanged: () {
              relatorioCtrl.produtividadeViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioProdutividade();
            },
          ),
        ],
      ),
    );
  }

  // ── KPIs ────────────────────────────────────────────────

  Widget _kpisWidget(RelatorioProdutividadeModel relatorio) {
    final diasAtivos = relatorio.porDia.length;
    final mediaDiaria = diasAtivos > 0 ? (relatorio.kgTotal / diasAtivos) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        final cardWidth = isCompact
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard(
              titulo: 'Produção Total',
              valor: relatorio.kgTotal.toKg(),
              icone: Icons.scale_outlined,
              cor: AppColors.primaryMain,
              width: cardWidth,
            ),
            _kpiCard(
              titulo: 'Metros Lineares',
              valor: '${_fmtMetros.format(relatorio.metrosTotal)} m',
              icone: Icons.straighten_outlined,
              cor: const Color(0xFF0D9488),
              width: cardWidth,
            ),
            _kpiCard(
              titulo: 'Média / Dia Ativo',
              valor: mediaDiaria.toKg(),
              icone: Icons.trending_up_rounded,
              cor: const Color(0xFF2563EB),
              width: cardWidth,
            ),
            _kpiCard(
              titulo: 'Dias Trabalhados',
              valor: '$diasAtivos dias',
              icone: Icons.calendar_today_outlined,
              cor: const Color(0xFFD97706),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
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
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 22, color: cor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo,
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(valor,
                    style: AppCss.mediumBold
                        .setSize(15)
                        .setColor(const Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── POR BITOLA ──────────────────────────────────────────

  Widget _porBitolaWidget(RelatorioProdutividadeModel relatorio) {
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
                    child: Icon(Icons.bar_chart_outlined,
                        size: 18, color: AppColors.primaryMain),
                  ),
                  const SizedBox(width: 10),
                  Text('Produção por Bitola',
                      style: AppCss.mediumBold
                          .setSize(15)
                          .setColor(const Color(0xFF0F172A))),
                ],
              ),
              Text(
                'Total: ${relatorio.kgTotal.toKg()}',
                style: AppCss.minimumBold
                    .setSize(12)
                    .setColor(AppColors.primaryMain),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tabela/Lista de Bitolas
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('BITOLA',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)))),
                      Expanded(
                          flex: 2,
                          child: Text('PRODUÇÃO (KG)',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('METRAGEM',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('PARTICIPAÇÃO',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Linhas
                for (int i = 0; i < relatorio.porBitola.length; i++)
                  _bitolaRow(relatorio.porBitola[i], relatorio.kgTotal, i.isOdd),

                // Rodapé Totalizador
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('TOTAL GERAL',
                              style: AppCss.minimumBold
                                  .setSize(12)
                                  .setColor(const Color(0xFF0F172A)))),
                      Expanded(
                          flex: 2,
                          child: Text(
                              relatorio.kgTotal.toKg(),
                              style: AppCss.minimumBold
                                  .setSize(13)
                                  .setColor(AppColors.primaryMain),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text(
                              '${_fmtMetros.format(relatorio.metrosTotal)} m',
                              style: AppCss.minimumBold
                                  .setSize(13)
                                  .setColor(const Color(0xFF0D9488)),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text(
                              '100.0%',
                              style: AppCss.minimumBold
                                  .setSize(12)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bitolaRow(
      ProdutividadePorBitola item, double kgTotal, bool isOdd) {
    final perc = kgTotal > 0 ? (item.kg / kgTotal) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOdd ? const Color(0xFFFAFAFA) : Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      item.bitola.descricaoReplaced,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryMain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.bitola.descricaoReplaced} mm',
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(const Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.kg.toKg(),
              style: AppCss.minimumBold
                  .setSize(12)
                  .setColor(const Color(0xFF0F172A)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmtMetros.format(item.metros)} m',
              style: AppCss.minimumRegular
                  .setSize(12)
                  .setColor(const Color(0xFF475569)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${perc.toStringAsFixed(1)}%',
              style: AppCss.minimumBold
                  .setSize(11)
                  .setColor(const Color(0xFF64748B)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── POR DIA ─────────────────────────────────────────────

  Widget _porDiaWidget(RelatorioProdutividadeModel relatorio) {
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
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_outlined,
                        size: 18, color: Color(0xFF0D9488)),
                  ),
                  const SizedBox(width: 10),
                  Text('Produção Diária',
                      style: AppCss.mediumBold
                          .setSize(15)
                          .setColor(const Color(0xFF0F172A))),
                ],
              ),
              Text(
                '${relatorio.porDia.length} dias apontados',
                style: AppCss.minimumRegular
                    .setSize(12)
                    .setColor(const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('DATA',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)))),
                      Expanded(
                          flex: 2,
                          child: Text('PRODUÇÃO (KG)',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('METRAGEM',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(const Color(0xFF64748B)),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Linhas
                for (int i = 0; i < relatorio.porDia.length; i++)
                  _diaRow(relatorio.porDia[i], i.isOdd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diaRow(ProdutividadePorDia item, bool isOdd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOdd ? const Color(0xFFFAFAFA) : Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.event_note_outlined,
                    size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy (EEE)', 'pt_BR').format(item.data),
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(const Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.kg.toKg(),
              style: AppCss.minimumBold
                  .setSize(12)
                  .setColor(const Color(0xFF0F172A)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmtMetros.format(item.metros)} m',
              style: AppCss.minimumRegular
                  .setSize(12)
                  .setColor(const Color(0xFF0D9488)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTimeRange?> _mostrarDialogPeriodo(
      BuildContext context, DateTimeRange atual) async {
    DateTime inicio = atual.start;
    DateTime fim = DateTime(atual.end.year, atual.end.month, atual.end.day);

    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.date_range,
                      size: 20, color: AppColors.primaryMain),
                  const SizedBox(width: 8),
                  const Text('Selecionar Período'),
                ],
              ),
              titleTextStyle: AppCss.mediumBold.setSize(16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Início
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: inicio,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setDialogState(() => inicio = d);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month,
                              size: 16, color: AppColors.primaryMain),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Início',
                                  style: AppCss.minimumRegular
                                      .setSize(10)
                                      .setColor(Colors.grey[500]!)),
                              Text(
                                DateFormat('dd/MM/yyyy').format(inicio),
                                style: AppCss.minimumBold,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fim
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: fim,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setDialogState(() => fim = d);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month,
                              size: 16, color: AppColors.primaryMain),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fim',
                                  style: AppCss.minimumRegular
                                      .setSize(10)
                                      .setColor(Colors.grey[500]!)),
                              Text(
                                DateFormat('dd/MM/yyyy').format(fim),
                                style: AppCss.minimumBold,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      DateTimeRange(
                        start: inicio,
                        end: DateTime(
                            fim.year, fim.month, fim.day, 23, 59, 59),
                      ),
                    );
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
