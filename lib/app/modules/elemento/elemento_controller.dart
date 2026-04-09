import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';
import 'package:collection/collection.dart';

final elementoCtrl = ElementoController();

class ElementoController {
  static final ElementoController _instance = ElementoController._();
  ElementoController._();
  factory ElementoController() => _instance;

  final AppStream<List<ElementoModel>> elementosStream =
      AppStream<List<ElementoModel>>.seed([]);
  List<ElementoModel> get elementos => elementosStream.value;

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
  }

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

  // ─── IMPORTAR PDF ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> onImportPDF(Uint8List bytes, PedidoModel pedido) async {
    String rawText = '';
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      rawText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (rawText.trim().isEmpty) {
        return {'success': false, 'error': 'PDF parece estar sem texto (pode ser uma imagem).', 'rawText': ''};
      }

      final lines = rawText.split('\n');
      String? currentElementName;
      List<ElementoPosicaoCreateModel> currentPosicoes = [];
      final List<ElementoCreateModel> novosElementos = [];

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // 1. Identificar Header de Elemento (ex: "Elemento EP301")
        final elementMatch = RegExp(r'Elemento\s+([A-Z0-9.\-_]+)', caseSensitive: false).firstMatch(line);
        if (elementMatch != null) {
          if (currentElementName != null && currentPosicoes.isNotEmpty) {
            final el = ElementoCreateModel()..nome.text = currentElementName;
            el.posicoes = List.from(currentPosicoes);
            novosElementos.add(el);
          }
          currentElementName = elementMatch.group(1);
          currentPosicoes = [];
          continue;
        }

        // 2. Identificar Linha de Posição
        // Padrão esperado: Pos Bitola Aço Qtde Compr Peso [Outros] OS
        // Tenta capturar 6+ blocos que pareçam uma linha de tabela, mesmo se estiverem um pouco grudados
        // Ex: "01  20,00  CA50  8  120  24,000  (O)  1"
        final parts = line.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        
        if (parts.length >= 6) {
          // Heurística para bitola: Geralmente é o segundo campo e tem "," ou ".00"
          final bitolaStr = parts[1].replaceAll(',', '.');
          final bitola = double.tryParse(bitolaStr);
          
          if (bitola != null) {
            // Peso: Geralmente é um dos últimos valores numéricos
            double? peso;
            String? osStr;
            
            // Varre do fim para o início para achar OS e Peso
            for (int i = parts.length - 1; i >= 4; i--) {
                final cleaned = parts[i].replaceAll(',', '.');
                final val = double.tryParse(cleaned);
                if (val != null) {
                    if (osStr == null) {
                        osStr = parts[i]; 
                    } else if (peso == null) {
                        peso = val;
                        break;
                    }
                }
            }
            
            if (peso != null && currentElementName != null) {
              final pos = ElementoPosicaoCreateModel();
              pos.nome.text = parts[0];
              pos.numeroOs.text = osStr ?? '';
              pos.pesoKg.text = peso.toStringAsFixed(3);
              
              // Mapeia bitola: remove ".0" para facilitar o "contains"
              final bMatch = bitola.toString().replaceAll(RegExp(r'\.0$'), '');
              pos.produto = pedido.getProdutos()
                  .map((e) => e.produto)
                  .where((p) => p.nome.contains(bMatch) || p.labelMinified.contains(bMatch))
                  .firstOrNull;

              if (pos.produto != null) {
                currentPosicoes.add(pos);
              }
            }
          }
        }
      }

      // Adicionar o último elemento capturado
      if (currentElementName != null && currentPosicoes.isNotEmpty) {
        final el = ElementoCreateModel()..nome.text = currentElementName;
        el.posicoes = List.from(currentPosicoes);
        novosElementos.add(el);
      }

      if (novosElementos.isEmpty) {
        return {'success': false, 'error': 'Nenhum elemento ou posição válida foi identificado.', 'rawText': rawText};
      }

      // Salvar no Banco
      for (final el in novosElementos) {
        await onSaveElemento(el, pedido.id);
      }
      
      await onFetch(pedido.id);
      return {'success': true, 'elementsFound': novosElementos.length, 'rawText': rawText};
    } catch (e) {
      print('ElementoController.onImportPDF erro: $e');
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
        pesoNasPosicoesMap[posicao.produtoId] =
            (pesoNasPosicoesMap[posicao.produtoId] ?? 0.0) + posicao.pesoKg;
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
