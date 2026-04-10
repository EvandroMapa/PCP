import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoPdfParser {
  static Map<String, dynamic> parse(String text) {
    log('--- INÍCIO EXTRAÇÃO PDF PEDIDO ---');
    log('CONTEÚDO BRUTO EXTRAÍDO:');
    log(text);
    log('--- FIM CONTEÚDO BRUTO ---');

    final Map<String, dynamic> data = {
      'pedidoFinanceiro': '',
      'clienteCodigo': '',
      'clienteNome': '',
      'produtos': <Map<String, dynamic>>[],
      'subtotal': 0.0,
      'taxas': 0.0,
      'desconto': 0.0,
      'total': 0.0,
      'planilhamento': '',
      'romaneio': '',
      'rawText': text,
    };

    final cleanText = text.replaceAll(RegExp(r'_{10,}'), '\n');

    // 2-5. Extração de Metadados e Financeiro
    data['pedidoFinanceiro'] = _extractString(cleanText, r'Pedido\s*[:\-]?\s*(\d+)');
    data['clienteCodigo'] = _extractString(cleanText, r'Cliente\s*[:\-]?\s*(\d+)');
    data['clienteNome'] = _extractString(cleanText, r'Cliente\s*[:\-]?\s*\d+\s*[-]?\s*([^\n\r]+)');
    data['planilhamento'] = _extractString(cleanText, r'(?:Planilhamento|Plan\.)\s*[:\-]?\s*([^\n\r]+)');
    data['romaneio'] = _extractString(cleanText, r'(?:Romaneio|Rom\.)\s*[:\-]?\s*([^\n\r]+)');
    data['taxas'] = _extractValue(cleanText, r'Taxas\s*[:\-]?\s*([\d,.]+)');
    data['desconto'] = _extractValue(cleanText, r'Desconto\s*[:\-]?\s*([\d,.]+)');

    // 6. Extrair Produtos (Novo Motor de Precisão com Âncora de Unidade)
    final List<String> units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];
    final String unitsPattern = units.join('|');

    // Dividir pelo cabeçalho para evitar pegar fones/endereço como códigos
    int startIndex = cleanText.toLowerCase().indexOf('código');
    if (startIndex == -1) startIndex = cleanText.toLowerCase().indexOf('descrição');
    if (startIndex == -1) startIndex = 0;
    
    final bodyText = cleanText.substring(startIndex);
    
    // Regex para capturar: [CÓDIGO][DESCRIÇÃO][UNIDADE][VALORES]
    // O pulo do gato: A unidade colada nos números é nossa âncora principal, sem exigir espaços
    final itemRegExp = RegExp('(\\d{4,7})\\s*([A-Za-z][\\s\\S]+?)($unitsPattern)\\s*([\\d,.]+)', caseSensitive: false);
    final matches = itemRegExp.allMatches(bodyText);

    for (final m in matches) {
        final codigo = m.group(1)!;
        if (codigo == data['pedidoFinanceiro']) continue;

        String descricao = m.group(2)!.trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
        final unidade = m.group(3)!.toUpperCase();
        final numericTail = m.group(4)!;
        
        // Pega todos os números com formato decimal ,X ou ,XX ou .X
        final allNumbers = RegExp(r'[\d.,]*\d+,\d{1,3}').allMatches(numericTail).map((mn) => mn.group(0)!).toList();
        
        if (allNumbers.length >= 2) {
            final double q = _parseDecimal(allNumbers[0]);
            final double u = _parseDecimal(allNumbers[1]);
            final double t = double.parse((q * u).toStringAsFixed(2));
            
            log('ITEM DETECTADO: $codigo | $q $unidade x $u = $t');

            data['produtos'].add({
                'codigo': codigo,
                'descricao': descricao,
                'unidade': unidade,
                'qtde': q,
                'unitario': u,
                'total': t,
            });
        }
    }

    // 8. Totais Finais (Soma calculada e Subtotal de conferência)
    double vSubtotalCalculado = 0;
    for (final p in data['produtos']) {
        vSubtotalCalculado += p['total'];
    }
    
    final double subPDF = _extractValue(cleanText, r'Subtotal\s*[:\-]?\s*([\d,.]+)');
    data['subtotal'] = vSubtotalCalculado > 0 ? double.parse(vSubtotalCalculado.toStringAsFixed(2)) : subPDF;
    data['total'] = double.parse((data['subtotal'] + data['taxas'] - data['desconto']).toStringAsFixed(2));

    log('RESUMO: Itens=${data['produtos'].length} | Subtotal=${data['subtotal']} | Total=${data['total']}');

    return data;
  }

  static double _extractValue(String text, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      final match = regExp.firstMatch(text);
      if (match != null) {
        // Se pegou o grupo 1 (valor na mesma linha), usa ele. 
        if (match.groupCount >= 1 && match.group(1) != null) {
           return _parseDecimal(match.group(1)!);
        }
        // Senão, tenta na linha de baixo
        final index = match.end;
        final remainingText = text.substring(index);
        final valueMatch = RegExp(r'\s*([\d,.]+)').firstMatch(remainingText);
        if (valueMatch != null) {
           return _parseDecimal(valueMatch.group(1) ?? '0');
        }
      }
    } catch (_) {}
    return 0.0;
  }

  static String _extractString(String text, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      final match = regExp.firstMatch(text);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    } catch (_) {}
    return '';
  }

  static double _parseDecimal(String value) {
    if (value.isEmpty) return 0.0;
    // Remove pontos de milhar e troca vírgula por ponto
    String clean = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }
}

