import 'package:web/web.dart' as web;

class FullscreenService {
  static bool get isFullscreen => web.document.fullscreenElement != null;

  static void toggle() {
    try {
      if (isFullscreen) {
        web.document.exitFullscreen();
      } else {
        web.document.documentElement?.requestFullscreen();
      }
    } catch (_) {}
  }

  static void enter() {
    try {
      if (!isFullscreen) {
        web.document.documentElement?.requestFullscreen();
      }
    } catch (_) {}
  }

  static void exit() {
    try {
      if (isFullscreen) {
        web.document.exitFullscreen();
      }
    } catch (_) {}
  }
}
