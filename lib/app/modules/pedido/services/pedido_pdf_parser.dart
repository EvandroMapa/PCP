import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoPdfParser {
  static Map<String, dynamic> parse(String text) {
    final Map<String, dynamic> data = {
      'pedidoFinanceiro': '',
      'clienteCodigo': '',
      'clienteNome': '',
      'produtos': <Map<String, dynamic>>[],
      'subtotal': 0.0,
      'taxas': 0.0,
      'desconto': 0.0,
      'total': 0.0,
    };

    // 1. Extrair Pedido Financeiro
    final pedidoRegExp = RegExp(r'Pedido\s*:\s*(\d+)');
    final pedidoMatch = pedidoRegExp.firstMatch(text);
    if (pedidoMatch != null) {
      data['pedidoFinanceiro'] = pedidoMatch.group(1) ?? '';
    }

    // 2. Extrair Cliente (Código e Nome)
    // Suporte para: "Cliente: 3544 - Nome" ou "Cliente: \n 3544 - Nome"
    final clienteRegExp = RegExp(r'Cliente:\s*(\d+)\s*-\s*([^\n\r]+)');
    final clienteMatch = clienteRegExp.firstMatch(text);
    if (clienteMatch != null) {
      data['clienteCodigo'] = clienteMatch.group(1) ?? '';
      data['clienteNome'] = (clienteMatch.group(2) ?? '').trim();
    }

    // 3. Extrair Totais Financeiros
    data['subtotal'] = _extractValue(text, r'Subtotal\s*:\s*([\d,.]+)');
    data['taxas'] = _extractValue(text, r'Taxas\s*:\s*([\d,.]+)');
    data['desconto'] = _extractValue(text, r'Desconto\s*:\s*([\d,.]+)');
    data['total'] = _extractValue(text, r'Total\s*:\s*([\d,.]+)');

    // 4. Extrair Produtos da Tabela
    // Regex mais flexível:
    // - Captura código (4+ dígitos)
    // - Descrição (até a unidade)
    // - Unidade (expandida: KG, UN, PC, MT, PÇ, BAR, PCT, M2, CJ, Unid, etc)
    // - Qtde, Unitário, Total (formato 0.000,00 ou 0,00)
    final productRegExp = RegExp(
      r'(\d{4,})\s+(.+?)\s+(KG|UN|PC|MT|PÇ|BAR|PCT|M2|CJ|Unid|Pç|UNID)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)',
      caseSensitive: false,
    );

    final matches = productRegExp.allMatches(text);
    for (final match in matches) {
      final codigo = match.group(1) ?? '';
      final descricao = match.group(2) ?? '';
      final qtde = _parseDecimal(match.group(4) ?? '0');
      final unitario = _parseDecimal(match.group(5) ?? '0');
      final total = _parseDecimal(match.group(6) ?? '0');

      data['produtos'].add({
        'codigo': codigo,
        'descricao': descricao.trim(),
        'qtde': qtde,
        'unitario': unitario,
        'total': total,
      });
    }

    return data;
  }

  static double _extractValue(String text, String pattern) {
    final regExp = RegExp(pattern, caseSensitive: false);
    final match = regExp.firstMatch(text);
    if (match != null) {
      return _parseDecimal(match.group(1) ?? '0');
    }
    return 0.0;
  }

  static double _parseDecimal(String value) {
    // Remove pontos de milhar e troca vírgula por ponto decimal
    final clean = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }
}
