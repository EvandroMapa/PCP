import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF de Pedido de Cotação — enviado para um único fornecedor (nominal).
/// Aparece somente em pedidos com status [PedidoCompraStatus.pendente].
class PedidoCompraCotacaoPdfPage {
  final List<PedidoCompraModel> itens;
  final FabricanteModel fabricante;
  final String nomeEmpresa;
  final String descricaoEmpresa;
  final String? usuarioNome;

  PedidoCompraCotacaoPdfPage({
    required this.itens,
    required this.fabricante,
    required this.nomeEmpresa,
    required this.descricaoEmpresa,
    this.usuarioNome,
  });

  static final _azulEscuro = PdfColor.fromHex('#1E3A5F');
  static final _azulMedio = PdfColor.fromHex('#2563EB');
  static final _cinzaClaro = PdfColor.fromHex('#F1F5F9');
  static final _cinzaBorda = PdfColor.fromHex('#CBD5E1');
  static final _laranja = PdfColor.fromHex('#EA580C');
  static final _texto = PdfColor.fromHex('#1E293B');
  static final _subtexto = PdfColor.fromHex('#64748B');

  Future<pw.Document> build(Uint8List logoBytes) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        header: (_) => _buildHeader(logoBytes, fontBold),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => [
          _buildInfoBanner(),
          pw.SizedBox(height: 20),
          _buildDestinatario(),
          pw.SizedBox(height: 20),
          _buildTabela(),
          pw.SizedBox(height: 20),
          _buildObservacoes(),
        ],
      ),
    );
    return pdf;
  }

  // ── Cabeçalho ────────────────────────────────────────────────────────────
  pw.Widget _buildHeader(Uint8List logoBytes, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _azulEscuro, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48),
              pw.SizedBox(width: 14),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Empresa',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _azulEscuro,
                    ),
                  ),
                  if (descricaoEmpresa.isNotEmpty)
                    pw.Text(
                      descricaoEmpresa,
                      style: pw.TextStyle(fontSize: 9, color: _subtexto),
                    ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: _laranja,
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'PEDIDO DE COTAÇÃO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: _subtexto),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Banner informativo ───────────────────────────────────────────────────
  pw.Widget _buildInfoBanner() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _cinzaClaro,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _cinzaBorda),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Solicitamos a gentileza de V. Sas. nos enviarem cotação de preço para os materiais abaixo relacionados.',
            style: pw.TextStyle(fontSize: 10, color: _texto),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Por favor, responder informando: preço unitário, prazo de entrega, condições de pagamento e validade da proposta.',
            style: pw.TextStyle(fontSize: 9, color: _subtexto,
                fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ── Destinatário ─────────────────────────────────────────────────────────
  pw.Widget _buildDestinatario() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _cinzaBorda),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DESTINATÁRIO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulMedio,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  fabricante.nome,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto),
                ),
                if (fabricante.temDescricao) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    fabricante.descricao!,
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (fabricante.temContato) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'A/C: ${fabricante.contato!}',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _azulMedio),
                  ),
                ],
                if (fabricante.temWhatsApp) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'WhatsApp: ${fabricante.telefone}',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (fabricante.temEmail) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'E-mail: ${fabricante.email}',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _cinzaBorda),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SOLICITANTE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulMedio,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Nao configurado',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto),
                ),
                if (descricaoEmpresa.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    descricaoEmpresa,
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (usuarioNome != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Responsável: $usuarioNome',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tabela de itens ──────────────────────────────────────────────────────
  pw.Widget _buildTabela() {
    final headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(fontSize: 9, color: _texto);
    final altStyle = pw.TextStyle(fontSize: 9, color: _texto);

    return pw.Table(
      border: pw.TableBorder.all(color: _cinzaBorda, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(32),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _azulEscuro),
          children: [
            _cell('#', headerStyle, center: true),
            _cell('Produto / Bitola', headerStyle),
            _cell('Qtde (kg)', headerStyle, center: true),
            _cell('Preço Unit.', headerStyle, center: true),
            _cell('Total', headerStyle, center: true),
            _cell('Prazo Entrega', headerStyle, center: true),
          ],
        ),
        // Linhas
        for (int i = 0; i < itens.length; i++) ...[
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : _cinzaClaro,
            ),
            children: [
              _cell('${i + 1}', i.isEven ? cellStyle : altStyle,
                  center: true),
              _cell(
                  '${itens[i].produto.nome} - ${itens[i].produto.descricao}',
                  i.isEven ? cellStyle : altStyle),
              _cell(
                  itens[i].quantidade.toStringAsFixed(3),
                  i.isEven ? cellStyle : altStyle,
                  center: true),
              _cell('', i.isEven ? cellStyle : altStyle, center: true),
              _cell('', i.isEven ? cellStyle : altStyle, center: true),
              _cell('', i.isEven ? cellStyle : altStyle, center: true),
            ],
          ),
        ],
        // Total
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: _azulEscuro.shade(0.8),
          ),
          children: [
            _cell('', headerStyle, center: true),
            _cell('TOTAL GERAL', headerStyle),
            _cell(
              '${itens.fold(0.0, (s, i) => s + i.quantidade).toStringAsFixed(3)} kg',
              pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              center: true,
            ),
            _cell('', headerStyle, center: true),
            _cell('', headerStyle, center: true),
            _cell('', headerStyle, center: true),
          ],
        ),
      ],
    );
  }

  // ── Observações / Assinatura ─────────────────────────────────────────────
  pw.Widget _buildObservacoes() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _cinzaClaro,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _cinzaBorda),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Condições de Pagamento:',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _texto),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Validade da Proposta:',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _texto),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Observações:',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _texto),
              ),
              pw.SizedBox(height: 32),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _assinatura(
              'Assinatura do Fornecedor',
              '${fabricante.nome}',
            ),
            _assinatura(
              'Responsável pelo Pedido',
              usuarioNome ?? nomeEmpresa,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _assinatura(String titulo, String nome) {
    return pw.Column(
      children: [
        pw.Container(
          width: 180,
          height: 1,
          color: _cinzaBorda,
        ),
        pw.SizedBox(height: 4),
        pw.Text(titulo,
            style: pw.TextStyle(fontSize: 8, color: _subtexto)),
        pw.Text(nome,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _texto)),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────
  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _cinzaBorda, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 7, color: _subtexto),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _subtexto),
          ),
        ],
      ),
    );
  }

  // ── Utilitário ───────────────────────────────────────────────────────────
  pw.Widget _cell(String text, pw.TextStyle style,
      {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: style,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }
}
