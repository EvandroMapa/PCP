import 'dart:developer';

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

    // 6. Extrair Produtos
    final List<String> units = ['KG', 'UN', 'PC', 'MT', 'PÇ', 'BAR', 'PCT', 'M2', 'CJ', 'UNID', 'Pç', 'FL', 'RL'];

    // Dividir pelo cabeçalho para evitar pegar fones/endereço como códigos
    int startIndex = cleanText.toLowerCase().indexOf('código');
    if (startIndex == -1) startIndex = cleanText.toLowerCase().indexOf('descrição');
    if (startIndex == -1) startIndex = 0;

    final bodyText = cleanText.substring(startIndex);

    // ── ESTRATÉGIA 1: Regex concatenado (formato inline) ──────────────────────
    final String unitsPattern = units.join('|');
    final itemRegExp = RegExp('(\\d{4,7})\\s*([A-Za-z][\\s\\S]+?)($unitsPattern)\\s*([\\d,.]+)', caseSensitive: false);
    final matches = itemRegExp.allMatches(bodyText);

    for (final m in matches) {
      final codigo = m.group(1)!;
      if (codigo == data['pedidoFinanceiro']) continue;

      String descricao = m.group(2)!.trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
      final unidade = m.group(3)!.toUpperCase();
      final numericTail = m.group(4)!;

      final List<double>? values = _breakConcatenatedNumbers(numericTail);

      if (values != null && values.length == 3) {
        final double q = values[0];
        final double u = values[1];
        final double t = values[2];

        log('ITEM DETECTADO (inline): $codigo | $q $unidade x $u = $t');

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

    // ── ESTRATÉGIA 2: Parse linha a linha (formato separado por newlines) ──────
    // Se a Estratégia 1 não encontrou nada, tenta parse sequencial
    if ((data['produtos'] as List).isEmpty) {
      log('Estratégia 1 vazia. Tentando parse linha a linha...');
      final lines = bodyText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Procurar código numérico de 4-7 dígitos
        if (!RegExp(r'^\d{4,7}$').hasMatch(line)) continue;
        final codigo = line;
        if (codigo == data['pedidoFinanceiro']) continue;

        // Coletar linhas de descrição até achar uma unidade
        String descricao = '';
        String unidade = '';
        int j = i + 1;

        while (j < lines.length) {
          final upper = lines[j].toUpperCase().trim();
          // Verificar se é uma unidade (pode estar concatenada como "1\nKG")
          // Primeiro checa se a linha atual é um número puro (quantidade) seguido por unidade na próxima
          if (units.contains(upper)) {
            unidade = upper;
            j++;
            break;
          }
          // Verificar se é "NÚMERO\nUNIDADE" pattern (ex: "1" seguido por "KG")
          if (RegExp(r'^\d+$').hasMatch(lines[j]) && j + 1 < lines.length && units.contains(lines[j + 1].toUpperCase().trim())) {
            // O número é a quantidade, a próxima linha é a unidade
            unidade = lines[j + 1].toUpperCase().trim();
            j += 2;
            break;
          }
          // Verificar se contém unidade no final (ex: "1 KG")
          bool foundUnit = false;
          for (final u in units) {
            if (upper.endsWith(' $u') || upper == u) {
              unidade = u;
              // Texto antes da unidade faz parte da descrição
              final beforeUnit = lines[j].substring(0, lines[j].toUpperCase().lastIndexOf(u)).trim();
              if (beforeUnit.isNotEmpty && !RegExp(r'^\d+$').hasMatch(beforeUnit)) {
                descricao += ' $beforeUnit';
              }
              foundUnit = true;
              j++;
              break;
            }
          }
          if (foundUnit) break;

          // Senão, é parte da descrição
          descricao += ' ${lines[j]}';
          j++;
        }

        descricao = descricao.trim();
        if (unidade.isEmpty || descricao.isEmpty) continue;

        // Agora esperamos 3 valores numéricos: qtde, unitário, total
        final List<double> numValues = [];
        while (j < lines.length && numValues.length < 3) {
          final val = _parseDecimalOrNull(lines[j]);
          if (val != null) {
            numValues.add(val);
            j++;
          } else {
            break;
          }
        }

        if (numValues.length == 3) {
          final double q = numValues[0];
          final double u = numValues[1];
          final double t = numValues[2];

          log('ITEM DETECTADO (linhas): $codigo | $descricao | $q $unidade x $u = $t');

          data['produtos'].add({
            'codigo': codigo,
            'descricao': descricao,
            'unidade': unidade,
            'qtde': q,
            'unitario': u,
            'total': t,
          });

          i = j - 1; // Avança o ponteiro principal
        }
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

  static double? _parseDecimalOrNull(String value) {
    if (value.isEmpty) return null;
    // Aceita formatos: "300,73" ou "1.984,82" ou "6,60"
    if (!RegExp(r'^[\d.,]+$').hasMatch(value)) return null;
    String clean = value.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean);
  }

  static List<double>? _breakConcatenatedNumbers(String numStr) {
    String clean = numStr.replaceAll('.', '');
    for (int i = 1; i < clean.length - 1; i++) {
        for (int j = i + 1; j < clean.length; j++) {
            String qStr = clean.substring(0, i);
            String uStr = clean.substring(i, j);
            String tStr = clean.substring(j);

            int tCommaPos = tStr.indexOf(',');
            if (tCommaPos == -1 || tStr.length - tCommaPos - 1 != 2) continue;
            
            if (uStr.isEmpty || uStr == ',') continue;
            int uCommaPos = uStr.indexOf(',');
            if (uCommaPos != -1 && uCommaPos != uStr.lastIndexOf(',')) continue;
            
            if (qStr.isEmpty || qStr == ',') continue;
            int qCommaPos = qStr.indexOf(',');
            if (qCommaPos != -1 && qCommaPos != qStr.lastIndexOf(',')) continue;

            double qVal = double.parse(qStr.replaceAll(',', '.'));
            double uVal = double.parse(uStr.replaceAll(',', '.'));
            double tVal = double.parse(tStr.replaceAll(',', '.'));

            if ((qVal * uVal - tVal).abs() <= 0.05) {
                return [qVal, uVal, tVal];
            }
        }
    }
    return null;
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
