import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_ordem_view_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RelatorioOrdemPdfOrdemPage {
  final RelatorioOrdemModel model;
  final RelatorioOrdensPdfExportarTipo tipo;
  RelatorioOrdemPdfOrdemPage(this.model, this.tipo);

  pw.Page build(Uint8List bytes) => pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RELATÓRIO DE ORDEM DE PRODUÇÃO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(AppColors.black.value),
                  ),
                ),
                pw.Text(
                  model.ordem.localizator,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(AppColors.primaryMain.value),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) => [
          _buildInfoGrid(model.ordem),
          pw.SizedBox(height: 15),
          _buildProdutosTable(model.ordem),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      );

  pw.Widget _buildInfoGrid(OrdemModel ordem) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _infoCell('BITOLA', '${ordem.produto.descricaoReplaced} mm', flex: 2),
              _infoCell(
                'MATÉRIA PRIMA',
                ordem.materiaPrima != null
                    ? '${ordem.materiaPrima!.fabricanteModel.nome} - ${ordem.materiaPrima!.corridaLote}'
                    : 'NÃO DEFINIDA',
                flex: 3,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _infoCell(
                'CRIADO EM',
                DateFormat('dd/MM/yyyy HH:mm').format(ordem.createdAt),
                flex: 2,
              ),
              _infoCell(
                'TOTAL DA ORDEM',
                '${ordem.produtos.map((e) => e.qtde).fold(.0, (a, b) => a + b).toStringAsFixed(2)} kg',
                flex: 3,
                isBoldValue: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoCell(String label, String value,
      {int flex = 1, bool isBoldValue = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProdutosTable(OrdemModel ordem) {
    final headers = ['PEDIDO / TIPO', 'CLIENTE / OBRA', 'PESO (kg)', 'ENTREGA'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: ordem.produtos.map((p) {
        return [
          '${p.pedido.localizador}\n(${p.pedido.tipo.name.toUpperCase()})',
          '${p.cliente.nome}\n${p.obra.descricao}',
          p.qtde.toStringAsFixed(2),
          p.pedido.deliveryAt?.text() ?? '-',
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.primaryMain.value),
      ),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      headerHeight: 20,
      cellPadding: const pw.EdgeInsets.all(5),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTAS / OBSERVAÇÕES:',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Container(
          height: 40,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              children: [
                pw.Container(
                  width: 150,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text('Assinatura do Responsável', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
