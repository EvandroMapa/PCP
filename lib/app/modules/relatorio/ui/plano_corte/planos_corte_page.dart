import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_gravado_model.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PlanosCortePage extends StatefulWidget {
  const PlanosCortePage({super.key});

  @override
  State<PlanosCortePage> createState() => _PlanosCortePageState();
}

class _PlanosCortePageState extends State<PlanosCortePage> {
  List<PlanoCorteGravadoModel> _planos = [];
  bool _carregando = true;
  String? _exportandoId;

  @override
  void initState() {
    super.initState();
    setWebTitle('Planos de Corte');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([
        Tooltip(
          message: 'Novo Plano de Corte',
          child: IconButton(
            onPressed: () async {
              await push(context, const PlanoCorteRelatorioPage());
              _carregarPlanos();
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ]);
    });
    _carregarPlanos();
  }

  Future<void> _carregarPlanos() async {
    setState(() => _carregando = true);
    try {
      final data = await SupabaseService.client
          .from('planos_corte')
          .select()
          .order('created_at', ascending: false);
      _planos =
          data.map((e) => PlanoCorteGravadoModel.fromSupabaseMap(e)).toList();
    } catch (_) {
      _planos = [];
    }
    setState(() => _carregando = false);
  }

  // ─── Excluir ──────────────────────────────────────────────────────────────
  Future<void> _excluirPlano(PlanoCorteGravadoModel plano) async {
    // Plano executado não pode ser excluído
    if (plano.status == 'executado') {
      NotificationService.showNegative(
        'Plano protegido',
        'Plano executado não pode ser excluído. Cancele a execução antes.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir plano de corte?'),
        content: Text(
            'Deseja excluir o plano "${plano.ordemLocalizator}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await SupabaseService.client
          .from('planos_corte')
          .delete()
          .eq('id', plano.id);
      _carregarPlanos();
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao excluir',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ─── PDF do plano salvo ───────────────────────────────────────────────────
  Future<void> _exportarPdfSalvo(PlanoCorteGravadoModel plano) async {
    setState(() => _exportandoId = plano.id);
    try {
    final logoBytes = await LogoHelper.logoBytesForPdf();
    final pdf = pw.Document();
    final rJson = plano.resultadoJson;

    final barrasUsadas = (rJson['barras_usadas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pecasNaoAlocadas = (rJson['pecas_nao_alocadas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      header: (ctx) => _pdfHeader(logoBytes, plano),
      footer: (ctx) => _pdfFooter(ctx),
      build: (ctx) {
        final widgets = <pw.Widget>[];

        // KPIs
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            border: pw.Border.all(color: PdfColors.blueGrey200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            _pdfKpi('Barras', '${plano.totalBarrasUsadas}'),
            _pdfKpi('Aproveit.', '${plano.percentualAproveitamento.toStringAsFixed(1)}%'),
            _pdfKpi('Sobra Total', plano.totalSobra.toStringAsFixed(1)),
            if (pecasNaoAlocadas.isNotEmpty)
              _pdfKpi('Faltaram', '${pecasNaoAlocadas.length} pç', cor: PdfColors.red700),
          ]),
        ));
        widgets.add(pw.SizedBox(height: 10));

        // Agrupar layouts idênticos
        final layouts = _agruparLayoutsSalvo(barrasUsadas);
        for (int i = 0; i < layouts.length; i++) {
          widgets.add(_pdfBarraBloco(layouts[i], i + 1));
          widgets.add(pw.SizedBox(height: 6));
        }

        // Peças não alocadas
        if (pecasNaoAlocadas.isNotEmpty) {
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PEÇAS NÃO ALOCADAS (${pecasNaoAlocadas.length})',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                pw.SizedBox(height: 4),
                ...pecasNaoAlocadas.map((p) => pw.Text(
                      '${p['pedido_localizador']} · ${p['elemento_nome']} · OS ${p['numero_os']} — ${(p['compr_corte'] ?? 0).toStringAsFixed(1)}',
                      style: const pw.TextStyle(fontSize: 7),
                    )),
              ],
            ),
          ));
        }

        return widgets;
      },
    ));

    final bytes = await pdf.save();
    final nome = 'plano_corte_${plano.ordemLocalizator.toLowerCase()}_${plano.createdAt.toFileName()}.pdf';
    await downloadPDF(nome, '/relatorio/plano_corte/', bytes);
    } finally {
      if (mounted) setState(() => _exportandoId = null);
    }
  }

  // ─── Helpers PDF ──────────────────────────────────────────────────────────

  List<_LayoutSalvo> _agruparLayoutsSalvo(List<Map<String, dynamic>> barras) {
    final List<_LayoutSalvo> layouts = [];
    for (final barra in barras) {
      final cortes = (barra['cortes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final chave = '${barra['comprimento_total']}_${cortes.map((c) => (c['compr_corte'] ?? 0).toStringAsFixed(2)).join('|')}';
      final existente = layouts.where((l) => l.chave == chave).firstOrNull;
      if (existente != null) {
        existente.quantidade++;
      } else {
        layouts.add(_LayoutSalvo(barraJson: barra, chave: chave));
      }
    }
    return layouts;
  }

  pw.Widget _pdfHeader(dynamic logoBytes, PlanoCorteGravadoModel plano) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            pw.Image(pw.MemoryImage(logoBytes), width: 36, height: 36),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PLANO DE CORTE',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                pw.Text('${plano.ordemLocalizator} — ${plano.bitolaDescricao}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ]),
          pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(plano.createdAt),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento gerado eletronicamente',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfKpi(String label, String valor, {PdfColor cor = PdfColors.blueGrey800}) {
    return pw.Expanded(
      child: pw.Column(children: [
        pw.Text(valor, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: cor)),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ]),
    );
  }

  pw.Widget _pdfBarraBloco(_LayoutSalvo layout, int numero) {
    final barra = layout.barraJson;
    final cortes = (barra['cortes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final comprTotal = (barra['comprimento_total'] ?? 0).toDouble();
    final comprUsado = cortes.fold(0.0, (sum, c) => sum + ((c['compr_corte'] ?? 0) as num).toDouble());
    final sobra = comprTotal - comprUsado;
    final pctUso = comprTotal > 0 ? (comprUsado / comprTotal) * 100 : 0.0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: PdfColors.blueGrey800,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LAYOUT ${numero.toString().padLeft(2, '0')} — Compr. ${comprTotal.toStringAsFixed(1)} — Repetir ${layout.quantidade} vez${layout.quantidade > 1 ? 'es' : ''}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('Uso: ${pctUso.toStringAsFixed(1)}%  |  Sobra: ${sobra.toStringAsFixed(1)}',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ],
          ),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['Localizador', 'Elemento', 'OS', 'Compr. Corte'],
          data: cortes.map((c) => [
            c['pedido_localizador'] ?? '',
            c['elemento_nome'] ?? '',
            c['numero_os'] ?? '',
            ((c['compr_corte'] ?? 0) as num).toDouble().toStringAsFixed(1),
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerLeft,
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.2),
          },
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_planos.isEmpty) {
      return const Center(child: EmptyData());
    }

    return RefreshIndicator(
      onRefresh: _carregarPlanos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _planos.length,
        itemBuilder: (_, i) => _itemPlanoWidget(_planos[i]),
      ),
    );
  }

  Widget _itemPlanoWidget(PlanoCorteGravadoModel plano) {
    final isExecutado = plano.status == 'executado';
    final aprovCor = isExecutado
        ? Colors.green[700]!
        : plano.percentualAproveitamento >= 90
            ? Colors.green[700]!
            : plano.percentualAproveitamento >= 70
                ? Colors.blue[600]!
                : Colors.orange[600]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          await push(context, PlanoCorteRelatorioPage(planoParaEditar: plano));
          _carregarPlanos();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
        decoration: BoxDecoration(
          color: isExecutado ? Colors.green[50] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExecutado ? Colors.green[300]! : const Color(0xFFE2E8F0),
            width: isExecutado ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Borda lateral
              Container(width: 5, color: aprovCor),
              // Conteúdo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha 1: Ordem + Bitola + Data
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${plano.ordemLocalizator} — ${plano.bitolaDescricao}',
                              style: AppCss.smallBold.setSize(14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yy HH:mm')
                                .format(plano.createdAt),
                            style: AppCss.minimumRegular
                                .setSize(11)
                                .setColor(Colors.grey[400]!),
                          ),
                          if (isExecutado) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green[700],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('EXECUTADO',
                                  style: AppCss.minimumBold
                                      .setSize(10)
                                      .setColor(Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const H(6),
                      // Linha 2: KPIs + botões
                      Row(
                        children: [
                          _badge(
                            Icons.straighten,
                            '${plano.totalBarrasUsadas} barras',
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _badge(
                            Icons.pie_chart,
                            '${plano.percentualAproveitamento.toStringAsFixed(1)}%',
                            aprovCor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${plano.totalElementos} elem. · ${plano.totalPosicoes} pos.',
                            style: AppCss.minimumRegular
                                .setSize(11)
                                .setColor(Colors.grey[500]!),
                          ),
                          const Spacer(),
                          // Botão PDF
                          Tooltip(
                            message: 'Exportar PDF',
                            child: InkWell(
                              onTap: _exportandoId == plano.id
                                  ? null
                                  : () => _exportarPdfSalvo(plano),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _exportandoId == plano.id
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.blue[700],
                                        ),
                                      )
                                    : Icon(Icons.picture_as_pdf,
                                        size: 18, color: Colors.blue[700]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Botão Excluir (oculto para planos executados)
                          if (plano.status != 'executado')
                            Tooltip(
                              message: 'Excluir',
                              child: InkWell(
                                onTap: () => _excluirPlano(plano),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red[700]),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Linha 3: Descrição
                      if (plano.descricao.isNotEmpty) ...[
                        const H(4),
                        Text(
                          plano.descricao,
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(Colors.grey[600]!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _badge(IconData icone, String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: cor),
          const SizedBox(width: 4),
          Text(texto,
              style: AppCss.minimumBold.setSize(11).setColor(cor)),
        ],
      ),
    );
  }
}

// ─── Classe auxiliar para agrupamento de layouts salvos ──────────────────────
class _LayoutSalvo {
  final Map<String, dynamic> barraJson;
  final String chave;
  int quantidade;

  _LayoutSalvo({
    required this.barraJson,
    required this.chave,
    this.quantidade = 1,
  });
}
