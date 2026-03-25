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
    };

    // 1. Extrair Pedido Financeiro
    final pedidoRegExp = RegExp(r'Pedido\s*:\s*(\d+)');
    final pedidoMatch = pedidoRegExp.firstMatch(text);
    if (pedidoMatch != null) {
      data['pedidoFinanceiro'] = pedidoMatch.group(1) ?? '';
    }

    // 2. Extrair Cliente (Código e Nome)
    // Ex: 3544 - Gabriel Wagner Santos Teixeira
    final clienteRegExp = RegExp(r'Cliente:\s*(\d+)\s*-\s*(.*)');
    final clienteMatch = clienteRegExp.firstMatch(text);
    if (clienteMatch != null) {
      data['clienteCodigo'] = clienteMatch.group(1) ?? '';
      data['clienteNome'] = (clienteMatch.group(2) ?? '').trim();
    }

    // 3. Extrair Produtos da Tabela
    // Padrão: Código Descrição ... Unidade Qtde Unitário Total
    // Ex: 109501 VERGALHAO 5,0 MM PA CD CDA 12.FAT2-CD KG 271,62 7,50 2.037,15
    final lines = text.split('\n');
    for (final line in lines) {
      final productRegExp = RegExp(
          r'^(\d{4,})\s+(.+?)\s+.*\s+(KG|UN|PC|MT|PÇ)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)$');
      final match = productRegExp.firstMatch(line.trim());
      if (match != null) {
        final codigo = match.group(1) ?? '';
        final descricao = match.group(2) ?? '';
        final qtde = _parseDecimal(match.group(4) ?? '0');
        final unitario = _parseDecimal(match.group(5) ?? '0');
        final total = _parseDecimal(match.group(6) ?? '0');

        data['produtos'].add({
          'codigo': codigo,
          'descricao': descricao,
          'qtde': qtde,
          'unitario': unitario,
          'total': total,
        });
      }
    }

    return data;
  }

  static double _parseDecimal(String value) {
    // Converte "2.037,15" para "2037.15"
    final clean = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }
}
