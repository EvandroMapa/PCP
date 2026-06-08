import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/supabase_storage_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:collection/collection.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:pdfx/pdfx.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/modules/relatorio/ui/pedido/relatorio_elemento_pdf_page.dart';

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
    _globalElementosSub =
        AppSupabaseClient.elementos.dataStream.listen.listen((globalElementos) {
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
        currentList.sort((a, b) =>
            a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
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
        _updateArmacaoResumo(
            pedidoId, <ElementoModel>[]); // Zera o resumo do Kanban no BD
        return;
      }

      final eIds = elementosRaw.map((e) => e['id'].toString()).toList();
      loadingMessageStream.add(
          'Montando ${elementosRaw.length} elementos detectados...\nBaixando posições e arquivos...');

      log('onFetch: 3 - Buscando posicoes e arquivos em lotes...');
      
      // Busca em lotes de 100 para evitar erro 400 (URL muito longa) no Supabase
      const batchSize = 100;
      final List<Map<String, dynamic>> allPosicoes = [];
      final List<Map<String, dynamic>> allArquivos = [];

      for (var i = 0; i < eIds.length; i += batchSize) {
        final end = (i + batchSize < eIds.length) ? i + batchSize : eIds.length;
        final batchIds = eIds.sublist(i, end);
        
        loadingMessageStream.add(
          'Baixando posições e arquivos...\nLote ${(i ~/ batchSize) + 1} de ${(eIds.length / batchSize).ceil()}');

        final batchResults = await Future.wait([
          SupabaseService.client
              .from('elemento_posicoes')
              .select()
              .filter('elemento_id', 'in', batchIds)
              .timeout(const Duration(seconds: 15)),
          SupabaseService.client
              .from('elemento_arquivos')
              .select()
              .filter('elemento_id', 'in', batchIds)
              .timeout(const Duration(seconds: 15)),
        ]);
        
        allPosicoes.addAll(List<Map<String, dynamic>>.from(batchResults[0]));
        allArquivos.addAll(List<Map<String, dynamic>>.from(batchResults[1]));
      }

      // Buscar medidas variáveis das posições
      final posIds = allPosicoes.map((p) => p['id'].toString()).toList();
      final List<Map<String, dynamic>> allMedidas = [];
      if (posIds.isNotEmpty) {
        for (var i = 0; i < posIds.length; i += batchSize) {
          final end = (i + batchSize < posIds.length) ? i + batchSize : posIds.length;
          final batchPosIds = posIds.sublist(i, end);
          final medidasBatch = await SupabaseService.client
              .from('elemento_posicao_medidas')
              .select()
              .filter('posicao_id', 'in', batchPosIds)
              .timeout(const Duration(seconds: 15));
          allMedidas.addAll(List<Map<String, dynamic>>.from(medidasBatch));
        }
      }

      log('onFetch: 4 - Consultas filhas concluidas.');
      loadingMessageStream.add('Processando dados recebidos...');

      final List<ElementoModel> result = elementosRaw.map((e) {
        final eId = e['id'].toString();
        return ElementoModel.fromSupabaseMap(
          e,
          posicoesRaw: allPosicoes
              .where((p) => p['elemento_id'].toString() == eId)
              .toList(),
          arquivosRaw: allArquivos
              .where((a) => a['elemento_id'].toString() == eId)
              .toList(),
          medidasRaw: allMedidas,
        );
      }).toList();

      // Ordenar alfabeticamente A-Z (Garante ordem mesmo que o banco falte)
      result.sort((a, b) =>
          a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));

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
  Future<void> _updateArmacaoResumo(
      String pedidoId, List<ElementoModel> elementos) async {
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
          qtdPorStatus[ElementoStatus.aguardando] =
              (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.aguardando] =
              (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + e.pesoTotal;
        } else if (e.status == ElementoStatus.pronto) {
          qtdPorStatus[ElementoStatus.pronto] =
              (qtdPorStatus[ElementoStatus.pronto] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.pronto] =
              (pesoPorStatus[ElementoStatus.pronto] ?? 0) + e.pesoTotal;
        } else {
          // armando — cálculo proporcional baseado no qtdePronto
          final qtdeProntoFrac = e.qtdePronto.toDouble();
          final qtdeArmandoFrac = (e.qtde - e.qtdePronto).toDouble();
          final pesoPorUnidade = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

          qtdPorStatus[ElementoStatus.pronto] =
              (qtdPorStatus[ElementoStatus.pronto] ?? 0) + qtdeProntoFrac;
          pesoPorStatus[ElementoStatus.pronto] =
              (pesoPorStatus[ElementoStatus.pronto] ?? 0) +
                  (qtdeProntoFrac * pesoPorUnidade);

          qtdPorStatus[ElementoStatus.armando] =
              (qtdPorStatus[ElementoStatus.armando] ?? 0) + qtdeArmandoFrac;
          pesoPorStatus[ElementoStatus.armando] =
              (pesoPorStatus[ElementoStatus.armando] ?? 0) +
                  (qtdeArmandoFrac * pesoPorUnidade);
        }
      }

      final Map<String, dynamic> resume = {
        'total_qtd': totalQtd,
        'total_peso': totalPeso,
        'details': {
          'aguardando': {
            'qtd': qtdPorStatus[ElementoStatus.aguardando],
            'peso': pesoPorStatus[ElementoStatus.aguardando],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.aguardando]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.aguardando]! / totalPeso
                : 0,
          },
          'armando': {
            'qtd': qtdPorStatus[ElementoStatus.armando],
            'peso': pesoPorStatus[ElementoStatus.armando],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.armando]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.armando]! / totalPeso
                : 0,
          },
          'pronto': {
            'qtd': qtdPorStatus[ElementoStatus.pronto],
            'peso': pesoPorStatus[ElementoStatus.pronto],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.pronto]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.pronto]! / totalPeso
                : 0,
          },
        }
      };

      // Persistir no Supabase
      await SupabaseService.client
          .from('pedidos')
          .update({'armacao_resumo': resume}).eq('id', pedidoId);

      // Atualizar localmente no objeto pedido para refletir no Kanban
      final pedido = BackendClient.pedidos.pepidosUnarchiveds.firstWhere(
          (p) => p.id == pedidoId,
          orElse: () => throw 'Pedido não encontrado');
      pedido.armacaoResumo.clear();
      pedido.armacaoResumo.addAll(resume);

      log('armacaoResumo atualizado: $totalQtd elementos, ${totalPeso.toStringAsFixed(1)} kg');
    } catch (e) {
      log('Erro ao atualizar armacaoResumo: $e');
    }
  }

  // ─── SALVAR ELEMENTO3
  // ──────────────────────────────────────────────────────
  Future<void> onSaveElemento(ElementoCreateModel form, String pedidoId) async {
    try {
      final elementoMap = {
        'id': form.id,
        'pedido_id': pedidoId,
        'nome': form.nome.text,
        'qtde': form.qtdeInt,
      };

      await SupabaseService.client.from('elementos').upsert(elementoMap);

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
          'bitola_id': posicao.produto!.id,
          'peso_kg': posicao.pesoDouble,
          'qtde': posicao.qtdeInt,
          'compr_unit': posicao.comprUnitDouble,
          'compr_corte': posicao.comprCorteDouble,
        });

        // Salvar medidas variáveis (limpa e reinsere)
        await SupabaseService.client
            .from('elemento_posicao_medidas')
            .delete()
            .eq('posicao_id', posicao.id);
        for (final medida in posicao.medidas) {
          await SupabaseService.client.from('elemento_posicao_medidas').upsert({
            'id': medida.id,
            'posicao_id': posicao.id,
            'compr_unit': medida.comprUnit,
            'compr_corte': medida.comprCorte,
            'qtde': medida.qtde,
          });
        }
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
        showInfoDialog(
            'Não Permitido: Não é possível excluir um elemento que já está sendo armando ou pronto.');
        return;
      }
      showLoadingDialog();
      // Remove dependências manualmente para evitar violar Foreign Keys caso não haja ON DELETE CASCADE
      await SupabaseService.client
          .from('elemento_posicoes')
          .delete()
          .eq('elemento_id', elemento.id);
      await SupabaseService.client
          .from('elemento_arquivos')
          .delete()
          .eq('elemento_id', elemento.id);

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

  // ─── GERENCIAMENTO DE ARQUIVOS ─────────────────────────────────────────
  Future<void> onAddArquivo(ElementoModel elemento, String name,
      Uint8List bytes, String mimeType) async {
    try {
      final isPdf =
          mimeType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        // O dialog de loading com stream é aberto pela UI (_ElementoArquivosDialog)
        loadingMessageStream.add('Preparando otimização...');
        await _optimizeAndUploadPdf(elemento, name, bytes);
        await onFetch(elemento.pedidoId);
        if (contextGlobal.mounted)
          Navigator.pop(contextGlobal); // Fecha o dialog da UI
        NotificationService.showPositive(
            'Sucesso', 'Desenho otimizado e anexado!');
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
      NotificationService.showPositive(
          'Sucesso', 'Arquivo anexado com sucesso!');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      log('ElementoController.onAddArquivo erro: $e');
      NotificationService.showNegative('Erro', 'Falha ao anexado arquivo.');
    }
  }

  /// ─── MOTOR DE OTIMIZAÇÃO DE DESENHOS (PDF -> JPG HD) ──────────────
  Future<void> _optimizeAndUploadPdf(
      ElementoModel elemento, String originalName, Uint8List pdfBytes) async {
    PdfDocument? document;
    try {
      // Busca o nível atualizado do banco antes de processar
      try {
        final configRaw = await SupabaseService.client
            .from('configs')
            .select()
            .eq('key', 'pdf_optimization_level')
            .maybeSingle();
        if (configRaw != null) {
          final val = int.tryParse(configRaw['value'].toString());
          if (val != null)
            PreferencesService.pdfOptimizationLevel.add(val.clamp(0, 10));
        }
      } catch (_) {} // Se falhar, usa o valor em memória

      document = await PdfDocument.openData(pdfBytes);
      final int pageCount = document.pagesCount;

      final level = PreferencesService.pdfOptimizationLevel.value;
      for (int i = 1; i <= pageCount; i++) {
        loadingMessageStream.add(
            'Processando página $i de $pageCount...\nOtimizando com nível $level');

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

  Future<void> onDeleteAllArquivos(
      ElementoModel elemento, String pedidoId) async {
    try {
      showLoadingDialog();
      for (final arquivo in List.from(elemento.arquivos)) {
        await SupabaseStorageService.deleteFile(arquivo.url);
        await AppSupabaseClient.elementoArquivos.delete(arquivo.id);
      }
      await onFetch(pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      NotificationService.showPositive(
          'Sucesso', 'Todos os arquivos removidos!');
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // Fecha loading
      log('ElementoController.onDeleteAllArquivos erro: $e');
    }
  }

  // ─── DELETAR TODOS OS ELEMENTOS ───────────────────────────────────────────
  Future<void> onDeleteAllElementos(String pedidoId) async {
    try {
      if (elementos.any((e) => e.status != ElementoStatus.aguardando)) {
        showInfoDialog(
            'Operação Negada: Existem elementos que já estão em produção ou concluídos. Remova individualmente os que permite exclusão.');
        return;
      }
      showLoadingDialog();

      // Resgata os IDs para deletar filhos
      final eRaw = await SupabaseService.client
          .from('elementos')
          .select('id')
          .eq('pedido_id', pedidoId);
      final eIds = eRaw.map((e) => e['id'].toString()).toList();

      if (eIds.isNotEmpty) {
        await SupabaseService.client
            .from('elemento_posicoes')
            .delete()
            .filter('elemento_id', 'in', eIds);
        await SupabaseService.client
            .from('elemento_arquivos')
            .delete()
            .filter('elemento_id', 'in', eIds);
      }

      await SupabaseService.client
          .from('elementos')
          .delete()
          .eq('pedido_id', pedidoId);

      await onFetch(pedidoId);
      if (contextGlobal.mounted) Navigator.pop(contextGlobal); // fecha loading
      NotificationService.showPositive(
          'Sucesso', 'Todos os elementos foram removidos.');
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
      final imageBytes = await LogoHelper.logoBytesForPdf();

      final relatorio = RelatorioElementoPdfPage(pedido: pedido, elementos: elementos);
      pdf.addPage(relatorio.build(imageBytes));

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

  /// Normaliza strings numéricas do padrão BR (1.018,08) para o formato
  /// internacional (1018.08) compatível com [double.tryParse].
  /// Detecta automaticamente se o ponto é separador de milhar.
  String _normalizarNumero(String valor) {
    if (valor.isEmpty) return '0';
    // Remove espaços e letras residuais (ex: "kg")
    valor = valor.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
    // Padrão BR: ponto como milhar e vírgula como decimal (ex: 1.018,08)
    if (valor.contains('.') && valor.contains(',')) {
      return valor.replaceAll('.', '').replaceAll(',', '.');
    }
    // Só vírgula → decimal BR (ex: 203,62)
    if (valor.contains(',')) {
      return valor.replaceAll(',', '.');
    }
    // Só ponto → pode ser milhar OU decimal
    // Se tem mais de um ponto, são milhares (ex: 1.018.000 → 1018000)
    if (RegExp(r'\..*\.').hasMatch(valor)) {
      return valor.replaceAll('.', '');
    }
    // Ponto único: verificar se são 3 dígitos depois (milhar) ou não (decimal)
    final dotIndex = valor.indexOf('.');
    if (dotIndex != -1) {
      final afterDot = valor.substring(dotIndex + 1);
      if (afterDot.length == 3 && !afterDot.contains(RegExp(r'[^0-9]'))) {
        // Ex: 1.018 → provavelmente milhar (1018)
        return valor.replaceAll('.', '');
      }
    }
    return valor;
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

      importProgressStream
          .add(ImportProgress(status: 'Lendo dados do arquivo CSV...'));

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

      final lines = rawText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Validação básica se parece um CSV válido
      if (lines.length <= 1 || !lines.first.contains(';')) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error':
              'O arquivo não parece ser um CSV válido separado por ponto-e-vírgula (;).',
          'rawText': rawText
        };
      }

      final List<ElementoCreateModel> novosElementos = [];
      ElementoCreateModel? currentElement;

      // Extrai a linha de cabeçalho (ignorando case e espaços)
      final headerLine =
          lines.first.split(';').map((e) => e.trim().toUpperCase()).toList();

      // Cria mapa de índices para procurar colunas chaves
      final Map<String, int> headerIndex = {};
      for (int i = 0; i < headerLine.length; i++) {
        headerIndex[headerLine[i]] = i;
      }

      int getIndex(List<String> possibleNames) {
        for (String name in possibleNames) {
          if (headerIndex.containsKey(name)) return headerIndex[name]!;
          // Pesquisa com partially match se não achar exato (ex: PESO (KG) -> PESO)
          final match =
              headerIndex.keys.firstWhereOrNull((k) => k.contains(name));
          if (match != null) return headerIndex[match]!;
        }
        return -1;
      }

      // Procura índices usando possíveis variações de nome na sua planilha
      final idxElemento = getIndex(['ELEMENTO']);
      final idxIdElem = getIndex(['ID ELEM', 'ID_ELEM', 'IDELEM']);
      final idxQtdeElementos = getIndex([
        'QTDE ELEM',
        'QTDE_ELEMENTOS',
        'QTDE ELEMENTOS',
        'QTD_ELEMENTOS',
        'QTD ELEMENTOS'
      ]);
      final idxOs = getIndex(['OS', 'O.S.', 'O.S']);
      final idxPosicao = getIndex(['POSICAO', 'POSIÇÃO', 'POS.']);
      final idxBitola = getIndex(['BITOLA', 'DIAMETRO']);
      final idxPeso = getIndex(['PESO (KG)', 'PESO']);
      final idxQtde =
          getIndex(['QTDE', 'QUANTIDADE', 'QTD']); // qtde da posicao
      final idxComprUnit = getIndex(['COMPR. UNIT.', 'COMPR. UNIT', 'COMPR UNIT', 'COMPRIMENTO UNIT', 'COMPR.UNIT']);
      final idxComprCorte =
          getIndex(['COMPR. CORTE', 'COMPR CORTE', 'COMPRIMENTO CORTE', 'COMPR.CORTE', 'COMPR. CORTE.']);

      if (idxElemento == -1 ||
          idxPosicao == -1 ||
          idxBitola == -1 ||
          idxPeso == -1) {
        importProgressStream.add(null);
        return {
          'success': false,
          'error': 'O CSV fornecido não está no padrão de importação.\n\n'
              'Seu arquivo DEVE conter as seguintes colunas na primeira linha (cabeçalho):\n'
              '• ELEMENTO\n'
              '• POSICAO (ou POS.)\n'
              '• BITOLA (ou DIAMETRO)\n'
              '• PESO (ou PESO (KG))\n\n'
              'Colunas opcionais identificadas pelo sistema:\n'
              '• ID ELEM (Identificador Único do Elemento)\n'
              '• QTDE ELEMENTOS (Quantidade de conjuntos)\n'
              '• OS ou O.S. (Ordem de Serviço)\n'
              '• QTDE ou QUANTIDADE (Qtd de peças na posição, ex: 6 ou 2x6)\n'
              '• COMPR CORTE e COMPR UNIT (Tamanho ou variação, ex: 100 var 150)\n\n'
              'Dica: Salve sua planilha Excel como "CSV UTF-8 (separado por vírgulas)" (que no padrão do Excel BR usará ponto e vírgula).',
          'rawText': rawText
        };
      }

      String currentElementIdStr = '';

      // Pula a linha de cabeçalho
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        final columns = line.split(';');

        if (columns.length <= idxBitola) continue;

        final elNome = columns[idxElemento].trim();
        final idElemStr = idxIdElem != -1 && columns.length > idxIdElem
            ? columns[idxIdElem].trim()
            : '';
        final elQtdeStr =
            idxQtdeElementos != -1 && columns.length > idxQtdeElementos
                ? columns[idxQtdeElementos].trim()
                : '1';
        final osNumber =
            idxOs != -1 && columns.length > idxOs ? columns[idxOs].trim() : '';
        final posNome = columns[idxPosicao].trim();
        final bitolaStr =
            columns[idxBitola].trim().replaceAll('mm', '').replaceAll(',', '.');
        final pesoStr = idxPeso != -1 && columns.length > idxPeso
            ? _normalizarNumero(columns[idxPeso].trim())
            : '0';
        final posQtdeStr = idxQtde != -1 && columns.length > idxQtde
            ? columns[idxQtde].trim()
            : '0';
        final comprCorteStr = idxComprCorte != -1 && columns.length > idxComprCorte
            ? _normalizarNumero(columns[idxComprCorte].trim())
            : '0';
        final comprUnitStr = idxComprUnit != -1 && columns.length > idxComprUnit
            ? _normalizarNumero(columns[idxComprUnit].trim())
            : '0';

        if (elNome.isEmpty || posNome.isEmpty) continue;

        final elQtdeNormalizado = int.tryParse(elQtdeStr)?.toString() ?? '1';

        // Agrupa por ID ELEM ou (NOME + QTDE ELEM)
        if (currentElement == null ||
            (idElemStr.isNotEmpty && currentElementIdStr != idElemStr) ||
            (idElemStr.isEmpty &&
                (currentElement.nome.text != elNome ||
                    currentElement.qtde.text != elQtdeNormalizado))) {
          if (currentElement != null && currentElement.posicoes.isNotEmpty) {
            novosElementos.add(currentElement);
          }
          currentElement = ElementoCreateModel();
          currentElementIdStr = idElemStr;
          currentElement.nome.text = elNome;
          currentElement.qtde.text = elQtdeNormalizado;
        }

        final bitola = double.tryParse(bitolaStr);
        final pesoLido = double.tryParse(pesoStr);

        if (bitola != null && pesoLido != null) {
          final produtoEncontrado = BackendClient.bitolas.data.where((p) {
            final textToSearch =
                '${p.nome} ${p.labelMinified}'.replaceAll(',', '.');
            final extractedNumbers =
                RegExp(r'\d+(?:\.\d+)?').allMatches(textToSearch);
            return extractedNumbers.any((match) {
              final extractedValue = double.tryParse(match.group(0)!);
              return extractedValue == bitola;
            });
          }).firstOrNull;

          if (produtoEncontrado != null) {
            // Analisar a quantidade (ex: "6" ou "1 X 19" ou "2 X 16")
            // Formato CSV: "MULTIPLIER X STEPS"
            //   parts[0] = multiplier (peças por variante de comprimento)
            //   parts[1] = steps     (número de variantes/medidas distintas)
            final qtyLower = posQtdeStr.toLowerCase();
            int multiplier = 1;
            int steps = 1;

            if (qtyLower.contains('x')) {
              final parts = qtyLower.split('x');
              multiplier = int.tryParse(parts[0].trim()) ?? 1; // A = peças por variante
              steps      = int.tryParse(parts[1].trim()) ?? 1; // B = nº de variantes
            } else {
              steps = int.tryParse(qtyLower) ?? 1;
              if (steps == 0) steps = 1;
            }

            // Calcular a qtde total da posição
            final int totalQtdePosicao = qtyLower.contains('x')
                ? multiplier * steps
                : steps;

            // Analisar Variação COMPR CORTE "100 var 150"
            final varCorteMatch = RegExp(r'(\d+(?:\.\d+)?)\s*var\s*(\d+(?:\.\d+)?)', caseSensitive: false)
                .firstMatch(comprCorteStr);
            // Analisar Variação COMPR UNIT "55 var 609"
            final varUnitMatch = RegExp(r'(\d+(?:\.\d+)?)\s*var\s*(\d+(?:\.\d+)?)', caseSensitive: false)
                .firstMatch(comprUnitStr);

            final bool temVariacao = varCorteMatch != null && steps > 1;

            // Criar a posição (sempre UMA só por linha do CSV)
            final pos = ElementoPosicaoCreateModel();
            pos.nome.text = posNome;
            pos.numeroOs.text = osNumber;
            // O peso do CSV já vem multiplicado pela QTDE ELEM (peso total de todos os elementos).
            // Divide pela qtde de elementos para obter o peso de 1 elemento.
            final qtdeElem = int.tryParse(elQtdeStr) ?? 1;
            final pesoUnitario = qtdeElem > 1 ? pesoLido / qtdeElem : pesoLido;
            pos.pesoKg.text = pesoUnitario.toStringAsFixed(3);
            pos.qtde.text = totalQtdePosicao.toString();
            pos.produto = produtoEncontrado;

            if (temVariacao) {
              // Posição variável: comprUnit e comprCorte ficam 0 (os valores reais estão nas medidas)
              pos.comprUnit.text = '0';
              pos.comprCorte.text = '0';

              final minCorte = double.tryParse(varCorteMatch.group(1)!) ?? 0;
              final maxCorte = double.tryParse(varCorteMatch.group(2)!) ?? 0;
              final stepCorte = (maxCorte - minCorte) / (steps - 1);

              double minUnit = 0, stepUnit = 0;
              if (varUnitMatch != null) {
                minUnit = double.tryParse(varUnitMatch.group(1)!) ?? 0;
                final maxUnit = double.tryParse(varUnitMatch.group(2)!) ?? 0;
                stepUnit = (maxUnit - minUnit) / (steps - 1);
              }

              for (int j = 0; j < steps; j++) {
                pos.medidas.add(PosicaoMedidaCreateModel(
                  comprUnit: minUnit + (stepUnit * j),
                  comprCorte: minCorte + (stepCorte * j),
                  qtde: multiplier,
                ));
              }
            } else {
              // Posição com comprimento fixo
              pos.comprUnit.text = comprUnitStr.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
              pos.comprCorte.text = comprCorteStr.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
            }

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
            'bitola_id': posicao.produto!.id,
            'peso_kg': posicao.pesoDouble,
            'qtde': posicao.qtdeInt,
            'compr_unit': posicao.comprUnitDouble,
            'compr_corte': posicao.comprCorteDouble,
          });

          // Salvar medidas variáveis na sub-tabela
          for (final medida in posicao.medidas) {
            await SupabaseService.client.from('elemento_posicao_medidas').upsert({
              'id': medida.id,
              'posicao_id': posicao.id,
              'compr_unit': medida.comprUnit,
              'compr_corte': medida.comprCorte,
              'qtde': medida.qtde,
            });
          }
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
      isOk:
          divergencias.isEmpty && (totalPedido - totalElementos).abs() < 0.001,
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
  final PedidoBitolaModel produto;
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
