import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RelatorioElementoPdfPage {
  final PedidoModel pedido;
  final List<ElementoModel> elementos;

  RelatorioElementoPdfPage({
    required this.pedido,
    required this.elementos,
  });

  pw.Page build(Uint8List logoBytes) => pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(logoBytes),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) {
          final fmt = NumberFormat('#,##0.000', 'pt_BR');
          
          // Agrupar totais por bitola para o resumo
          final Map<String, double> resumoBitola = {};
          for (final el in elementos) {
            for (final pos in el.posicoes) {
              final pesoTotal = pos.pesoKg * el.qtde;
              final label = pos.produto?.labelMinified ?? pos.produtoId;
              resumoBitola[label] = (resumoBitola[label] ?? 0) + pesoTotal;
            }
          }

          return [
            _buildOrderInfo(),
            pw.SizedBox(height: 20),
            pw.Text('ELEMENTOS DETALHADOS',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 10),
            ...elementos.map((el) => _buildElementItem(el, fmt)),
            pw.SizedBox(height: 20),
            _buildSummaryTable(resumoBitola, fmt),
          ];
        },
      );

  pw.Widget _buildHeader(Uint8List logoBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5)),
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
                  pw.Text('RELATÓRIO TÉCNICO DE ELEMENTOS',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.Text('Sistema PCP - Gestão de Produção Inteligente',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Pedido: ${pedido.localizador}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento gerado eletronicamente para controle de fábrica',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildOrderInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Column(
        children: [
          pw.Row(children: [
            _infoCell('CLIENTE:', pedido.cliente.nome, flex: 3),
            _infoCell('OBRA:', pedido.obra.descricao, flex: 3),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _infoCell('TIPO:', pedido.tipo.name.toUpperCase()),
            _infoCell('ENTREGA:', pedido.deliveryAt != null ? DateFormat('dd/MM/yyyy').format(pedido.deliveryAt!) : 'N/D'),
            _infoCell('TOTAL PESO:', pedido.getQtdeTotal().toKg()),
          ]),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildElementItem(ElementoModel el, NumberFormat fmt) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: PdfColors.blueGrey800,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ELEMENTO: ${el.nome.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Row(children: [
                  pw.Text('QTD: ${el.qtde}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.SizedBox(width: 15),
                  pw.Text('PESO TOTAL: ${fmt.format(el.pesoTotal)} kg',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ]),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['POSIÇÃO', 'Nº OS', 'BITOLA', 'PESO UNIT.', 'SUBTOTAL'],
            data: el.posicoes
                .map((p) => [
                      p.nome,
                      p.numeroOs,
                      p.produto?.labelMinified ?? p.produtoId,
                      '${fmt.format(p.pesoKg)} kg',
                      '${fmt.format(p.pesoKg * el.qtde)} kg',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryTable(Map<String, double> resumo, NumberFormat fmt) {
    final double totalGeral = resumo.values.fold(0, (a, b) => a + b);
    final sortedKeys = resumo.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RESUMO CONSOLIDADO POR BITOLA',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['BITOLA', 'PESO TOTAL (KG)', 'PROGRESSO VISUAL'],
          data: sortedKeys.map((k) {
            final peso = resumo[k]!;
            final percent = totalGeral > 0 ? peso / totalGeral : 0.0;
            return [
              k,
              fmt.format(peso),
              '${(percent * 100).toStringAsFixed(1)}%',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
          cellStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
          },
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PESO TOTAL GERAL DO PEDIDO:',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Text('${fmt.format(totalGeral)} kg',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            ],
          ),
        ),
      ],
    );
  }
}
