void main() {
  String pdfLines = """
ESTEIRAS X 10
Elemento
Ok
140
90 
01
8,00
CA50
50,400
1
OS
Qtde
Compr. (cm)
Posição
Bitola (mm)
Aço
Peso (kg)
VIGAS X 8
Elemento
Ok
32
900 
01
10,00
CA50
181,440
2
480
110 
02
5,00
CA60
84,480
3
""";
  
  List<String> lines = pdfLines.split('\n').map((e) => e.trim()).toList();
  
  for (int i=0; i<lines.length; i++) {
     print('[$i]: ${lines[i]}');
  }

  print('--- PARSING ---');

  for (int i=0; i<lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;
        final lineLower = line.toLowerCase();

        // 1. Detectar Início de Elemento (Vertical)
        if (i + 2 < lines.length && 
            lines[i+1].toLowerCase() == 'elemento' && 
            lines[i+2].toLowerCase() == 'ok') {
          
          print('ELEMENT FOUND: \$line');
          i += 2; // Pula "Elemento" e "Ok"
          continue;
        }

        // Tentar block de 7 linhas (NOVO LAYOUT)
        if (i + 6 < lines.length) {
          final valQtde = lines[i].replaceAll(',', '.');
          final valPos = lines[i+2];
          final valBitolaStr = lines[i+3].replaceAll(',', '.');
          final valAco = lines[i+4].toUpperCase();
          final valPesoStr = lines[i+5].replaceAll(',', '.');
          final valOs = lines[i+6];

          final qtdePos = double.tryParse(valQtde);
          final bitola = double.tryParse(valBitolaStr);
          final peso = double.tryParse(valPesoStr);
          
          if (qtdePos != null && bitola != null && (valAco.contains('CA50') || valAco.contains('CA60'))) {
             print('  POS_FOUND: Qtde=\$qtdePos, Pos=\$valPos, Bitola=\$bitola, Aco=\$valAco, Peso=\$peso, OS=\$valOs');
             i += 6; // pula o bloco
             continue;
          }
        }
  }
}
