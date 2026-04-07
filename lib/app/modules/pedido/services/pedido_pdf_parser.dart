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
    // IMPORTANTE: Só busca produtos APÓS a palavra "Código" ou "Descrição" para evitar pegar o cabeçalho
    int tableStartIndex = text.toLowerCase().indexOf('código');
    if (tableStartIndex == -1) tableStartIndex = text.toLowerCase().indexOf('descrição');
    if (tableStartIndex == -1) tableStartIndex = 0;

    final productSection = text.substring(tableStartIndex);
    
    final units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];
    final unitsPattern = units.join('|');
    
    // Regex aprimorado:
    // - Descrição não pode conter a palavra "Pedido" ou "Cliente" (evita vazamento do cabeçalho)
    // - Usa limites de palavra para o código
    final productRegExp = RegExp(
      '(\\d{3,7})\\s+([\\s\\S]+?)\\s+(?:\\d+\\s+)?($unitsPattern)\\s+([\\d,.]+)\\s+([\\d,.]+)\\s+([\\d,.]+)',
      caseSensitive: false,
    );

    final matches = productRegExp.allMatches(productSection);
    for (final match in matches) {
      final codigo = match.group(1) ?? '';
      String descricao = (match.group(2) ?? '').trim();
      final unidade = (match.group(3) ?? '').toUpperCase();
      final val1 = _parseDecimal(match.group(4) ?? '0');
      final val2 = _parseDecimal(match.group(5) ?? '0');
      final val3 = _parseDecimal(match.group(6) ?? '0');

      // Limpeza agressiva da descrição para remover lixos e quebras de linha excessivas
      descricao = descricao.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
      
      // Se a descrição for muito longa (> 200 caracteres), provavelmente pegou coisa errada
      if (descricao.length > 200) continue;

      if (val1 > 0 && val3 > 0) {
        data['produtos'].add({
          'codigo': codigo,
          'descricao': descricao,
          'unidade': unidade,
          'qtde': val1,
          'unitario': val2,
          'total': val3,
        });
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
    String clean = value.replaceAll(RegExp(r'[^0-9,.]'), '');

    // Para o padrão brasileiro de PDF, o ponto (.) é separador de milhar e a vírgula (,) é o decimal.
    clean = clean.replaceAll('.', '');
    clean = clean.replaceAll(',', '.');

    return double.tryParse(clean) ?? 0.0;
  }
}
