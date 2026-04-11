import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('extract pdf', () async {
    final file = File(r'D:\DESENVOLVIMENTO\PDF IMPORT\elementos2.pdf');
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    
    await File('pdf_output2.txt').writeAsString(text);
    print('Extraction 2 done!');
  });
}
