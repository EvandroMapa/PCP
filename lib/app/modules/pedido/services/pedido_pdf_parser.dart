import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoPdfParser {
  static Map<String, dynamic> parse(String text) {
    log('--- RAW PDF START ---');
    log(text);
    log('--- RAW PDF END ---');

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

    // 1. Extrair Pedido Financeiro (Pega o primeiro número após "Pedido")
    final pedidoRegExp = RegExp(r'Pedido\s*[:\-]?[\s\S]*?(\d+)', caseSensitive: false);
    final pedidoMatch = pedidoRegExp.firstMatch(text);
    if (pedidoMatch != null) {
      data['pedidoFinanceiro'] = pedidoMatch.group(1) ?? '';
    }

    // 2. Extrair Cliente
    final clienteRegExp = RegExp(r'Cliente\s*[:\-]?[\s\S]*?(\d+)\s*[-]\s*([^\n\r]+)', caseSensitive: false);
    final clienteMatch = clienteRegExp.firstMatch(text);
    if (clienteMatch != null) {
      data['clienteCodigo'] = clienteMatch.group(1) ?? '';
      data['clienteNome'] = (clienteMatch.group(2) ?? '').trim();
    }

    // 3. Extrair Totais Financeiros
    data['subtotal'] = _extractValue(text, r'Subtotal\s*[:\-]?\s*([\d,.]+)');
    data['taxas'] = _extractValue(text, r'Taxas\s*[:\-]?\s*([\d,.]+)');
    data['desconto'] = _extractValue(text, r'Desconto\s*[:\-]?\s*([\d,.]+)');
    data['total'] = _extractValue(text, r'Total\s*(?:Geral|Líquido)?\s*[:\-]?\s*([\d,.]+)');

    // 4. Extrair Planilhamento e Romaneio (Novo)
    data['planilhamento'] = _extractString(text, r'(?:Planilhamento|Plan\.)\s*[:\-]?\s*([^\n\r]+)');
    data['romaneio'] = _extractString(text, r'(?:Romaneio|Rom\.)\s*[:\-]?\s*([^\n\r]+)');

    // 5. Extrair Produtos da Tabela
    final List<String> units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];
    final String unitsPattern = units.join('|');

    for (var line in text.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Procura o padrão: [Código de 5-6 dígitos][Descrição...][UNIDADE][Lixo Numérico]
      // Ex: 109499VERGALHAO 10,0 MM 3/8 PA CD CDA13.FAT2-CDAKG181,448,901.614,82
      final rowMatch = RegExp('^(\\d{4,7})(.+?)($unitsPattern)([\\d,.]+)', caseSensitive: false).firstMatch(line);
      
      if (rowMatch != null) {
        final codigo = rowMatch.group(1)!;
        String descricao = rowMatch.group(2)!.trim();
        final unidade = rowMatch.group(3)!.toUpperCase();
        final numericTail = rowMatch.group(4)!;

        // Tenta desmembrar a "cauda numérica" (Ex: 181,448,901.614,82)
        // Regra: Os últimos caracteres costumam ser o Total (com 2 casas decimais e separador de milhar opcional)
        // Usamos uma regex para pegar 3 grupos de números com vírgula
        final valuesMatch = RegExp(r'(\d+,\d{2})(\d+,\d{2})([\d.]*,\d{2})$').firstMatch(numericTail);
        
        double qtde = 0;
        double unitario = 0;
        double total = 0;

        if (valuesMatch != null) {
            qtde = _parseDecimal(valuesMatch.group(1)!);
            unitario = _parseDecimal(valuesMatch.group(2)!);
            total = _parseDecimal(valuesMatch.group(3)!);
        } else {
            // Fallback se não conseguir quebrar em 3 perfeitamente
            // Tenta pegar o último valor como total e o primeiro como qtde
            final allNumbers = RegExp(r'\d+,\d{2}').allMatches(numericTail).map((m) => m.group(0)!).toList();
            if (allNumbers.length >= 2) {
                qtde = _parseDecimal(allNumbers.first);
                total = _parseDecimal(allNumbers.last);
                if (allNumbers.length >= 3) unitario = _parseDecimal(allNumbers[1]);
            }
        }

        if (qtde > 0) {
          data['produtos'].add({
            'codigo': codigo,
            'descricao': descricao,
            'unidade': unidade,
            'qtde': qtde,
            'unitario': unitario,
            'total': total,
          });
        }
      }
    }

    return data;
  }

  static double _extractValue(String text, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false, dotAll: true);
      final matches = regExp.allMatches(text);
      if (matches.isNotEmpty) {
        return _parseDecimal(matches.last.group(1) ?? '0');
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
