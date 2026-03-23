import 'package:flutter/material.dart';

enum ArchiveType { pdf, image, video, other, undefined }

extension ArchiveTypeExtension on ArchiveType {
  String get name {
    switch (this) {
      case ArchiveType.pdf:
        return 'PDF';
      case ArchiveType.image:
        return 'Imagem';
      case ArchiveType.video:
        return 'Vídeo';
      case ArchiveType.other:
        return 'Outros';
      default:
        return 'Desconhecido';
    }
  }

  IconData get icon {
    switch (this) {
      case ArchiveType.pdf:
        return Icons.picture_as_pdf;
      case ArchiveType.image:
        return Icons.image;
      case ArchiveType.video:
        return Icons.video_library;
      case ArchiveType.other:
        return Icons.file_present_rounded;
      default:
        return Icons.error;
    }
  }
}
