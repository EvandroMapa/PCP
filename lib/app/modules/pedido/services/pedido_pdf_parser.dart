import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoPdfParser {
  static Map<String, dynamic> parse(String text) {
    // Log para depuração (visível no console de dev)
    log('--- RAW PDF TEXT START ---');
    log(text);
    log('--- RAW PDF TEXT END ---');

    final Map<String, dynamic> data = {
      'pedidoFinanceiro': '',
      'clienteCodigo': '',
      'clienteNome': '',
      'produtos': <Map<String, dynamic>>[],
      'subtotal': 0.0,
      'taxas': 0.0,
      'desconto': 0.0,
      'total': 0.0,
      'rawText': text, // Retornar texto bruto para permitir debug na UI se necessário
    };

    // 1. Extrair Pedido Financeiro (Mais flexível com o separador)
    final pedidoRegExp = RegExp(r'Pedido\s*[:\-]\s*(\d+)', caseSensitive: false);
    final pedidoMatch = pedidoRegExp.firstMatch(text);
    if (pedidoMatch != null) {
      data['pedidoFinanceiro'] = pedidoMatch.group(1) ?? '';
    }

    // 2. Extrair Cliente (Código e Nome)
    // Busca "Cliente:" seguido de código, hífen e nome. Aceita quebras de linha.
    final clienteRegExp = RegExp(r'Cliente\s*[:\-]\s*(\d+)\s*[-]\s*([^\n\r]+)', caseSensitive: false);
    final clienteMatch = clienteRegExp.firstMatch(text);
    if (clienteMatch != null) {
      data['clienteCodigo'] = clienteMatch.group(1) ?? '';
      data['clienteNome'] = (clienteMatch.group(2) ?? '').trim();
    }

    // 3. Extrair Totais Financeiros (Mais flexíveis com labels)
    data['subtotal'] = _extractValue(text, r'Subtotal\s*[:\-]?\s*([\d,.]+)');
    data['taxas'] = _extractValue(text, r'Taxas\s*[:\-]?\s*([\d,.]+)');
    data['desconto'] = _extractValue(text, r'Desconto\s*[:\-]?\s*([\d,.]+)');
    data['total'] = _extractValue(text, r'Total\s*(?:Geral|Líquido)?\s*[:\-]?\s*([\d,.]+)');

    // 4. Extrair Produtos da Tabela
    // Regex ultra-flexível:
    // - Código: 4 a 7 dígitos
    // - Descrição: qualquer coisa até a unidade
    // - Unidades: Expandidas e case-insensitive
    // - Valores: Suporta formatos com ou sem ponto de milhar
    final productRegExp = RegExp(
      r'(\d{4,7})\s+(.+?)\s+(KG|UN|PC|MT|PÇ|BAR|PCT|M2|CJ|Unid|Pç|UNID|FL|RL)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)',
      caseSensitive: false,
    );

    final matches = productRegExp.allMatches(text);
    for (final match in matches) {
      final codigo = (match.group(1) ?? '').trim();
      final descricao = (match.group(2) ?? '').trim();
      final unidade = (match.group(3) ?? '').toUpperCase();
      final qtde = _parseDecimal(match.group(4) ?? '0');
      final unitario = _parseDecimal(match.group(5) ?? '0');
      final total = _parseDecimal(match.group(6) ?? '0');

      // Validação básica para evitar falsos positivos
      if (qtde > 0 && total > 0) {
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

    return data;
  }

  static double _extractValue(String text, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      // Busca a última ocorrência (geralmente totais ficam no fim)
      final matches = regExp.allMatches(text);
      if (matches.isNotEmpty) {
        return _parseDecimal(matches.last.group(1) ?? '0');
      }
    } catch (_) {}
    return 0.0;
  }

  static double _parseDecimal(String value) {
    if (value.isEmpty) return 0.0;
    
    // Se houver vírgula e ponto, assume formato BR (1.234,56)
    if (value.contains(',') && value.contains('.')) {
      return double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    }
    // Se houver apenas vírgula, troca por ponto
    if (value.contains(',')) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    // Caso contrário tenta parse direto
    return double.tryParse(value) ?? 0.0;
  }
}
