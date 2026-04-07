import 'dart:convert';
import 'dart:html' as html;

import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/backup/backup_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final backupCtrl = BackupController();

class BackupController {
  static final BackupController _instance = BackupController._();
  BackupController._();
  factory BackupController() => _instance;

  static const _bucket = 'backups';

  final AppStream<List<BackupModel>> backupsStream =
      AppStream<List<BackupModel>>();
  List<BackupModel> get backups => backupsStream.value;

  // Stream de progresso para exibir na UI
  final AppStream<String> progressStream = AppStream<String>();

  Future<void> onInit() async {
    await onFetch();
  }

  // ─── LISTAR BACKUPS ──────────────────────────────────────────────────────
  Future<void> onFetch() async {
    try {
      final List<FileObject> items =
          await SupabaseService.client.storage.from(_bucket).list();

      final list = items
          .where((f) => f.name.endsWith('.json'))
          .map((f) => BackupModel.fromFileObject(f))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      backupsStream.add(list);
    } catch (e) {
      print('BackupController.onFetch erro: $e');
      backupsStream.add([]);
    }
  }

  // ─── CRIAR BACKUP ────────────────────────────────────────────────────────
  Future<void> onCreateBackup(BuildContext context) async {
    final tables = [
      'usuarios', 'clientes', 'materia_primas', 'fabricantes', 'produtos',
      'steps', 'step_from_steps', 'step_move_roles', 'tags',
      'pedidos', 'pedido_produtos', 'pedido_status_history',
      'pedido_steps_history', 'pedido_tags',
      'ordens', 'ordem_produtos', 'ordem_status_history',
      'checklists', 'notificacoes', 'automatizacao',
    ];

    // Exibe diálogo de progresso (não modal, com stream)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackupProgressDialog(),
    );

    try {
      final Map<String, dynamic> data = {};

      for (var i = 0; i < tables.length; i++) {
        final table = tables[i];
        progressStream.add(
          '(${i + 1}/${tables.length}) Exportando: $table...',
        );
        try {
          data[table] = await SupabaseService.client.from(table).select();
        } catch (_) {
          data[table] = [];
        }
      }

      progressStream.add('Gerando arquivo JSON...');
      final bytes = utf8.encode(jsonEncode(data));
      final name =
          'backup_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.json';

      progressStream.add('Enviando para o servidor...');
      await SupabaseService.client.storage.from(_bucket).uploadBinary(
            name,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );

      progressStream.add('Preparando download local...');
      final b64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$b64')
        ..setAttribute('download', name)
        ..click();

      pop(contextGlobal); // fecha o progress dialog
      await onFetch();    // atualiza a lista
    } catch (e) {
      pop(contextGlobal); // fecha o progress dialog
      print('BackupController.onCreateBackup erro: $e');
      await showInfoDialog('Erro ao criar backup:\n$e');
    }
  }

  // ─── DOWNLOAD DE UM BACKUP DO SERVIDOR ───────────────────────────────────
  Future<void> onDownloadBackup(BackupModel backup) async {
    try {
      progressStream.add('Baixando ${backup.nome}...');
      final bytes = await SupabaseService.client.storage
          .from(_bucket)
          .download(backup.nome);

      final b64 = base64Encode(bytes);
      html.AnchorElement(href: 'data:application/octet-stream;base64,$b64')
        ..setAttribute('download', backup.nome)
        ..click();
    } catch (e) {
      await showInfoDialog('Erro ao baixar backup:\n$e');
    }
  }

  // ─── RESTAURAR BACKUP ────────────────────────────────────────────────────
  Future<void> onRestoreBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.first.bytes == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackupProgressDialog(),
    );

    try {
      progressStream.add('Lendo arquivo...');
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(result.files.first.bytes!));

      final deleteOrder = [
        'pedido_status_history', 'pedido_steps_history',
        'pedido_produtos', 'pedido_tags',
        'ordem_produtos', 'ordem_status_history',
        'step_from_steps', 'step_move_roles',
        'pedidos', 'ordens', 'notificacoes', 'checklists',
        'produtos', 'materia_primas', 'fabricantes', 'steps', 'tags',
        'clientes', 'usuarios', 'automatizacao',
      ];

      // 2. Deleta (filhos -> pais)
      for (var i = 0; i < deleteOrder.length; i++) {
        final table = deleteOrder[i];
        progressStream.add(
            '(${i + 1}/${deleteOrder.length}) Limpando: $table...');
        try {
          final rows =
              await SupabaseService.client.from(table).select('id');
          final ids = rows.map((r) => r['id']).toList();
          for (var j = 0; j < ids.length; j += 200) {
            final chunk = ids.sublist(j, (j + 200).clamp(0, ids.length));
            await SupabaseService.client
                .from(table)
                .delete()
                .inFilter('id', chunk);
          }
        } catch (_) {}
      }

      // 3. Insere (pais -> filhos)
      final insertOrder = deleteOrder.reversed.toList();
      for (var i = 0; i < insertOrder.length; i++) {
        final table = insertOrder[i];
        final rows =
            (data[table] as List?)?.cast<Map<String, dynamic>>();
        if (rows == null || rows.isEmpty) continue;
        progressStream
            .add('(${i + 1}/${insertOrder.length}) Restaurando: $table...');
        try {
          for (var j = 0; j < rows.length; j += 500) {
            final chunk = rows.sublist(j, (j + 500).clamp(0, rows.length));
            await SupabaseService.client.from(table).upsert(chunk);
          }
        } catch (e) {
          print('Erro ao restaurar $table: $e');
        }
      }

      progressStream.add('Concluído! Recarregando...');
      await Future.delayed(const Duration(seconds: 1));
      html.window.location.reload();
    } catch (e) {
      pop(contextGlobal);
      await showInfoDialog('Erro ao restaurar backup:\n$e');
    }
  }
}

// ─── DIÁLOGO DE PROGRESSO ────────────────────────────────────────────────────
class _BackupProgressDialog extends StatelessWidget {
  const _BackupProgressDialog();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: backupCtrl.progressStream.listen,
      builder: (_, snap) {
        final msg = snap.data ?? 'Iniciando...';
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Processando', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
