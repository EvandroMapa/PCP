import 'dart:convert';
import 'dart:html' as html;

import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/backup/backup_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final backupCtrl = BackupController();

class BackupController {
  static final BackupController _instance = BackupController._();
  BackupController._();
  factory BackupController() => _instance;

  static const _bucket = 'backups';

  final AppStream<List<BackupModel>> backupsStream = AppStream<List<BackupModel>>();
  List<BackupModel> get backups => backupsStream.value;
  final AppStream<BackupUtils> utilsStream = AppStream<BackupUtils>();
  BackupUtils get utils => utilsStream.value;

  Future<void> onInit() async {
    await onFetch();
  }

  // ─── LISTAR BACKUPS ──────────────────────────────────────────────────────
  Future<void> onFetch() async {
    try {
      // Lista arquivos na RAIZ do bucket (sem pasta intermediária)
      final List<FileObject> items = await SupabaseService.client.storage
          .from(_bucket)
          .list();

      final backups = items
          .where((f) => f.name.endsWith('.json'))
          .map((f) => BackupModel.fromFileObject(f))
          .toList();

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      backupsStream.add(backups);
    } catch (e) {
      print('BackupController.onFetch erro: $e');
      backupsStream.add([]);
    }
  }

  // ─── CRIAR BACKUP ────────────────────────────────────────────────────────
  Future<void> onCreateBackup() async {
    showLoadingDialog();
    try {
      // 1. Extrai todas as tabelas
      final tables = [
        'usuarios', 'clientes', 'materia_primas', 'fabricantes', 'produtos',
        'steps', 'step_from_steps', 'step_move_roles', 'tags',
        'pedidos', 'pedido_produtos', 'pedido_status_history',
        'pedido_steps_history', 'pedido_tags',
        'ordens', 'ordem_produtos', 'ordem_status_history',
        'checklists', 'notificacoes', 'automatizacao',
      ];

      final Map<String, dynamic> data = {};
      for (final table in tables) {
        try {
          data[table] = await SupabaseService.client.from(table).select();
        } catch (e) {
          data[table] = [];
        }
      }

      // 2. Gera o arquivo JSON
      final bytes = utf8.encode(jsonEncode(data));
      final name = 'backup_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.json';

      // 3. Faz upload no Supabase Storage na RAIZ do bucket
      await SupabaseService.client.storage.from(_bucket).uploadBinary(
        name,                  // apenas o nome, sem barra nem pasta
        bytes,
        fileOptions: const FileOptions(contentType: 'application/json', upsert: true),
      );

      // 4. Dispara o download local no navegador
      final base64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$base64')
        ..setAttribute('download', name)
        ..click();

      // 5. Atualiza a lista
      await onFetch();
    } catch (e) {
      print('BackupController.onCreateBackup erro: $e');
      showInfoDialog('Erro ao criar backup: $e');
    } finally {
      pop(contextGlobal);
    }
  }

  // ─── URL PARA DOWNLOAD DE UM BACKUP ──────────────────────────────────────
  Future<void> onDownloadBackup(BackupModel backup) async {
    try {
      // Baixa os bytes diretamente do Storage
      final bytes = await SupabaseService.client.storage
          .from(_bucket)
          .download(backup.nome);

      final base64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$base64')
        ..setAttribute('download', backup.nome)
        ..click();
    } catch (e) {
      showInfoDialog('Erro ao baixar backup: $e');
    }
  }

  // ─── RESTAURAR BACKUP ────────────────────────────────────────────────────
  Future<void> onRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.first.bytes == null) return;

    showLoadingDialog();
    try {
      // 1. Lê o arquivo
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(result.files.first.bytes!));

      // 2. Deleta na ordem inversa (filhos -> pais)
      final deleteOrder = [
        'pedido_status_history', 'pedido_steps_history',
        'pedido_produtos', 'pedido_tags',
        'ordem_produtos', 'ordem_status_history',
        'step_from_steps', 'step_move_roles',
        'pedidos', 'ordens', 'notificacoes', 'checklists',
        'produtos', 'materia_primas', 'fabricantes', 'steps', 'tags',
        'clientes', 'usuarios', 'automatizacao',
      ];

      for (final table in deleteOrder) {
        try {
          final rows = await SupabaseService.client.from(table).select('id');
          final ids = rows.map((r) => r['id']).toList();
          // Deleta em lotes de 200
          for (var i = 0; i < ids.length; i += 200) {
            final chunk = ids.sublist(i, (i + 200).clamp(0, ids.length));
            await SupabaseService.client.from(table).delete().inFilter('id', chunk);
          }
        } catch (_) {}
      }

      // 3. Insere na ordem correta (pais -> filhos)
      final insertOrder = deleteOrder.reversed.toList();
      for (final table in insertOrder) {
        final rows = (data[table] as List?)?.cast<Map<String, dynamic>>();
        if (rows == null || rows.isEmpty) continue;
        try {
          for (var i = 0; i < rows.length; i += 500) {
            final chunk = rows.sublist(i, (i + 500).clamp(0, rows.length));
            await SupabaseService.client.from(table).upsert(chunk);
          }
        } catch (e) {
          print('Erro ao restaurar tabela $table: $e');
        }
      }

      // 4. Reload
      html.window.location.reload();
    } catch (e) {
      print('BackupController.onRestoreBackup erro: $e');
      showInfoDialog('Erro ao restaurar backup: $e');
    } finally {
      pop(contextGlobal);
    }
  }
}
