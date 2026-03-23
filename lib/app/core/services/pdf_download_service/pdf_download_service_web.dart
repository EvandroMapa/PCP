// import 'dart:convert';
// import 'dart:html' as html;
// import 'dart:typed_data';

// import 'package:pdf/pdf.dart';
// import 'package:printing/printing.dart';

// Future<bool> downloadPDF(String name, String path, Uint8List bytes) async {
//   try {
//     await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
//     // List<int> fileInts = List.from(bytes);
//     // html.AnchorElement(
//     //     href:
//     //         "data:application/octet-stream;charset=utf-16le;base64,${base64.encode(fileInts)}")
//     //   ..setAttribute("download", name)
//     //   ..click();
//     return true;
//   } catch (_) {
//     return false;
//   }
// }
