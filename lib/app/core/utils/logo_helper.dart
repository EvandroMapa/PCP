import 'dart:typed_data';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Centraliza o acesso à logo do sistema.
/// Se houver uma logo customizada (URL do Supabase), usa ela.
/// Caso contrário, faz fallback para `assets/images/logo.png`.
class LogoHelper {
  static String? get _customUrl {
    final url = PreferencesService.logoUrl.value;
    return (url.isNotEmpty) ? url : null;
  }

  /// Widget de logo para uso em telas (login, splash, drawer, etc).
  static Widget logoWidget({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final url = _customUrl;
    if (url != null) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/logo.png',
          width: width,
          height: height,
          fit: fit,
        ),
      );
    }
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Retorna os bytes da logo para uso em PDFs (pw.MemoryImage).
  static Future<Uint8List> logoBytesForPdf() async {
    final url = _customUrl;
    if (url != null) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (_) {
        // fallback
      }
    }
    final data = await rootBundle.load('assets/images/logo.png');
    return data.buffer.asUint8List();
  }
}
