import 'dart:io';

void main() {
  final rawText = File('LMEMP001 novo.csv').readAsStringSync();
  final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  
  final headerLine = lines.first.split(';').map((e) => e.trim().toUpperCase()).toList();
  print('=== HEADER (${headerLine.length} colunas) ===');
  for (int i = 0; i < headerLine.length; i++) {
    print('  [$i] ${headerLine[i]}');
  }

  final Map<String, int> headerIndex = {};
  for (int i = 0; i < headerLine.length; i++) {
    headerIndex[headerLine[i]] = i;
  }

  int getIndex(List<String> possibleNames) {
    for (String name in possibleNames) {
      if (headerIndex.containsKey(name)) return headerIndex[name]!;
      final match = headerIndex.keys.where((k) => k.contains(name)).firstOrNull;
      if (match != null) return headerIndex[match]!;
    }
    return -1;
  }

  final idxElemento = getIndex(['ELEMENTO']);
  final idxIdElem = getIndex(['ID ELEM', 'ID_ELEM', 'IDELEM']);
  final idxQtdeElementos = getIndex(['QTDE ELEM', 'QTDE_ELEMENTOS', 'QTDE ELEMENTOS']);
  final idxOs = getIndex(['OS', 'O.S.', 'O.S']);
  final idxPosicao = getIndex(['POSICAO', 'POSIÇÃO', 'POS.']);
  final idxBitola = getIndex(['BITOLA', 'DIAMETRO']);
  final idxPeso = getIndex(['PESO (KG)', 'PESO']);
  final idxQtde = getIndex(['QTDE', 'QUANTIDADE', 'QTD']);
  final idxComprUnit = getIndex(['COMPR. UNIT', 'COMPR UNIT', 'COMPRIMENTO UNIT']);
  final idxComprCorte = getIndex(['COMPR. CORTE', 'COMPR CORTE', 'COMPRIMENTO CORTE', 'COMPR.CORTE']);

  print('\n=== ÍNDICES ===');
  print('ELEMENTO=$idxElemento, ID_ELEM=$idxIdElem, QTDE_ELEM=$idxQtdeElementos');
  print('OS=$idxOs, POSICAO=$idxPosicao, BITOLA=$idxBitola, PESO=$idxPeso');
  print('QTDE=$idxQtde, COMPR_UNIT=$idxComprUnit, COMPR_CORTE=$idxComprCorte');

  print('\n=== LINHAS DE DADOS ===');
  String currentIdElem = '';
  for (int i = 1; i < lines.length; i++) {
    final columns = lines[i].split(';');
    final elNome = columns[idxElemento].trim();
    final idElem = idxIdElem != -1 && columns.length > idxIdElem ? columns[idxIdElem].trim() : '';
    final osNumber = idxOs != -1 && columns.length > idxOs ? columns[idxOs].trim() : '';
    final posNome = columns[idxPosicao].trim();
    final bitolaStr = columns[idxBitola].trim().replaceAll('mm', '').replaceAll(',', '.');
    final pesoStr = idxPeso != -1 && columns.length > idxPeso ? columns[idxPeso].trim().replaceAll(',', '.') : '0';
    final posQtdeStr = idxQtde != -1 && columns.length > idxQtde ? columns[idxQtde].trim() : '0';
    final comprCorteStr = idxComprCorte != -1 && columns.length > idxComprCorte ? columns[idxComprCorte].trim().replaceAll(',', '.') : '0';
    final comprUnitStr = idxComprUnit != -1 && columns.length > idxComprUnit ? columns[idxComprUnit].trim().replaceAll(',', '.') : '0';
    
    final bitola = double.tryParse(bitolaStr);
    final pesoLido = double.tryParse(pesoStr);

    final isNewElement = currentIdElem != idElem;
    currentIdElem = idElem;

    print('Linha $i: ID=$idElem ${isNewElement ? "(NOVO)" : "(MESMO)"} | Elem=$elNome | Pos=$posNome | OS=$osNumber | Bitola=$bitola | Peso=$pesoLido | Qtde=$posQtdeStr | CUnit=$comprUnitStr | CCorte=$comprCorteStr');
    
    // Simular isValid
    final nomeOk = posNome.isNotEmpty;
    final osOk = osNumber.isNotEmpty;
    final produtoOk = bitola != null; // simplificação
    final pesoOk = (pesoLido ?? 0) > 0;
    print('  isValid: nome=$nomeOk, os=$osOk, produto=$produtoOk, peso=$pesoOk => ${nomeOk && osOk && produtoOk && pesoOk}');

    // Simular detecção de variação
    final varCorteMatch = RegExp(r'(\d+(?:\.\d+)?)\s*var\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(comprCorteStr);
    final qtyLower = posQtdeStr.toLowerCase();
    int steps = 1;
    int multiplier = 1;
    if (qtyLower.contains('x')) {
      final parts = qtyLower.split('x');
      steps = int.tryParse(parts[0].trim()) ?? 1;
      multiplier = int.tryParse(parts[1].trim()) ?? 1;
    } else {
      steps = int.tryParse(qtyLower) ?? 1;
      if (steps == 0) steps = 1;
    }
    final temVariacao = varCorteMatch != null && steps > 1;
    final totalQtde = qtyLower.contains('x') ? multiplier * steps : steps;
    print('  Variação: $temVariacao | Steps=$steps | Mult=$multiplier | TotalQtde=$totalQtde | Medidas=${temVariacao ? steps : 0}');
  }
}
