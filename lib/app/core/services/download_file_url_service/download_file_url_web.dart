import 'dart:js' as js;

void onDownloadFileURL(String url) {
  js.context.callMethod('open', [url]);
}
