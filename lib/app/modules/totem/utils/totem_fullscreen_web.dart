import 'package:web/web.dart' as web;

/// Implementação web usando Fullscreen API do browser.
void entrarFullscreenWeb() {
  try {
    web.document.documentElement?.requestFullscreen();
  } catch (_) {}
}

void sairFullscreenWeb() {
  try {
    web.document.exitFullscreen();
  } catch (_) {}
}
