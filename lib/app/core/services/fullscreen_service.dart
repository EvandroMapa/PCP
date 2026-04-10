import 'package:web/web.dart' as web;

class FullscreenService {
  static bool get isFullscreen => web.document.fullscreenElement != null;

  static void toggle() {
    if (isFullscreen) {
      web.document.exitFullscreen();
    } else {
      web.document.documentElement?.requestFullscreen();
    }
  }

  static void enter() {
    if (!isFullscreen) {
      web.document.documentElement?.requestFullscreen();
    }
  }

  static void exit() {
    if (isFullscreen) {
      web.document.exitFullscreen();
    }
  }
}
