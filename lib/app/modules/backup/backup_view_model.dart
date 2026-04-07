import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupUtils {
  String restoreTitle = 'Restaurar Backup';
  int restoreLenght = 0;
  int restoreIndex = 0;
}

class BackupModel {
  final String nome;
  final DateTime createdAt;
  late String url;

  BackupModel({required this.nome, required this.createdAt});

  factory BackupModel.fromFileObject(FileObject file) {
    DateTime createdAt;
    try {
      createdAt = DateFormat(
        'dd_MM_yyyy_HH_mm_ss',
      ).parse(file.name.split('.').first.split('backup_').last);
    } catch (_) {
      createdAt = file.createdAt != null ? DateTime.parse(file.createdAt!) : DateTime.now();
    }
    return BackupModel(nome: file.name, createdAt: createdAt);
  }
}
