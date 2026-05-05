import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

// Importação condicional: web só carrega no browser
import 'package:aco_plus/app/modules/totem/utils/totem_fullscreen_stub.dart'
    if (dart.library.html) 'package:aco_plus/app/modules/totem/utils/totem_fullscreen_web.dart'
    as platform;

/// Helper multiplataforma para controlar tela cheia do totem.
/// - Web: usa Fullscreen API do browser
/// - Android: usa SystemChrome (modo imersivo)
class TotemFullscreen {
  static void entrar() {
    if (kIsWeb) {
      platform.entrarFullscreenWeb();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  static void sair() {
    if (kIsWeb) {
      platform.sairFullscreenWeb();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}
