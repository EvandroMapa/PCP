import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static const String _bucket = 'pcp-arquivos';

  /// Remove acentos e caracteres especiais do nome do arquivo
  /// para evitar "invalid key" no Supabase Storage.
  /// O nome original é mantido nos metadados do ArchiveModel.
  static String _sanitizeFileName(String name) {
    const from = 'àáâãäåæçèéêëìíîïðñòóôõöùúûüýÿ'
        'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖÙÚÛÜÝ';
    const to   = 'aaaaaaaceeeeiiiidnoooooouuuuyy'
        'AAAAAAACEEEEIIIIDNOOOOOOUUUUY';
    var result = name;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    // Remove qualquer caractere que não seja letra, número, ponto, hífen ou underscore
    result = result.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return result;
  }

  /// Faz upload de um arquivo para o Supabase Storage e retorna a URL pública.
  /// [path] = caminho relativo dentro do bucket, ex: 'pedidos/abc123'
  /// [name] = nome do arquivo (pode ter acentos — será sanitizado automaticamente)
  static Future<String> uploadFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    required String path,
    String bucket = _bucket,
  }) async {
    final safeName = _sanitizeFileName(name);
    final fullPath = '$path/$safeName';
    await SupabaseService.client.storage.from(bucket).uploadBinary(
      fullPath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    return SupabaseService.client.storage.from(bucket).getPublicUrl(fullPath);
  }
}
