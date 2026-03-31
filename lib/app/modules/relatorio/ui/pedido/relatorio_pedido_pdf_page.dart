import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum RelatorioPedidoQuantidade { todos, unico }

class RelatorioPedidoPdfPage {
  final RelatorioPedidoModel model;
  final RelatorioPedidoQuantidade quantidade;
  RelatorioPedidoPdfPage(
    this.model, {
    this.quantidade = RelatorioPedidoQuantidade.todos,
  });

  pw.Page build(Uint8List bytes) => pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (context) => _buildHeader(bytes),
        footer: (context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildFiltersInfo(),
          pw.SizedBox(height: 20),
          if ([RelatorioPedidoTipo.totais, RelatorioPedidoTipo.totaisPedidos]
              .contains(model.tipo)) ...[
            _buildTotalsSection(),
            pw.SizedBox(height: 20),
          ],
          if ([RelatorioPedidoTipo.pedidos, RelatorioPedidoTipo.totaisPedidos]
              .contains(model.tipo)) ...[
            _buildPedidosList(),
          ],
        ],
      );

  pw.Widget _buildHeader(Uint8List logoBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
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
                  pw.Text('RELATÓRIO DE PEDIDOS',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sistema de Controle de Produção - PCP',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(model.createdAt)}',
                  style: pw.TextStyle(fontSize: 9)),
              pw.Text('PCP v1.0', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
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
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Relatório Gerencial de Pedidos',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildFiltersInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              _infoCell('CLIENTE:', model.cliente?.nome ?? 'TODOS OS CLIENTES', flex: 2),
              _infoCell('TIPO:', model.tipo.label, flex: 1),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              _infoCell('STATUS:', model.status.map((e) => e.label).join(', '), flex: 2),
              _infoCell('PEDIDOS:', model.pedidos.length.toString(), flex: 1),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoCell(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: '$label ',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTotalsSection() {
    final statusTotals = PedidoProdutoStatus.values
        .map((s) => [s.label, relatorioCtrl.getPedidosTotalPorStatus(s).toKg()])
        .where((e) => e[1] != '0,00kg')
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RESUMO GERAL',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['DESCRIÇÃO', 'PESO TOTAL (KG)'],
          data: [
            ['TOTAL GERAL DE PEDIDOS FILTRADOS', relatorioCtrl.getPedidosTotal().toKg()],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
        ),
        if (statusTotals.isNotEmpty) ...[
          pw.SizedBox(height: 15),
          pw.Text('POR STATUS',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Table.fromTextArray(
            headers: ['STATUS', 'PESO'],
            data: statusTotals,
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildPedidosList() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PEDIDOS DETALHADOS',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        for (final pedido in model.pedidos) ...[
          _buildPedidoItem(pedido),
          pw.SizedBox(height: 15),
        ],
      ],
    );
  }

  pw.Widget _buildPedidoItem(PedidoModel pedido) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PEDIDO: ${pedido.localizador}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('CRIADO EM: ${DateFormat('dd/MM/yyyy HH:mm').format(pedido.createdAt)}',
                    style: pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  _infoCell('CLIENTE:', pedido.cliente.nome, flex: 2),
                  _infoCell('ENTREGA:', pedido.deliveryAt?.text() ?? 'N/D', flex: 1),
                ]),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: ['BITOLA', 'STATUS', 'QUANTIDADE'],
                  data: pedido.produtos.map((p) => [
                    '${p.produto.descricaoReplaced}mm',
                    p.status.status.label.toUpperCase(),
                    p.qtde.toKg()
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1)
                  },
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text('TOTAL DO PEDIDO: ${pedido.getQtdeTotal().toKg()}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
