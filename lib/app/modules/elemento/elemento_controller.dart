import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';

final elementoCtrl = ElementoController();

class ElementoController {
  static final ElementoController _instance = ElementoController._();
  ElementoController._();
  factory ElementoController() => _instance;

  final AppStream<List<ElementoModel>> elementosStream =
      AppStream<List<ElementoModel>>.seed([]);
  List<ElementoModel> get elementos => elementosStream.value;

  final AppStream<ImportProgress?> importProgressStream =
      AppStream<ImportProgress?>.seed(null);

  bool _cancelImport = false;
  String? _currentPedidoId;

  // ─── INICIALIZAÇÃO ────────────────────────────────────────────────────────
  Future<void> onInit(String pedidoId) async {
    if (_currentPedidoId == pedidoId) return;
    _currentPedidoId = pedidoId;
    await onFetch(pedidoId);
  }

  void onDispose() {
    _currentPedidoId = null;
    elementosStream.add([]);
    importProgressStream.add(null);
  }

  void cancelImport() => _cancelImport = true;

  // ─── BUSCAR ───────────────────────────────────────────────────────────────
  Future<void> onFetch(String pedidoId) async {
    try {
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedidoId)
          .order('created_at');

      final List<ElementoModel> result = [];
      for (final e in elementosRaw) {
        final posicoesRaw = await SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .eq('elemento_id', e['id'].toString())
            .order('created_at');

        result.add(ElementoModel.fromSupabaseMap(
          e,
          posicoesRaw: List<Map<String, dynamic>>.from(posicoesRaw),
        ));
      }

      elementosStream.add(result);
    } catch (e) {
      print('ElementoController.onFetch erro: $e');
      elementosStream.add([]);
    }
  }

  // ─── SALVAR ELEMENTO ──────────────────────────────────────────────────────
  Future<void> onSaveElemento(
      ElementoCreateModel form, String pedidoId) async {
    try {
      final elementoMap = {
        'id': form.id,
        'pedido_id': pedidoId,
        'nome': form.nome.text,
        'qtde': form.qtdeInt,
      };

      await SupabaseService.client
          .from('elementos')
          .upsert(elementoMap);

      // Salva as posições
      if (form.isEdit) {
        // Remove as posições antigas para reinserir
        await SupabaseService.client
            .from('elemento_posicoes')
            .delete()
            .eq('elemento_id', form.id);
      }

      for (final posicao in form.posicoes) {
        if (!posicao.isValid) continue;
        await SupabaseService.client.from('elemento_posicoes').upsert({
          'id': posicao.id,
          'elemento_id': form.id,
          'nome': posicao.nome.controller.text,
          'numero_os': posicao.numeroOs.controller.text,
          'produto_id': posicao.produto!.id,
          'peso_kg': posicao.pesoDouble,
        });
      }

      await onFetch(pedidoId);
    } catch (e) {
      print('ElementoController.onSaveElemento erro: $e');
    }
  }

  // ─── DELETAR ELEMENTO ─────────────────────────────────────────────────────
  Future<void> onDeleteElemento(ElementoModel elemento) async {
    try {
      // ON DELETE CASCADE apaga as posições automaticamente
      await SupabaseService.client
          .from('elementos')
          .delete()
          .eq('id', elemento.id);

      await onFetch(elemento.pedidoId);
    } catch (e) {
      print('ElementoController.onDeleteElemento erro: $e');
    }
  }

  // ─── DELETAR TODOS OS ELEMENTOS ───────────────────────────────────────────
  Future<void> onDeleteAllElementos(String pedidoId) async {
    try {
      await SupabaseService.client
          .from('elementos')
          .delete()
          .eq('pedido_id', pedidoId);

      await onFetch(pedidoId);
    } catch (e) {
      print('ElementoController.onDeleteAllElementos erro: $e');
    }
  }

  // ─── IMPORTAR PDF ─────────────────────────────────────────────────────────
  Future<void> onGeneratePDF(PedidoModel pedido) async {
    showLoadingDialog();
    try {
      final pdf = pw.Document();
      final img = await rootBundle.load('assets/images/logo.png');
      final imageBytes = img.buffer.asUint8List();
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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          header: (context) => _buildPDFHeader(imageBytes, pedido),
          footer: (context) => _buildPDFFooter(context),
          build: (context) => [
            _buildPDFOrderInfo(pedido),
            pw.SizedBox(height: 20),
            pw.Text('ELEMENTOS DO PEDIDO',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...elementos.map((el) => _buildPDFElementItem(el, fmt)),
            pw.SizedBox(height: 20),
            _buildPDFSummaryTable(resumoBitola, fmt),
          ],
        ),
      );

      final name =
          "elementos_${pedido.localizador.toLowerCase()}_${DateTime.now().toFileName()}.pdf";
      await downloadPDF(name, '/relatorio/elementos/', await pdf.save());
    } catch (e, stack) {
      print('Erro ao gerar PDF: $e');
      print(stack);
      NotificationService.showNegative('Erro', 'Falha ao gerar o PDF: $e');
    }
    Navigator.pop(contextGlobal);
  }

  pw.Widget _buildPDFHeader(Uint8List logo, PedidoModel pedido) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(pw.MemoryImage(logo), width: 40, height: 40),
              pw.SizedBox(width: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RELATÓRIO TÉCNICO DE ELEMENTOS',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Sistema PCP - Controle de Produção',
                      style:
                          pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Pedido: ${pedido.localizador}',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento para conferência interna de produção',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildPDFOrderInfo(PedidoModel pedido) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Row(children: [
            _pdfInfoCell('CLIENTE:', pedido.cliente.nome, flex: 2),
            _pdfInfoCell('OBRA:', pedido.obra.descricao, flex: 2),
          ]),
          pw.SizedBox(height: 5),
          pw.Row(children: [
            _pdfInfoCell('ENTREGA:',
                pedido.deliveryAt != null ? DateFormat('dd/MM/yyyy').format(pedido.deliveryAt!) : 'N/D'),
            _pdfInfoCell('TIPO:', pedido.tipo.name.toUpperCase()),
          ]),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoCell(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: '$label ',
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPDFElementItem(ElementoModel el, NumberFormat fmt) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
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
                pw.Text('ELEMENTO: ${el.nome} (x${el.qtde})',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('PESO TOTAL EL: ${fmt.format(el.pesoTotal)} kg',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Table.fromTextArray(
            headers: ['POSIÇÃO', 'OS', 'BITOLA', 'PESO UNIT.', 'PESO TOTAL'],
            data: el.posicoes
                .map((p) => [
                      p.nome,
                      p.numeroOs,
                      p.produto?.labelMinified ?? p.produtoId,
                      '${fmt.format(p.pesoKg)} kg',
                      '${fmt.format(p.pesoKg * el.qtde)} kg',
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryTable(Map<String, double> resumo, NumberFormat fmt) {
    final double totalGeral = resumo.values.fold(0, (a, b) => a + b);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('RESUMO POR BITOLA',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['BITOLA', 'PESO TOTAL (KG)'],
          data: [
            ...resumo.entries
                .map((e) => [e.key, '${fmt.format(e.value)} kg'])
                .toList(),
            ['TOTAL GERAL', '${fmt.format(totalGeral)} kg'],
          ],
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1)
          },
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> onImportPDF(
      Uint8List bytes, PedidoModel pedido) async {
    String rawText = '';
    _cancelImport = false;
    final List<String> createdElementIds = [];

    try {
      importProgressStream.add(ImportProgress(status: 'Extraindo texto do PDF...'));
      
      final syncfusion.PdfDocument document = syncfusion.PdfDocument(inputBytes: bytes);
      rawText = syncfusion.PdfTextExtractor(document).extractText();
      document.dispose();

      if (rawText.trim().isEmpty) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'PDF parece estar sem texto (pode ser uma imagem).',
          'rawText': ''
        };
      }

      final lines = rawText.split('\n').map((l) => l.trim()).toList();
      String? currentElementName;
      List<ElementoPosicaoCreateModel> currentPosicoes = [];
      final List<ElementoCreateModel> novosElementos = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;

        // 1. Identificar Mudança de Elemento (Vertical)
        if (i + 2 < lines.length &&
            lines[i + 1] == 'Elemento' &&
            lines[i + 2] == 'Ok') {
          if (currentElementName != null && currentPosicoes.isNotEmpty) {
            final xMatch = RegExp(r'X\s?(\d+)', caseSensitive: false)
                .firstMatch(currentElementName!);
            final extractedQtde =
                xMatch != null ? int.tryParse(xMatch.group(1)!) ?? 1 : 1;

            novosElementos.add(ElementoCreateModel()
              ..nome.text = currentElementName!
              ..qtde.text = extractedQtde.toString()
              ..posicoes.addAll(currentPosicoes));
          }
          currentElementName = line;
          currentPosicoes = [];
          i += 2;
          continue;
        }

        // 2. Tentar coletar um bloco de 7 linhas (Modo Vertical)
        if (currentElementName != null && i + 6 < lines.length) {
          final qtdeStr = lines[i];
          final posNome = lines[i + 2];
          final bitolaStr = lines[i + 3].replaceAll(',', '.');
          final pesoStr = lines[i + 5].replaceAll(',', '.');
          final osStr = lines[i + 6];

          final bitola = double.tryParse(bitolaStr);
          final peso = double.tryParse(pesoStr);
          final qtde = double.tryParse(qtdeStr.replaceAll(',', '.'));

          if (bitola != null && peso != null && qtde != null) {
            final xMatch = RegExp(r'X\s?(\d+)', caseSensitive: false)
                .firstMatch(currentElementName!);
            final extractedQtde =
                xMatch != null ? int.tryParse(xMatch.group(1)!) ?? 1 : 1;
            final pesoUnitario = peso / extractedQtde;

            final pos = ElementoPosicaoCreateModel();
            pos.nome.text = posNome;
            pos.numeroOs.text = osStr;
            pos.pesoKg.text = pesoUnitario.toStringAsFixed(3);

            final bMatch = bitola.toString().replaceAll(RegExp(r'\.0$'), '');
            pos.produto = pedido
                .getProdutos()
                .map((e) => e.produto)
                .where((p) =>
                    p.nome.contains(bMatch) || p.labelMinified.contains(bMatch))
                .firstOrNull;

            if (pos.produto != null) currentPosicoes.add(pos);
            i += 6;
            continue;
          }
        }

        // 3. Fallback: Lógica de linha única (Modo Horizontal)
        final parts =
            line.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        if (parts.length >= 6) {
          final bitolaStr = parts[1].replaceAll(',', '.');
          final bitola = double.tryParse(bitolaStr);
          if (bitola != null) {
            double? peso;
            String? osStr;
            for (int j = parts.length - 1; j >= 4; j--) {
              final val = double.tryParse(parts[j].replaceAll(',', '.'));
              if (val != null) {
                if (osStr == null)
                  osStr = parts[j];
                else if (peso == null) {
                  peso = val;
                  break;
                }
              }
            }
            if (peso != null && currentElementName != null) {
              final xMatch = RegExp(r'X\s?(\d+)', caseSensitive: false)
                  .firstMatch(currentElementName!);
              final extractedQtde =
                  xMatch != null ? int.tryParse(xMatch.group(1)!) ?? 1 : 1;
              final pesoUnitario = peso / extractedQtde;

              final pos = ElementoPosicaoCreateModel();
              pos.nome.text = parts[0];
              pos.numeroOs.text = osStr ?? '';
              pos.pesoKg.text = pesoUnitario.toStringAsFixed(3);
              final bMatch = bitola.toString().replaceAll(RegExp(r'\.0$'), '');
              pos.produto = pedido
                  .getProdutos()
                  .map((e) => e.produto)
                  .where((p) =>
                      p.nome.contains(bMatch) ||
                      p.labelMinified.contains(bMatch))
                  .firstOrNull;
              if (pos.produto != null) currentPosicoes.add(pos);
            }
          }
        }
      }

      if (currentElementName != null && currentPosicoes.isNotEmpty) {
        final xMatch = RegExp(r'X\s?(\d+)', caseSensitive: false)
            .firstMatch(currentElementName!);
        final extractedQtde =
            xMatch != null ? int.tryParse(xMatch.group(1)!) ?? 1 : 1;

        novosElementos.add(ElementoCreateModel()
          ..nome.text = currentElementName!
          ..qtde.text = extractedQtde.toString()
          ..posicoes.addAll(currentPosicoes));
      }

      if (novosElementos.isEmpty) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'Nenhum elemento ou posição válida foi identificado.',
          'rawText': rawText
        };
      }

      // ─── SALVAR NO BANCO (com suporte a cancelamento) ───────────────────────
      final total = novosElementos.length;
      for (int i = 0; i < total; i++) {
        if (_cancelImport) {
          // Rollback: Remover o que já foi inserido
          importProgressStream
              .add(ImportProgress(status: 'Cancelando e limpando dados...'));
          if (createdElementIds.isNotEmpty) {
            await SupabaseService.client
                .from('elementos')
                .delete()
                .filter('id', 'in', createdElementIds);
          }
          await onFetch(pedido.id);
          importProgressStream.add(null);
          return {
            'success': false,
            'error': 'Importação cancelada pelo usuário.',
            'rawText': rawText
          };
        }

        final el = novosElementos[i];
        importProgressStream.add(ImportProgress(
          current: i + 1,
          total: total,
          status: 'Salvando elemento ${i + 1} de $total...',
          isSaving: true,
        ));

        await onSaveElemento(el, pedido.id);
        createdElementIds.add(el.id);
      }

      await onFetch(pedido.id);
      importProgressStream.add(null);
      return {
        'success': true,
        'elementsFound': novosElementos.length,
        'rawText': rawText
      };
    } catch (e) {
      print('ElementoController.onImportPDF erro: $e');
      importProgressStream.add(null);
      return {'success': false, 'error': e.toString(), 'rawText': rawText};
    }
  }

  // ─── VALIDAÇÃO POR BITOLA ─────────────────────────────────────────────────
  /// Verifica se o somatório de peso de cada bitola nas posições
  /// corresponde ao total de cada bitola no pedido.
  ElementoValidacaoResult getValidacaoBitola(PedidoModel pedido) {
    // Soma de peso por produto_id em TODAS as posições de todos os elementos
    final Map<String, double> pesoNasPosicoesMap = {};
    for (final elemento in elementos) {
      for (final posicao in elemento.posicoes) {
        final pesoTotalDaPosicao = posicao.pesoKg * elemento.qtde;
        pesoNasPosicoesMap[posicao.produtoId] =
            (pesoNasPosicoesMap[posicao.produtoId] ?? 0.0) + pesoTotalDaPosicao;
      }
    }

    // Peso esperado: o que está nas bitolas do pedido (qtde)
    final divergencias = <ElementoDivergenciaBitola>[];

    for (final pp in pedido.getProdutos()) {
      final esperado = pp.qtde;
      final calculado = pesoNasPosicoesMap[pp.produto.id] ?? 0.0;
      final diff = (esperado - calculado).abs();
      if (diff > 0.001) {
        divergencias.add(ElementoDivergenciaBitola(
          produto: pp,
          esperadoKg: esperado,
          calculadoKg: calculado,
        ));
      }
    }

    // Verifica também se o total geral bate
    final totalPedido = pedido.getQtdeTotal();
    final totalElementos = elementos.fold(0.0, (s, e) => s + e.pesoTotal);

    return ElementoValidacaoResult(
      totalPedidoKg: totalPedido,
      totalElementosKg: totalElementos,
      divergencias: divergencias,
      isOk: divergencias.isEmpty &&
          (totalPedido - totalElementos).abs() < 0.001,
    );
  }
}

// ─── RESULTADO DE VALIDAÇÃO ───────────────────────────────────────────────────
class ElementoValidacaoResult {
  final double totalPedidoKg;
  final double totalElementosKg;
  final List<ElementoDivergenciaBitola> divergencias;
  final bool isOk;

  ElementoValidacaoResult({
    required this.totalPedidoKg,
    required this.totalElementosKg,
    required this.divergencias,
    required this.isOk,
  });

  double get diferencaTotal => (totalPedidoKg - totalElementosKg).abs();
}

class ElementoDivergenciaBitola {
  final PedidoProdutoModel produto;
  final double esperadoKg;
  final double calculadoKg;
  double get diferencaKg => (esperadoKg - calculadoKg).abs();

  ElementoDivergenciaBitola({
    required this.produto,
    required this.esperadoKg,
    required this.calculadoKg,
  });
}

class ImportProgress {
  final int current;
  final int total;
  final String status;
  final bool isSaving;

  ImportProgress({
    this.current = 0,
    this.total = 0,
    required this.status,
    this.isSaving = false,
  });

  double get percent => total > 0 ? current / total : 0;
}
