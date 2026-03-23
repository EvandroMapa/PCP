import 'package:aco_plus/app/core/services/download_file_url_service/download_file_url_web.dart'
    if (dart.library.io) 'package:aco_plus/app/core/services/download_file_url_service/download_file_url_mobile.dart';

class DownloadFileURLService {
  static void call(String url) => onDownloadFileURL(url);
}
