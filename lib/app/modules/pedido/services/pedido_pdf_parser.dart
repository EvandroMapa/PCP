import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoPdfParser {
  static Map<String, dynamic> parse(String text) {
    print('--- INÍCIO EXTRAÇÃO PDF PEDIDO ---');
    print('CONTEÚDO BRUTO EXTRAÍDO:');
    print(text);
    print('--- FIM CONTEÚDO BRUTO ---');

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

    // 1. Limpeza inicial: Remover underlines que quebram a leitura de blocos
    final cleanText = text.replaceAll(RegExp(r'_{10,}'), '\n');

    // 2. Extrair Pedido Financeiro
    final pedidoRegExp = RegExp(r'Pedido\s*[:\-]?\s*(\d+)', caseSensitive: false);
    final pedidoMatch = pedidoRegExp.firstMatch(cleanText);
    if (pedidoMatch != null) {
      data['pedidoFinanceiro'] = pedidoMatch.group(1) ?? '';
    }

    // 3. Extrair Cliente (Melhorado para capturar código e nome mesmo sem traço perfeito)
    final clienteRegExp = RegExp(r'Cliente\s*[:\-]?\s*(\d+)\s*[-]?\s*([^\n\r]+)', caseSensitive: false);
    final clienteMatch = clienteRegExp.firstMatch(cleanText);
    if (clienteMatch != null) {
      data['clienteCodigo'] = clienteMatch.group(1) ?? '';
      data['clienteNome'] = (clienteMatch.group(2) ?? '').trim();
    }

    // 4. Extrair Planilhamento e Romaneio
    data['planilhamento'] = _extractString(cleanText, r'(?:Planilhamento|Plan\.)\s*[:\-]?\s*([^\n\r]+)');
    data['romaneio'] = _extractString(cleanText, r'(?:Romaneio|Rom\.)\s*[:\-]?\s*([^\n\r]+)');

    // 5. Extrair Taxas e Descontos (Para cálculo final)
    data['taxas'] = _extractValue(cleanText, r'Taxas\s*[:\-]?\s*([\d,.]+)');
    data['desconto'] = _extractValue(cleanText, r'Desconto\s*[:\-]?\s*([\d,.]+)');

    // 6. Extrair Produtos (Novo algoritmo robusto para Shop9)
    final List<String> units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];
    final String unitsPattern = units.join('|');

    // Dividir em blocos por Código (4-7 dígitos)
    // Procuramos um código que NÃO seja o número do pedido nem data
    final productSplitRegExp = RegExp(r'(?:\n|\r|^)(\d{4,7})(?=[A-Z\s])');
    final productMatches = productSplitRegExp.allMatches(cleanText).toList();

    for (var i = 0; i < productMatches.length; i++) {
        final match = productMatches[i];
        final codigo = match.group(1)!;
        if (codigo == data['pedidoFinanceiro']) continue;

        // O bloco vai do início deste código até o início do próximo ou até o fim
        final start = match.start;
        final end = (i + 1 < productMatches.length) ? productMatches[i + 1].start : cleanText.length;
        String block = cleanText.substring(start, end);

        // Tenta achar a unidade e os números no bloco
        final unitMatch = RegExp('($unitsPattern)\\s*([\\d,.]+)').firstMatch(block);
        if (unitMatch != null) {
            String descricao = block.substring(match.group(1)!.length, unitMatch.start).trim();
            descricao = descricao.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
            
            final unidade = unitMatch.group(1)!.toUpperCase();
            final numericTail = unitMatch.group(2)!;
            
            // Pega todos os números com formato decimal ,XX no final do bloco de números
            final allNumbers = RegExp(r'[\d.]*,\d{2}').allMatches(numericTail).map((m) => m.group(0)!).toList();
            
            double qtde = 0;
            double unitario = 0;
            double totalCalculado = 0;

            if (allNumbers.length >= 2) {
                qtde = _parseDecimal(allNumbers[0]);
                unitario = _parseDecimal(allNumbers[1]);
                totalCalculado = double.parse((qtde * unitario).toStringAsFixed(2));
                
                data['produtos'].add({
                    'codigo': codigo,
                    'descricao': descricao,
                    'unidade': unidade,
                    'qtde': qtde,
                    'unitario': unitario,
                    'total': totalCalculado,
                });
            }
        }
    }

    // 7. Fallback: Se não achou nada por blocos, tenta por linha (Regex agressiva)
    if (data['produtos'].isEmpty) {
        final fallbackRegExp = RegExp('(\\d{4,7})\\s*(.*?)\\s*($unitsPattern)\\s*([\\d,.]+)', caseSensitive: false);
        final matches = fallbackRegExp.allMatches(cleanText);
        for (final m in matches) {
            if (m.group(1) == data['pedidoFinanceiro']) continue;
            final qtdeTail = m.group(4)!;
            final nums = RegExp(r'[\d.]*,\d{2}').allMatches(qtdeTail).map((mn) => mn.group(0)!).toList();
            if (nums.length >= 2) {
                final q = _parseDecimal(nums[0]);
                final u = _parseDecimal(nums[1]);
                data['produtos'].add({
                    'codigo': m.group(1),
                    'descricao': m.group(2)!.trim(),
                    'unidade': m.group(3)!.toUpperCase(),
                    'qtde': q,
                    'unitario': u,
                    'total': double.parse((q * u).toStringAsFixed(2)),
                });
            }
        }
    }

    // 8. Calcular Totais do Pedido (Soma dos itens)
    double vSubtotal = 0;
    for (final p in data['produtos']) {
        vSubtotal += p['total'];
    }
    data['subtotal'] = double.parse(vSubtotal.toStringAsFixed(2));
    data['total'] = double.parse((data['subtotal'] + data['taxas'] - data['desconto']).toStringAsFixed(2));

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

