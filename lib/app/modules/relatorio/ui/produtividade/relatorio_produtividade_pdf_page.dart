import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_produtividade_view_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';

class RelatorioProdutividadePdfPage {
  final RelatorioProdutividadeModel relatorio;
  final DateTimeRange periodo;
  final UsuarioModel? operador;

  RelatorioProdutividadePdfPage({
    required this.relatorio,
    required this.periodo,
    this.operador,
  });

  static final _fmt = NumberFormat('#,##0.00', 'pt_BR');
  static final _fmtMetros = NumberFormat('#,##0.00', 'pt_BR');

  pw.Page build(Uint8List bytes) => pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(bytes),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) {
          return [
            _buildFiltrosInfo(),
            pw.SizedBox(height: 20),
            _buildKpis(),
            pw.SizedBox(height: 20),
            if (relatorio.porBitola.isNotEmpty) ...[
              _buildTabelaBitola(),
              pw.SizedBox(height: 20),
            ],
            if (relatorio.porDia.isNotEmpty) ...[
              _buildTabelaDia(),
            ],
          ];
        },
      );

  pw.Widget _buildHeader(Uint8List logoBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom:
                pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(pw.MemoryImage(logoBytes), width: 45, height: 45),
              pw.SizedBox(width: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RELATÓRIO DE PRODUTIVIDADE CD',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800)),
                  pw.Text(
                      'Sistema PCP - Controle de Produção Profissional',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                  'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(relatorio.geradoEm)}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Relatório Administrativo',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Documento para conferência e análise de produtividade',
              style:
                  pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildFiltrosInfo() {
    final inicioStr =
        DateFormat('dd/MM/yyyy').format(periodo.start);
    final fimStr = DateFormat('dd/MM/yyyy').format(periodo.end);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Row(
        children: [
          _infoCell('PERÍODO:', '$inicioStr a $fimStr', flex: 2),
          _infoCell(
              'OPERADOR:', operador?.nome ?? 'TODOS',
              flex: 2),
          _infoCell(
              'Nº PRODUÇÕES:',
              relatorio.qtdeProducoes.toString(),
              flex: 1),
        ],
      ),
    );
  }

  pw.Widget _infoCell(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey600)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildKpis() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.blue100),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _kpiItem(
              'TOTAL KG', '${_fmt.format(relatorio.kgTotal)} Kg'),
          _kpiItem('TOTAL METROS',
              '${_fmtMetros.format(relatorio.metrosTotal)} m'),
          _kpiItem('PRODUÇÕES', relatorio.qtdeProducoes.toString()),
        ],
      ),
    );
  }

  pw.Widget _kpiItem(String titulo, String valor) {
    return pw.Column(
      children: [
        pw.Text(titulo,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600)),
        pw.SizedBox(height: 4),
        pw.Text(valor,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900)),
      ],
    );
  }

  pw.Widget _buildTabelaBitola() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PRODUÇÃO POR BITOLA',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['BITOLA', 'KG', 'METROS', 'Nº PROD.'],
          data: [
            ...relatorio.porBitola.map((b) => [
                  '${b.bitola.descricaoReplaced}mm',
                  b.kg.toKg(),
                  '${_fmtMetros.format(b.metros)} m',
                  b.quantidade.toString(),
                ]),
            // Linha de totais
            [
              'TOTAL',
              relatorio.kgTotal.toKg(),
              '${_fmtMetros.format(relatorio.metrosTotal)} m',
              relatorio.qtdeProducoes.toString(),
            ],
          ],
          headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey50),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
          },
        ),
      ],
    );
  }

  pw.Widget _buildTabelaDia() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PRODUÇÃO POR DIA',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['DATA', 'KG', 'METROS', 'Nº PROD.'],
          data: [
            ...relatorio.porDia.map((d) => [
                  DateFormat('dd/MM/yyyy (EEE)', 'pt_BR')
                      .format(d.data),
                  d.kg.toKg(),
                  '${_fmtMetros.format(d.metros)} m',
                  d.quantidade.toString(),
                ]),
            [
              'TOTAL',
              relatorio.kgTotal.toKg(),
              '${_fmtMetros.format(relatorio.metrosTotal)} m',
              relatorio.qtdeProducoes.toString(),
            ],
          ],
          headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey50),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
          },
        ),
      ],
    );
  }
}
