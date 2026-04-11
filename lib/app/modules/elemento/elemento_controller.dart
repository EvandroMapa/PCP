import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/supabase_storage_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:collection/collection.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';

final elementoCtrl = ElementoController();

class ElementoController {
  static final ElementoController _instance = ElementoController._();
  ElementoController._();
  factory ElementoController() => _instance;

  final AppStream<List<ElementoModel>> elementosStream =
      AppStream<List<ElementoModel>>.seed([]);
  List<ElementoModel> get elementos => elementosStream.value;

  final AppStream<String> loadingMessageStream =
      AppStream<String>.seed('Aguarde, inicializando...');

  final AppStream<ImportProgress?> importProgressStream =
      AppStream<ImportProgress?>.seed(null);

  bool _cancelImport = false;
  String? _currentPedidoId;
  ElementoValidacaoResult? _cachedValidacao;
  bool _validacaoDirty = true;

  // ─── INICIALIZAÇÃO ────────────────────────────────────────────────────────
  Future<void> onInit(String pedidoId) async {
    if (_currentPedidoId == pedidoId) return;
    _currentPedidoId = pedidoId;
    await onFetch(pedidoId);
  }

  void onDispose() {
    _currentPedidoId = null;
    elementosStream.add(<ElementoModel>[]);
    importProgressStream.add(null);
  }

  void cancelImport() {
    _cancelImport = true;
    importProgressStream.add(ImportProgress(
      status: 'Cancelando importação...\nAguarde enquanto revertemos os dados.',
      isCancelling: true,
    ));
  }

  // ─── BUSCAR ───────────────────────────────────────────────────────────────
  Future<void> onFetch(String pedidoId) async {
    try {
      loadingMessageStream.add('Buscando cabeçalhos dos elementos...');
      log('onFetch: 1 - Buscando elementos...');
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedidoId)
          .order('created_at')
          .timeout(const Duration(seconds: 15));

      log('onFetch: 2 - Elementos retornados: ${elementosRaw.length}');
      if (elementosRaw.isEmpty) {
        elementosStream.add(<ElementoModel>[]);
        _validacaoDirty = true;
        return;
      }

      final eIds = elementosRaw.map((e) => e['id'].toString()).toList();
      loadingMessageStream.add('Montando ${elementosRaw.length} elementos detectados...\nBaixando posições e arquivos...');

      log('onFetch: 3 - Buscando posicoes e arquivos...');
      // Busca todas as posições e arquivos em paralelo (2 queries em vez de N*2)
      final results = await Future.wait([
        SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .filter('elemento_id', 'in', eIds)
            .timeout(const Duration(seconds: 15)),
        SupabaseService.client
            .from('elemento_arquivos')
            .select()
            .filter('elemento_id', 'in', eIds)
            .timeout(const Duration(seconds: 15)),
      ]);
      log('onFetch: 4 - Consultas filhas concluidas.');
      loadingMessageStream.add('Processando dados recebidos...');

      final allPosicoes = List<Map<String, dynamic>>.from(results[0]);
      final allArquivos = List<Map<String, dynamic>>.from(results[1]);

      final List<ElementoModel> result = elementosRaw.map((e) {
        final eId = e['id'].toString();
        return ElementoModel.fromSupabaseMap(
          e,
          posicoesRaw: allPosicoes.where((p) => p['elemento_id'].toString() == eId).toList(),
          arquivosRaw: allArquivos.where((a) => a['elemento_id'].toString() == eId).toList(),
        );
      }).toList();

      elementosStream.add(result);
      _validacaoDirty = true; // Invalida cache do comparativo

      // Recalcular armacaoResumo e persistir (garante dados para o Kanban)
      _updateArmacaoResumo(pedidoId, result);
    } catch (e) {
      log('ElementoController.onFetch erro', error: e);
      elementosStream.add(<ElementoModel>[]);
    }
  }

  // ─── RECÁLCULO DO RESUMO DE ARMAÇÃO ──────────────────────────────────────
  Future<void> _updateArmacaoResumo(String pedidoId, List<ElementoModel> elementos) async {
    try {
      int totalQtd = 0;
      double totalPeso = 0;
      final Map<ElementoStatus, int> qtdPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };
      final Map<ElementoStatus, double> pesoPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };

      for (final e in elementos) {
        totalQtd += e.qtde;
        totalPeso += e.pesoTotal;
        qtdPorStatus[e.status] = (qtdPorStatus[e.status] ?? 0) + e.qtde;
        pesoPorStatus[e.status] = (pesoPorStatus[e.status] ?? 0) + e.pesoTotal;
      }

      final Map<String, dynamic> resume = {
        'total_qtd': totalQtd,
        'total_peso': totalPeso,
        'details': {
          'aguardando': {
            'qtd': qtdPorStatus[ElementoStatus.aguardando],
            'peso': pesoPorStatus[ElementoStatus.aguardando],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.aguardando]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.aguardando]! / totalPeso : 0,
          },
          'armando': {
            'qtd': qtdPorStatus[ElementoStatus.armando],
            'peso': pesoPorStatus[ElementoStatus.armando],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.armando]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.armando]! / totalPeso : 0,
          },
          'pronto': {
            'qtd': qtdPorStatus[ElementoStatus.pronto],
            'peso': pesoPorStatus[ElementoStatus.pronto],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.pronto]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.pronto]! / totalPeso : 0,
          },
        }
      };

      // Persistir no Supabase
      await SupabaseService.client
          .from('pedidos')
          .update({'armacao_resumo': resume})
          .eq('id', pedidoId);

      // Atualizar localmente no objeto pedido para refletir no Kanban
      final pedido = BackendClient.pedidos.pepidosUnarchiveds
          .firstWhere((p) => p.id == pedidoId, orElse: () => throw 'Pedido não encontrado');
      pedido.armacaoResumo.clear();
      pedido.armacaoResumo.addAll(resume);

      log('armacaoResumo atualizado: $totalQtd elementos, ${totalPeso.toStringAsFixed(1)} kg');
    } catch (e) {
      log('Erro ao atualizar armacaoResumo: $e');
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
      log('ElementoController.onSaveElemento erro: $e');
    }
  }

  // ─── DELETAR ELEMENTO ─────────────────────────────────────────────────────
  Future<void> onDeleteElemento(ElementoModel elemento) async {
    try {
      showLoadingDialog();
      // Remove dependências manualmente para evitar violar Foreign Keys caso não haja ON DELETE CASCADE
      await SupabaseService.client.from('elemento_posicoes').delete().eq('elemento_id', elemento.id);
      await SupabaseService.client.from('elemento_arquivos').delete().eq('elemento_id', elemento.id);

      await SupabaseService.client
          .from('elementos')
          .delete()
          .eq('id', elemento.id);

      await onFetch(elemento.pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // fecha loading
      NotificationService.showPositive('Sucesso', 'Elemento excluído!');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal);
      log('ElementoController.onDeleteElemento erro: $e');
      NotificationService.showNegative('Erro', e.toString());
    }
  }

  // ─── GERENCIAMENTO DE ARQUIVOS ───────────────────────────────────────────
  Future<void> onAddArquivo(
      ElementoModel elemento, String name, Uint8List bytes, String mimeType) async {
    try {
      showLoadingDialog();
      final url = await SupabaseStorageService.uploadFile(
        name: name,
        bytes: bytes,
        mimeType: mimeType,
        path: 'elementos/${elemento.id}',
      );

      final arquivo = ElementoArquivoModel(
        id: '', // Supabase gera UUID
        elementoId: elemento.id,
        nome: name,
        url: url,
        tamanho: bytes.length,
        tipo: mimeType,
        extensao: name.split('.').last,
        criadoEm: DateTime.now(),
      );

      await AppSupabaseClient.elementoArquivos.add(arquivo);
      await onFetch(elemento.pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      NotificationService.showPositive('Sucesso', 'Arquivo anexado com sucesso!');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      log('ElementoController.onAddArquivo erro: $e');
      NotificationService.showNegative('Erro', 'Falha ao anexado arquivo.');
    }
  }

  Future<void> onDeleteArquivo(
      ElementoArquivoModel arquivo, String pedidoId) async {
    try {
      showLoadingDialog();
      // Remove do storage físico
      await SupabaseStorageService.deleteFile(arquivo.url);
      // Remove do banco
      await AppSupabaseClient.elementoArquivos.delete(arquivo.id);
      
      await onFetch(pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      NotificationService.showPositive('Sucesso', 'Arquivo removido!');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      log('ElementoController.onDeleteArquivo erro: $e');
    }
  }

  // ─── DELETAR TODOS OS ELEMENTOS ───────────────────────────────────────────
  Future<void> onDeleteAllElementos(String pedidoId) async {
    try {
      showLoadingDialog();
      
      // Resgata os IDs para deletar filhos
      final eRaw = await SupabaseService.client.from('elementos').select('id').eq('pedido_id', pedidoId);
      final eIds = eRaw.map((e) => e['id'].toString()).toList();
      
      if (eIds.isNotEmpty) {
          await SupabaseService.client.from('elemento_posicoes').delete().filter('elemento_id', 'in', eIds);
          await SupabaseService.client.from('elemento_arquivos').delete().filter('elemento_id', 'in', eIds);
      }

      await SupabaseService.client
          .from('elementos')
          .delete()
          .eq('pedido_id', pedidoId);

      await onFetch(pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // fecha loading
      NotificationService.showPositive('Sucesso', 'Todos os elementos foram removidos.');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal);
      log('ElementoController.onDeleteAllElementos erro: $e');
      NotificationService.showNegative('Erro ao deletar', e.toString());
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
      log('Erro ao gerar PDF: $e');
      log(stack.toString());
      NotificationService.showNegative('Erro', 'Falha ao gerar o PDF: $e');
    }
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
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
          pw.TableHelper.fromTextArray(
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
        pw.TableHelper.fromTextArray(
          headers: ['BITOLA', 'PESO TOTAL (KG)'],
          data: [
            ...resumo.entries
                .map((e) => [e.key, '${fmt.format(e.value)} kg'])
                ,
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
      final List<ElementoCreateModel> novosElementos = [];
      
      ElementoCreateModel? currentElement;
      String? pendingOS;

      // Lista de termos para ignorar (ruído de cabeçalho)

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;

        // 1. Detectar Início de Elemento (Vertical)
        // Padrão: NomeElemento \n Elemento \n Ok
        if (i + 2 < lines.length && 
            lines[i+1].toLowerCase() == 'elemento' && 
            lines[i+2].toLowerCase() == 'ok') {
          
          if (currentElement != null && currentElement.posicoes.isNotEmpty) {
            novosElementos.add(currentElement);
          }
          
          currentElement = ElementoCreateModel();
          
          // Tentar extrair Qtde do nome (ex: "V37 X 2") e descartar o multiplicador do nome
          final xMatch = RegExp(r'\s*X\s*(\d+)$', caseSensitive: false).firstMatch(line);
          if (xMatch != null) {
            currentElement.qtde.text = xMatch.group(1)!;
            currentElement.nome.text = line.substring(0, xMatch.start).trim();
          } else {
            currentElement.nome.text = line;
          }
          
          i += 2; // Pula "Elemento" e "Ok"
          continue;
        }

        // 2. Identificar possível OS (número isolado)
        // No PDF da ALA, a OS vem como um número solto, tentamos guardar mas NAO damos continue
        if (RegExp(r'^\d{2,6}$').hasMatch(line)) {
          pendingOS = line;
        }

        // 3. Tentar capturar um bloco de posição (Vertical)
        // Padrão antigo: Qtde(i) -> Compr(i+1) -> Pos(i+2) -> Bitola(i+3) -> Aço(i+4) -> Peso(i+5)
        // Padrão novo: ... -> Peso(i+5) -> OS(i+6)
        if (currentElement != null && i + 5 < lines.length) {
          final valQtde = lines[i].replaceAll(',', '.');
          final valPos = lines[i+2];
          final valBitolaStr = lines[i+3].replaceAll(',', '.');
          final valAco = lines[i+4].toUpperCase();
          final valPesoStr = lines[i+5].replaceAll(',', '.');

          final qtdePos = double.tryParse(valQtde);
          final bitola = double.tryParse(valBitolaStr);
          final peso = double.tryParse(valPesoStr);

          // Validação: Se bitola e peso são números e o Aço é CA50/CA60, é uma posição
          if (qtdePos != null && bitola != null && (valAco.contains('CA50') || valAco.contains('CA60'))) {
            
            bool hasOSInBlock = false;
            String osValue = pendingOS ?? '';

            if (i + 6 < lines.length && RegExp(r'^\d+$').hasMatch(lines[i+6])) {
                osValue = lines[i+6];
                hasOSInBlock = true;
            }

            final pos = ElementoPosicaoCreateModel();
            pos.nome.text = valPos; // Nome da Posição (ex: 01, 02)
            pos.numeroOs.text = osValue;
            
            // Peso unitário (no PDF o peso é total da posição incluindo Elemento.qtde)
            final elQtde = int.tryParse(currentElement.qtde.text) ?? 1;
            final pesoLido = peso ?? 0.0;
            final pesoUnitario = elQtde > 0 ? pesoLido / elQtde : pesoLido;
            pos.pesoKg.text = pesoUnitario.toStringAsFixed(3);

            pos.produto = pedido.getProdutos()
                .map((e) => e.produto)
                .where((p) {
                  final textToSearch = '${p.nome} ${p.labelMinified}'.replaceAll(',', '.');
                  // Extrai todos os números (com ou sem casa decimal) do nome do produto ex: "50", "12.5", "5"
                  final extractedNumbers = RegExp(r'\d+(?:\.\d+)?').allMatches(textToSearch);
                  
                  // Verifica se algum dos números extraídos é exatamente igual à bitola lida
                  return extractedNumbers.any((match) {
                     final extractedValue = double.tryParse(match.group(0)!);
                     return extractedValue == bitola;
                  });
                })
                .firstOrNull;

            if (pos.produto != null) {
              currentElement.posicoes.add(pos);
            }
            
            i += hasOSInBlock ? 6 : 5; // Pula o bloco processado
            pendingOS = null; 
            continue;
          }
        }
      }

      // Adiciona o último elemento acumulado
      if (currentElement != null && currentElement.posicoes.isNotEmpty) {
        novosElementos.add(currentElement);
      }

      if (novosElementos.isEmpty) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'Nenhum elemento ou posição válida foi identificado.',
          'rawText': rawText
        };
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
      // Calcula total de posições para a barra de progresso
      int totalPosicoes = 0;
      for (final el in novosElementos) {
        totalPosicoes += el.posicoes.length;
      }
      int posicaoAtual = 0;

      for (int i = 0; i < novosElementos.length; i++) {
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

        // Salva o elemento (header)
        await SupabaseService.client.from('elementos').upsert({
          'id': el.id,
          'pedido_id': pedido.id,
          'nome': el.nome.text,
          'qtde': el.qtdeInt,
        });

        // Salva cada posição individualmente, atualizando progresso
        for (final posicao in el.posicoes) {
          if (_cancelImport) break;
          if (!posicao.isValid) continue;

          posicaoAtual++;
          importProgressStream.add(ImportProgress(
            current: posicaoAtual,
            total: totalPosicoes,
            status: 'Elemento: ${el.nome.text}\nPosição: ${posicao.nome.text}',
            isSaving: true,
          ));

          await SupabaseService.client.from('elemento_posicoes').upsert({
            'id': posicao.id,
            'elemento_id': el.id,
            'nome': posicao.nome.controller.text,
            'numero_os': posicao.numeroOs.controller.text,
            'produto_id': posicao.produto!.id,
            'peso_kg': posicao.pesoDouble,
          });
        }

        createdElementIds.add(el.id);
        // Atualiza a lista atrás do dialog em tempo real
        await onFetch(pedido.id);
      }

      await onFetch(pedido.id);
      importProgressStream.add(null);
      return {
        'success': true,
        'elementsFound': novosElementos.length,
        'rawText': rawText
      };
    } catch (e) {
      log('ElementoController.onImportPDF erro: $e');
      importProgressStream.add(null);
      return {'success': false, 'error': e.toString(), 'rawText': rawText};
    }
  }

  // ─── VALIDAÇÃO POR BITOLA ─────────────────────────────────────────────────
  /// Verifica se o somatório de peso de cada bitola nas posições
  /// corresponde ao total de cada bitola no pedido.
  ElementoValidacaoResult getCachedValidacao(PedidoModel pedido) {
    if (_validacaoDirty || _cachedValidacao == null) {
      _cachedValidacao = getValidacaoBitola(pedido);
      _validacaoDirty = false;
    }
    return _cachedValidacao!;
  }

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
  final bool isCancelling;

  ImportProgress({
    this.current = 0,
    this.total = 0,
    required this.status,
    this.isSaving = false,
    this.isCancelling = false,
  });

  double get percent => total > 0 ? current / total : 0;
}
