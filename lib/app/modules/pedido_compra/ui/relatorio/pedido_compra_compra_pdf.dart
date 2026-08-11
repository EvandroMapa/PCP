import 'dart:typed_data';

import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF de Pedido de Compra — formal, endereçado ao fornecedor.
/// Aparece somente em pedidos com status [PedidoCompraStatus.confirmado].
class PedidoCompraCompraPdfPage {
  final List<PedidoCompraModel> itens;
  final FabricanteModel fabricante;
  final String nomeEmpresa;
  final String descricaoEmpresa;
  final String? usuarioNome;
  final String numeroPedido;
  final String razaoSocial;
  final String endereco;
  final String telefone;
  final String email;
  final String redesSociais;
  final String cnpj;

  PedidoCompraCompraPdfPage({
    required this.itens,
    required this.fabricante,
    required this.nomeEmpresa,
    required this.descricaoEmpresa,
    this.usuarioNome,
    required this.numeroPedido,
    this.razaoSocial = '',
    this.endereco = '',
    this.telefone = '',
    this.email = '',
    this.redesSociais = '',
    this.cnpj = '',
  });

  /// Nome a exibir no cabeçalho — prioriza razão social, fallback para nome fantasia.
  String get _nomeExibicao =>
      razaoSocial.isNotEmpty ? razaoSocial : (nomeEmpresa.isNotEmpty ? nomeEmpresa : 'Empresa');

  static final _azulEscuro = PdfColor.fromHex('#0F172A');
  static final _azulMedio = PdfColor.fromHex('#1D4ED8');
  static final _azulClaro = PdfColor.fromHex('#EFF6FF');
  static final _verde = PdfColor.fromHex('#15803D');
  static final _cinzaClaro = PdfColor.fromHex('#F8FAFC');
  static final _cinzaBorda = PdfColor.fromHex('#CBD5E1');
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
        header: (_) => _buildHeader(logoBytes),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => [
          _buildEnderecamento(),
          pw.SizedBox(height: 18),
          _buildTabela(),
          pw.SizedBox(height: 18),
          _buildCondicoes(),
          pw.SizedBox(height: 24),
          _buildAssinaturas(),
        ],
      ),
    );
    return pdf;
  }

  // ── Cabeçalho ────────────────────────────────────────────────────────────
  pw.Widget _buildHeader(Uint8List logoBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        children: [
          // Faixa superior — logo + dados da empresa (sem título sobreposto)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _azulEscuro,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 40, height: 40),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _nomeExibicao,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    if (cnpj.isNotEmpty)
                      pw.Text(
                        'CNPJ: $cnpj',
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey300),
                      ),
                    if (endereco.isNotEmpty)
                      pw.Text(
                        endereco,
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey300),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Faixa de data
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: _azulMedio,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Data de Emissão: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold),
                ),
                if (itens.isNotEmpty && itens.first.dataPrevista != null)
                  pw.Text(
                    'Prazo Previsto: ${DateFormat('dd/MM/yyyy').format(itens.first.dataPrevista!)}',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold),
                  ),
                pw.Text(
                  'Responsável: ${usuarioNome ?? '-'}',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.white),
                ),
              ],
            ),
          ),
          // Faixa de título em destaque — ORDEM DE COMPRA
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              color: _azulClaro,
              border: pw.Border.all(color: _azulMedio.shade(0.4), width: 1),
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(6),
                bottomRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'ORDEM DE COMPRA',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulMedio,
                    letterSpacing: 2.0,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Nº $numeroPedido',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulEscuro,
                    letterSpacing: 0.5,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Endereçamento ────────────────────────────────────────────────────────
  pw.Widget _buildEnderecamento() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _azulClaro,
              border: pw.Border.all(color: _azulMedio.shade(0.3)),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AO FORNECEDOR',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulMedio,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 8),
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
                pw.SizedBox(height: 6),
                if (fabricante.temWhatsApp)
                  pw.Text(
                    'WhatsApp: ${fabricante.telefone}',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
                if (fabricante.temEmail)
                  pw.Text(
                    'E-mail: ${fabricante.email}',
                    style: pw.TextStyle(fontSize: 9, color: _subtexto),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _cinzaClaro,
              border: pw.Border.all(color: _cinzaBorda),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DADOS DO PEDIDO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _subtexto,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 8),
                _dadoRow('Nº Pedido', numeroPedido),
                _dadoRow(
                    'Total de Itens', '${itens.length}'),
                _dadoRow(
                  'Total (kg)',
                  '${itens.fold(0.0, (s, i) => s + i.quantidade).toStringAsFixed(3)} kg',
                ),
                _dadoRow('Status', 'CONFIRMADO'),
                if (itens.isNotEmpty && itens.first.dataPrevista != null)
                  _dadoRow(
                    'Prev. Entrega',
                    DateFormat('dd/MM/yyyy').format(itens.first.dataPrevista!),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _dadoRow(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _subtexto)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _texto)),
        ],
      ),
    );
  }

  // ── Tabela ───────────────────────────────────────────────────────────────
  pw.Widget _buildTabela() {
    final headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(fontSize: 9, color: _texto);
    final altStyle =
        pw.TextStyle(fontSize: 9, color: _texto);

    double totalKg = 0;
    for (final item in itens) {
      totalKg += item.quantidade;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _azulEscuro,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'RELAÇÃO DE MATERIAIS SOLICITADOS',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _cinzaBorda, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(3.5),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: _azulMedio),
              children: [
                _cell('#', headerStyle, center: true),
                _cell('Produto / Bitola', headerStyle),
                _cell('Qtde (kg)', headerStyle, center: true),
                _cell('Preço Unit. (R\$)', headerStyle, center: true),
                _cell('Total (R\$)', headerStyle, center: true),
              ],
            ),
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
                    i.isEven ? cellStyle : altStyle,
                  ),
                  _cell(
                    itens[i].quantidade.toStringAsFixed(3),
                    i.isEven ? cellStyle : altStyle,
                    center: true,
                  ),
                  _cell('', i.isEven ? cellStyle : altStyle, center: true),
                  _cell('', i.isEven ? cellStyle : altStyle, center: true),
                ],
              ),
            ],
            // Totais
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: _verde.shade(0.8),
              ),
              children: [
                _cell('', headerStyle, center: true),
                _cell('TOTAL GERAL',
                    pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    )),
                _cell(
                  '${totalKg.toStringAsFixed(3)} kg',
                  pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  center: true,
                ),
                _cell('',
                    pw.TextStyle(
                        fontSize: 9, color: PdfColors.white),
                    center: true),
                _cell('',
                    pw.TextStyle(
                        fontSize: 9, color: PdfColors.white),
                    center: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Condições ────────────────────────────────────────────────────────────
  pw.Widget _buildCondicoes() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _cinzaClaro,
        border: pw.Border.all(color: _cinzaBorda),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CONDIÇÕES GERAIS',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _subtexto,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Condição de Pagamento:',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _texto)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 24,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(
                            color: _cinzaBorda, width: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Local de Entrega:',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _texto)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 24,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(
                            color: _cinzaBorda, width: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Assinaturas ──────────────────────────────────────────────────────────
  pw.Widget _buildAssinaturas() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _assinaturaBloco('Autorizado por', usuarioNome ?? _nomeExibicao),
        _assinaturaBloco('Recebido por', fabricante.nome),
        _assinaturaBloco('Data do Aceite', '____/____/________'),
      ],
    );
  }

  pw.Widget _assinaturaBloco(String titulo, String nome) {
    return pw.Column(
      children: [
        pw.Container(
          width: 150,
          height: 0.5,
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
      margin: const pw.EdgeInsets.only(top: 8),
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
            'Documento gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}  |  Ordem Nº $numeroPedido',
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
