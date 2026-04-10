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

    // 4. Extrair Planilhamento e Romaneio
    data['planilhamento'] = _extractString(text, r'(?:Planilhamento|Plan\.)\s*[:\-]?\s*([^\n\r]+)');
    data['romaneio'] = _extractString(text, r'(?:Romaneio|Rom\.)\s*[:\-]?\s*([^\n\r]+)');

    // 6. Extrair Produtos da Tabela (Suporte a multi-linha e Shop9)
    // SEGURANÇA: Procurar onde começa a tabela de produtos para ignorar o cabeçalho (Endereço, etc)
    int tableStartIndex = text.toLowerCase().indexOf('código');
    if (tableStartIndex == -1) tableStartIndex = text.toLowerCase().indexOf('descrição');
    if (tableStartIndex == -1) tableStartIndex = 0;

    final String tableText = text.substring(tableStartIndex);
    final String pedidoFinanceiro = data['pedidoFinanceiro'];

    final List<String> units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];
    final String unitsPattern = units.join('|');

    // Identificar blocos de produtos: [Código de 4-7 dígitos] seguido de texto e unidade
    // Usamos um lookahead negativo para garantir que o código não seja o mesmo que o pedido financeiro
    final productBlockRegExp = RegExp(r'(\d{4,7})\s+([\s\S]+?)\s+(' + unitsPattern + r')\s+([\d,.\s]+)', caseSensitive: false);
    final matches = productBlockRegExp.allMatches(tableText);

    for (final match in matches) {
      final codigo = match.group(1)!;
      
      // Se o código for igual ao pedido financeiro e estivermos muito no início, ignorar
      if (codigo == pedidoFinanceiro && match.start < 50) continue;

      String rawDesc = match.group(2)!.trim();
      final unidade = match.group(3)!.toUpperCase();
      final numericTail = match.group(4)!.trim();

      // Limpar a descrição: No Shop9 multi-linha, a descrição pode conter lixo se a regex for muito ampla
      // Limitamos a descrição para não pegar mais de 200 caracteres (evita engolir o documento todo)
      if (rawDesc.length > 200) {
        // Tenta achar o código de volta dentro da descrição abusiva
        final subMatch = RegExp(r'(\d{4,7})').firstMatch(rawDesc);
        if (subMatch != null) {
           // Se achou outro código dentro, a regex falhou por ser gananciosa. 
           // Recortamos a descrição até o próximo código provável.
           rawDesc = rawDesc.substring(0, subMatch.start).trim();
        }
      }

      String descricao = rawDesc.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
      
      final allNumbers = RegExp(r'[\d.]*,\d{2}').allMatches(numericTail).map((m) => m.group(0)!).toList();
      
      double qtde = 0;
      double unitario = 0;
      double total = 0;

      if (allNumbers.length >= 3) {
        qtde = _parseDecimal(allNumbers[0]);
        unitario = _parseDecimal(allNumbers[1]);
        total = _parseDecimal(allNumbers[2]);
      } else if (allNumbers.length == 2) {
        qtde = _parseDecimal(allNumbers[0]);
        total = _parseDecimal(allNumbers[1]);
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

    // Fallback: Se não achou nada pelo bloco, tenta por linha (o método antigo era melhor para layouts lineares)
    if (data['produtos'].isEmpty) {
      for (var line in text.split('\n')) {
        line = line.trim();
        if (line.isEmpty) continue;
        final rowMatch = RegExp('^(\\d{4,7})(.+?)($unitsPattern)([\\d,.]+)', caseSensitive: false).firstMatch(line);
        if (rowMatch != null) {
          final codigo = rowMatch.group(1)!;
          final descricao = rowMatch.group(2)!.trim();
          final unidade = rowMatch.group(3)!.toUpperCase();
          final numericTail = rowMatch.group(4)!;
          final allNumbers = RegExp(r'\d+,\d{2}').allMatches(numericTail).map((m) => m.group(0)!).toList();
          if (allNumbers.length >= 2) {
            data['produtos'].add({
              'codigo': codigo,
              'descricao': descricao,
              'unidade': unidade,
              'qtde': _parseDecimal(allNumbers.first),
              'unitario': allNumbers.length >= 3 ? _parseDecimal(allNumbers[1]) : 0.0,
              'total': _parseDecimal(allNumbers.last),
            });
          }
        }
      }
    }

    return data;
  }

  static double _extractValue(String text, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      final match = regExp.firstMatch(text);
      if (match != null) {
        // Se o valor não estiver na mesma linha, tenta pegar o que vem logo após a quebra de linha
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
    String clean = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }
}
