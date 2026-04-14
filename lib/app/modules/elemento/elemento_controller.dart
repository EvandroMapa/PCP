import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/supabase_storage_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:collection/collection.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:pdfx/pdfx.dart';
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
  StreamSubscription? _globalElementosSub;

  Future<void> onInit(String pedidoId) async {
    // Se mudou de pedido ou o stream está vazio, refaz o fetch completo.
    if (_currentPedidoId != pedidoId || elementosStream.value.isEmpty) {
      _currentPedidoId = pedidoId;
      await onFetch(pedidoId);
    }

    // Escuta mudanças globais em tempo real para sincronizar o status e dados básicos
    _globalElementosSub?.cancel();
    _globalElementosSub = AppSupabaseClient.elementos.dataStream.listen.listen((globalElementos) {
      if (_currentPedidoId == null) return;

      final currentList = elementosStream.value.toList();
      bool changed = false;

      for (final globalEl in globalElementos) {
         if (globalEl.pedidoId != _currentPedidoId) continue;
         final idx = currentList.indexWhere((e) => e.id == globalEl.id);
         if (idx != -1) {
            // Se o status, qtde, qtdePronto ou nome mudou globalmente, atualiza localmente
            if (currentList[idx].status != globalEl.status ||
                currentList[idx].qtde != globalEl.qtde ||
                currentList[idx].qtdePronto != globalEl.qtdePronto ||
                currentList[idx].nome != globalEl.nome) {
               currentList[idx] = currentList[idx].copyWith(
                 status: globalEl.status,
                 qtde: globalEl.qtde,
                 qtdePronto: globalEl.qtdePronto,
                 nome: globalEl.nome,
               );
               changed = true;
            }
         }
      }

      if (changed) {
        // Ordenar alfabeticamente A-Z
        currentList.sort((a, b) => a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
        elementosStream.add(currentList);
        _validacaoDirty = true;
        // Recalcular o resumo de armação para refletir no Kanban
        _updateArmacaoResumo(_currentPedidoId!, currentList);
      }
    });
  }

  void onDispose() {
    _currentPedidoId = null;
    _globalElementosSub?.cancel();
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
          .order('nome')
          .timeout(const Duration(seconds: 15));

      log('onFetch: 2 - Elementos retornados: ${elementosRaw.length}');
      if (elementosRaw.isEmpty) {
        elementosStream.add(<ElementoModel>[]);
        _validacaoDirty = true;
        _updateArmacaoResumo(pedidoId, <ElementoModel>[]); // Zera o resumo do Kanban no BD
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

      // Ordenar alfabeticamente A-Z (Garante ordem mesmo que o banco falte)
      result.sort((a, b) => a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));

      elementosStream.add(result);
      // Injeta os dados novos na coleção global para atualizar outros módulos (Ex: Armação no Tablet) reativamente
      AppSupabaseClient.elementos.updateLocalData(result);
      
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

      // Qtd e peso por status com suporte a progressos parciais
      final Map<ElementoStatus, double> qtdPorStatus = {
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

        if (e.status == ElementoStatus.aguardando) {
          qtdPorStatus[ElementoStatus.aguardando] = (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.aguardando] = (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + e.pesoTotal;
        } else if (e.status == ElementoStatus.pronto) {
          qtdPorStatus[ElementoStatus.pronto] = (qtdPorStatus[ElementoStatus.pronto] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.pronto] = (pesoPorStatus[ElementoStatus.pronto] ?? 0) + e.pesoTotal;
        } else {
          // armando — cálculo proporcional baseado no qtdePronto
          final qtdeProntoFrac = e.qtdePronto.toDouble();
          final qtdeArmandoFrac = (e.qtde - e.qtdePronto).toDouble();
          final pesoPorUnidade = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

          qtdPorStatus[ElementoStatus.pronto] = (qtdPorStatus[ElementoStatus.pronto] ?? 0) + qtdeProntoFrac;
          pesoPorStatus[ElementoStatus.pronto] = (pesoPorStatus[ElementoStatus.pronto] ?? 0) + (qtdeProntoFrac * pesoPorUnidade);

          qtdPorStatus[ElementoStatus.armando] = (qtdPorStatus[ElementoStatus.armando] ?? 0) + qtdeArmandoFrac;
          pesoPorStatus[ElementoStatus.armando] = (pesoPorStatus[ElementoStatus.armando] ?? 0) + (qtdeArmandoFrac * pesoPorUnidade);
        }
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

  // ─── SALVAR ELEMENTO3
  // ──────────────────────────────────────────────────────
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
          'qtde': posicao.qtdeInt,
        });
      }

      await onFetch(pedidoId);
    } catch (e) {
      log('ElementoController.onSaveElemento erro: $e');
    }
  }

  // ─── DELETAR ELEMENTdfO e─────────────────────────────────────────────────────
  Future<void> onDeleteElemento(ElementoModel elemento) async {
    try {
      if (elemento.status != ElementoStatus.aguardando) {
         showInfoDialog('Não Permitido: Não é possível excluir um elemento que já está sendo armando ou pronto.');
         return;
      }
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
      final isPdf = mimeType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
      
      if (isPdf) {
        // O dialog de loading com stream é aberto pela UI (_ElementoArquivosDialog)
        loadingMessageStream.add('Preparando otimização...');
        await _optimizeAndUploadPdf(elemento, name, bytes);
        await onFetch(elemento.pedidoId);
        if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha o dialog da UI
        NotificationService.showPositive('Sucesso', 'Desenho otimizado e anexado!');
        return;
      }

      showLoadingDialog(); // Apenas para imagens normais

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

  /// ─── MOTOR DE OTIMIZAÇÃO DE DESENHOS (PDF -> JPG HD) ──────────────
  Future<void> _optimizeAndUploadPdf(ElementoModel elemento, String originalName, Uint8List pdfBytes) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(pdfBytes);
      final int pageCount = document.pagesCount;

      final level = PreferencesService.pdfOptimizationLevel.value;
      for (int i = 1; i <= pageCount; i++) {
        loadingMessageStream.add('Processando página $i de $pageCount...\nOtimizando com nível $level');
        
        final page = await document.getPage(i);
        // Renderiza com escala e qualidade configuráveis (Configurações Gerais)
        final scale = PreferencesService.pdfScale;
        final quality = PreferencesService.pdfQuality;
        final pageImage = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
          quality: quality,
        );
        
        if (pageImage != null) {
          final String fileName = pageCount > 1 
              ? '${originalName.split('.').first}_PAG_$i.jpg'
              : '${originalName.split('.').first}.jpg';
              
          final url = await SupabaseStorageService.uploadFile(
            name: fileName,
            bytes: pageImage.bytes,
            mimeType: 'image/jpeg',
            path: 'elementos/${elemento.id}',
          );

          final arquivo = ElementoArquivoModel(
            id: '',
            elementoId: elemento.id,
            nome: fileName.toUpperCase(),
            url: url,
            tamanho: pageImage.bytes.length,
            tipo: 'image/jpeg',
            extensao: 'jpg',
            criadoEm: DateTime.now(),
          );

          await AppSupabaseClient.elementoArquivos.add(arquivo);
        }
        await page.close();
      }
    } catch (e) {
      log('ElementoController._optimizeAndUploadPdf erro: $e');
      rethrow;
    } finally {
      await document?.close();
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
      if (elementos.any((e) => e.status != ElementoStatus.aguardando)) {
         showInfoDialog('Operação Negada: Existem elementos que já estão em produção ou concluídos. Remova individualmente os que permite exclusão.');
         return;
      }
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

  Future<Map<String, dynamic>> onImportCSV(
      Uint8List bytes, PedidoModel pedido, bool clearExisting) async {

    String rawText = '';
    _cancelImport = false;
    final List<String> createdElementIds = [];

    try {
      if (clearExisting) {
        await onDeleteAllElementos(pedido.id);
      }

      importProgressStream.add(ImportProgress(status: 'Lendo dados do arquivo CSV...'));

      try {
        rawText = utf8.decode(bytes);
      } catch (e) {
        // Fallback clássico para CSVs gerados pelo Excel BR sem UTF-8
        rawText = latin1.decode(bytes);
      }

      if (rawText.trim().isEmpty) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'O arquivo CSV está vazio.',
          'rawText': ''
        };
      }

      final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      // Validação básica se parece um CSV válido
      if (lines.length <= 1 || !lines.first.contains(';')) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'O arquivo não parece ser um CSV válido separado por ponto-e-vírgula (;).',
          'rawText': rawText
        };
      }

      final List<ElementoCreateModel> novosElementos = [];
      ElementoCreateModel? currentElement;

      // Extrai a linha de cabeçalho (ignorando case e espaços)
      final headerLine = lines.first.split(';').map((e) => e.trim().toUpperCase()).toList();
      
      // Cria mapa de índices para procurar colunas chaves
      final Map<String, int> headerIndex = {};
      for (int i = 0; i < headerLine.length; i++) {
        headerIndex[headerLine[i]] = i;
      }

      int getIndex(List<String> possibleNames) {
        for (String name in possibleNames) {
          if (headerIndex.containsKey(name)) return headerIndex[name]!;
          // Pesquisa com partially match se não achar exato (ex: PESO (KG) -> PESO)
          final match = headerIndex.keys.firstWhereOrNull((k) => k.contains(name));
          if (match != null) return headerIndex[match]!;
        }
        return -1;
      }

      // Procura índices usando possíveis variações de nome na sua planilha
      final idxElemento = getIndex(['ELEMENTO']);
      final idxQtdeElementos = getIndex(['QTDE_ELEMENTOS', 'QTDE ELEMENTOS', 'QTD_ELEMENTOS', 'QTD ELEMENTOS']);
      final idxOs = getIndex(['OS', 'O.S.', 'O.S']);
      final idxPosicao = getIndex(['POSICAO', 'POSIÇÃO', 'POS.']);
      final idxBitola = getIndex(['BITOLA', 'DIAMETRO']);
      final idxPeso = getIndex(['PESO (KG)', 'PESO']);
      final idxQtde = getIndex(['QTDE', 'QUANTIDADE', 'QTD']); // qtde da posicao

      if (idxElemento == -1 || idxPosicao == -1 || idxBitola == -1) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'Colunas obrigatórias não encontradas no CSV (ELEMENTO, POSICAO, BITOLA).',
          'rawText': rawText
        };
      }

      // Pula a linha de cabeçalho
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        final columns = line.split(';');

        if (columns.length <= idxBitola) continue;

        final elNome = columns[idxElemento].trim();
        final elQtdeStr = idxQtdeElementos != -1 && columns.length > idxQtdeElementos ? columns[idxQtdeElementos].trim() : '1';
        final osNumber = idxOs != -1 && columns.length > idxOs ? columns[idxOs].trim() : '';
        final posNome = columns[idxPosicao].trim();
        final bitolaStr = columns[idxBitola].trim().replaceAll('mm', '').replaceAll(',', '.');
        final pesoStr = idxPeso != -1 && columns.length > idxPeso ? columns[idxPeso].trim().replaceAll(',', '.') : '0';
        final posQtdeStr = idxQtde != -1 && columns.length > idxQtde ? columns[idxQtde].trim() : '0';

        if (elNome.isEmpty || posNome.isEmpty) continue;

        // Controle de agrupamento de Posições sob o mesmo "Elemento Pai"
        if (currentElement == null || currentElement.nome.text != elNome) {
          if (currentElement != null && currentElement.posicoes.isNotEmpty) {
            novosElementos.add(currentElement);
          }
          currentElement = ElementoCreateModel();
          currentElement.nome.text = elNome;
          currentElement.qtde.text = int.tryParse(elQtdeStr)?.toString() ?? '1';
        }

        final bitola = double.tryParse(bitolaStr);
        final pesoLido = double.tryParse(pesoStr);

        if (bitola != null && pesoLido != null) {
          final pos = ElementoPosicaoCreateModel();
          pos.nome.text = posNome;
          pos.numeroOs.text = osNumber;
          pos.pesoKg.text = pesoLido.toStringAsFixed(3);
          pos.qtde.text = posQtdeStr;

          pos.produto = pedido.getProdutos()
              .map((e) => e.produto)
              .where((p) {
                final textToSearch = '${p.nome} ${p.labelMinified}'.replaceAll(',', '.');
                final extractedNumbers = RegExp(r'\d+(?:\.\d+)?').allMatches(textToSearch);
                return extractedNumbers.any((match) {
                   final extractedValue = double.tryParse(match.group(0)!);
                   return extractedValue == bitola;
                });
              })
              .firstOrNull;

          if (pos.produto != null) {
            currentElement.posicoes.add(pos);
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
          'error': 'Nenhum elemento ou posição válida foi identificada no CSV.',
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
            'qtde': posicao.qtdeInt,
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
      log('ElementoController.onImportCSV erro: $e');
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
