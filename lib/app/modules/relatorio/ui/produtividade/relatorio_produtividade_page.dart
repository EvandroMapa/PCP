import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
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
          stream:
              relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            onPressed: model.relatorio != null
                ? () => showProdutividadeGraficoDialog(context)
                : null,
            icon: Icon(
              Icons.bar_chart_rounded,
              color: model.relatorio != null
                  ? Colors.white
                  : Colors.grey[500],
            ),
          ),
        ),
        StreamOut(
          stream:
              relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            onPressed: () {
              model.mostrarFiltro = !model.mostrarFiltro;
              relatorioCtrl.produtividadeViewModelStream.update();
            },
            icon: const Icon(Icons.sort),
          ),
        ),
        StreamOut(
          stream:
              relatorioCtrl.produtividadeViewModelStream.listen,
          builder: (_, model) => IconButton(
            onPressed: model.relatorio != null
                ? () =>
                    relatorioCtrl.onExportRelatorioProdutividadePDF()
                : null,
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: model.relatorio != null
                  ? Colors.white
                  : Colors.grey[500],
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Produtividade CD',
                style: AppCss.largeBold.setSize(20)),
          ),
          if (model.mostrarFiltro) ...[
            _filtroWidget(model),
            const Divisor(height: 32),
          ],
          if (model.relatorio != null) ...[
            _kpisWidget(model.relatorio!),
            const H(16),
            if (model.relatorio!.porBitola.isNotEmpty)
              _porBitolaWidget(model.relatorio!),
            const H(16),
            if (model.relatorio!.porDia.isNotEmpty)
              _porDiaWidget(model.relatorio!),
          ] else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhuma produção encontrada no período.',
                  style: AppCss.mediumRegular
                      .setColor(Colors.grey[500]!),
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Período
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final range = await _mostrarDialogPeriodo(
                  context, model.periodo);
              if (range != null) {
                model.periodo = range;
                relatorioCtrl.produtividadeViewModelStream
                    .add(model);
                relatorioCtrl.onCreateRelatorioProdutividade();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range,
                      size: 18, color: AppColors.primaryMain),
                  const W(8),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(model.periodo.start)} — ${DateFormat('dd/MM/yyyy').format(model.periodo.end)}',
                    style: AppCss.minimumBold,
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_outlined,
                      size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const H(16),
          // Operador
          AppDropDown<UsuarioModel?>(
            label: 'Operador',
            hasFilter: true,
            item: model.operador,
            itens: [null, ...FirestoreClient.usuarios.data],
            itemLabel: (e) => e?.nome ?? 'TODOS',
            onSelect: (e) {
              model.operador = e;
              relatorioCtrl.produtividadeViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioProdutividade();
            },
          ),
          const H(16),
          // Bitolas
          AppDropDownList<BitolaModel>(
            label: 'Bitolas',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _kpiCard(
            titulo: 'Kg Total',
            valor: relatorio.kgTotal.toKg(),
            icone: Icons.scale_outlined,
            cor: AppColors.primaryMain,
          ),
          const W(12),
          _kpiCard(
            titulo: 'Metros Lineares',
            valor: '${_fmtMetros.format(relatorio.metrosTotal)} m',
            icone: Icons.straighten_outlined,
            cor: Colors.teal,
          ),

        ],
      ),
    );
  }

  Widget _kpiCard({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16, color: cor),
                const W(6),
                Text(titulo,
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[600]!)),
              ],
            ),
            const H(8),
            Text(valor,
                style: AppCss.mediumBold.setColor(cor)),
          ],
        ),
      ),
    );
  }

  // ── POR BITOLA ──────────────────────────────────────────

  Widget _porBitolaWidget(RelatorioProdutividadeModel relatorio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produção por Bitola', style: AppCss.mediumBold),
          const H(8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    border: Border(
                        bottom: BorderSide(
                            color: AppColors.primaryMain
                                .withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('Bitola',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!))),
                      Expanded(
                          child: Text('Kg',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!),
                              textAlign: TextAlign.right)),
                      Expanded(
                          child: Text('Metros',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!),
                              textAlign: TextAlign.right)),

                    ],
                  ),
                ),
                // Linhas
                for (int i = 0;
                    i < relatorio.porBitola.length;
                    i++) ...[
                  _bitolaRow(relatorio.porBitola[i], i.isOdd),
                ],
                // Total
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('TOTAL',
                              style: AppCss.minimumBold.setColor(
                                  AppColors.primaryMain))),
                      Expanded(
                          child: Text(
                              relatorio.kgTotal.toKg(),
                              style: AppCss.minimumBold.setColor(
                                  AppColors.primaryMain),
                              textAlign: TextAlign.right)),
                      Expanded(
                          child: Text(
                              '${_fmtMetros.format(relatorio.metrosTotal)} m',
                              style: AppCss.minimumBold.setColor(
                                  AppColors.primaryMain),
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

  Widget _bitolaRow(ProdutividadePorBitola item, bool isOdd) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOdd
          ? AppColors.primaryMain.withValues(alpha: 0.03)
          : Colors.white,
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(
                  '${item.bitola.descricaoReplaced}mm',
                  style: AppCss.minimumRegular)),
          Expanded(
              child: Text(item.kg.toKg(),
                  style: AppCss.minimumBold,
                  textAlign: TextAlign.right)),
          Expanded(
              child: Text(
                  '${_fmtMetros.format(item.metros)} m',
                  style: AppCss.minimumRegular,
                  textAlign: TextAlign.right)),

        ],
      ),
    );
  }

  // ── POR DIA ─────────────────────────────────────────────

  Widget _porDiaWidget(RelatorioProdutividadeModel relatorio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produção por Dia', style: AppCss.mediumBold),
          const H(8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.teal
                                .withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('Data',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!))),
                      Expanded(
                          child: Text('Kg',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!),
                              textAlign: TextAlign.right)),
                      Expanded(
                          child: Text('Metros',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[700]!),
                              textAlign: TextAlign.right)),

                    ],
                  ),
                ),
                // Linhas
                for (int i = 0;
                    i < relatorio.porDia.length;
                    i++) ...[
                  _diaRow(relatorio.porDia[i], i.isOdd),
                ],
                // Total
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('TOTAL',
                              style: AppCss.minimumBold
                                  .setColor(Colors.teal))),
                      Expanded(
                          child: Text(
                              relatorio.kgTotal.toKg(),
                              style: AppCss.minimumBold
                                  .setColor(Colors.teal),
                              textAlign: TextAlign.right)),
                      Expanded(
                          child: Text(
                              '${_fmtMetros.format(relatorio.metrosTotal)} m',
                              style: AppCss.minimumBold
                                  .setColor(Colors.teal),
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

  Widget _diaRow(ProdutividadePorDia item, bool isOdd) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOdd
          ? Colors.teal.withValues(alpha: 0.03)
          : Colors.white,
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(
                  DateFormat('dd/MM/yyyy (EEE)', 'pt_BR')
                      .format(item.data),
                  style: AppCss.minimumRegular)),
          Expanded(
              child: Text(item.kg.toKg(),
                  style: AppCss.minimumBold,
                  textAlign: TextAlign.right)),
          Expanded(
              child: Text(
                  '${_fmtMetros.format(item.metros)} m',
                  style: AppCss.minimumRegular,
                  textAlign: TextAlign.right)),

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
                  const W(8),
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
                          const W(8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Início',
                                  style: AppCss.minimumRegular
                                      .setSize(10)
                                      .setColor(Colors.grey[500]!)),
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(inicio),
                                style: AppCss.minimumBold,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const H(12),
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
                          const W(8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Fim',
                                  style: AppCss.minimumRegular
                                      .setSize(10)
                                      .setColor(Colors.grey[500]!)),
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(fim),
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
