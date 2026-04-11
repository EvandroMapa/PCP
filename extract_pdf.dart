import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final file = File(r'D:\DESENVOLVIMENTO\PDF IMPORT\elementos ALA.pdf');
  final bytes = await file.readAsBytes();
  final document = PdfDocument(inputBytes: bytes);
  final text = PdfTextExtractor(document).extractText();
  document.dispose();
  
  await File('pdf_output.txt').writeAsString(text);
  print('Extraction done!');
}
