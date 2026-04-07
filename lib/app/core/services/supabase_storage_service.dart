import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static const String _bucket = 'pcp-arquivos';

  /// Faz upload de um arquivo para o Supabase Storage e retorna a URL pública.
  /// [path] = caminho relativo dentro do bucket, ex: 'pedidos/abc123'
  /// [name] = nome do arquivo, ex: 'relatorio.pdf'
  static Future<String> uploadFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    required String path,
    String bucket = _bucket,
  }) async {
    final fullPath = path.isEmpty ? name : '$path/$name';
    await SupabaseService.client.storage.from(bucket).uploadBinary(
      fullPath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    return SupabaseService.client.storage.from(bucket).getPublicUrl(fullPath);
  }
}
