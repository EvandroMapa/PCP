import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:aco_plus/app/core/services/supabase_storage_service.dart';

Future<bool> backupDownload(String name, String path, Uint8List bytes) async {
  await SupabaseStorageService.uploadFile(
    name: name,
    bytes: bytes,
    mimeType: 'application/json',
    path: '',
    bucket: 'backups',
  );
  html.AnchorElement(
      href:
          "data:application/octet-stream;charset=utf-16le;base64,${base64.encode(bytes)}",
    )
    ..setAttribute("download", name)
    ..click();
  return true;
}
