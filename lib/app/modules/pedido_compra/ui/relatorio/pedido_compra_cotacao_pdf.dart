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
  final String razaoSocial;
  final String endereco;
  final String telefone;
  final String email;
  final String redesSociais;
  final String cnpj;

  PedidoCompraCotacaoPdfPage({
    required this.itens,
    required this.fabricante,
    required this.nomeEmpresa,
    required this.descricaoEmpresa,
    this.usuarioNome,
    this.razaoSocial = '',
    this.endereco = '',
    this.telefone = '',
    this.email = '',
    this.redesSociais = '',
    this.cnpj = '',
  });

  static final _azulEscuro = PdfColor.fromHex('#1E3A5F');
  static final _azulMedio = PdfColor.fromHex('#2563EB');
  static final _cinzaClaro = PdfColor.fromHex('#F1F5F9');
  static final _cinzaBorda = PdfColor.fromHex('#CBD5E1');
  static final _laranja = PdfColor.fromHex('#EA580C');
  static final _texto = PdfColor.fromHex('#1E293B');
  static final _subtexto = PdfColor.fromHex('#64748B');

  /// Nome a exibir no cabeçalho — prioriza razão social, fallback para nome fantasia.
  String get _nomeExibicao =>
      razaoSocial.isNotEmpty ? razaoSocial : (nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Empresa');

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
          pw.SizedBox(height: 32),
          _buildAssinaturaResponsavel(),
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
                    _nomeExibicao,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _azulEscuro,
                    ),
                  ),
                  if (cnpj.isNotEmpty)
                    pw.Text(
                      'CNPJ: $cnpj',
                      style: pw.TextStyle(fontSize: 8, color: _subtexto),
                    ),
                  if (endereco.isNotEmpty)
                    pw.Text(
                      endereco,
                      style: pw.TextStyle(fontSize: 8, color: _subtexto),
                    ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
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
                  _nomeExibicao,
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto),
                ),
                if (razaoSocial.isNotEmpty && nomeEmpresa.isNotEmpty && razaoSocial != nomeEmpresa) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    nomeEmpresa,
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (cnpj.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'CNPJ: $cnpj',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (endereco.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    endereco,
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (telefone.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Tel: $telefone',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    email,
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                ],
                if (redesSociais.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    redesSociais,
                    style: pw.TextStyle(fontSize: 8, color: _subtexto),
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
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _azulEscuro),
          children: [
            _cell('#', headerStyle, center: true),
            _cell('Produto / Bitola', headerStyle),
            _cell('Qtde (kg)', headerStyle, center: true),
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
          ],
        ),
      ],
    );
  }

  // ── Assinatura do Responsável ─────────────────────────────────────────────
  pw.Widget _buildAssinaturaResponsavel() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          children: [
            pw.Container(
              width: 200,
              height: 1,
              color: _cinzaBorda,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Responsável pelo Pedido',
                style: pw.TextStyle(fontSize: 8, color: _subtexto)),
            pw.Text(usuarioNome ?? _nomeExibicao,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _texto)),
          ],
        ),
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

