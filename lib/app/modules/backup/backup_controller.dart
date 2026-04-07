import 'dart:convert';

import 'dart:html' as html;
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/backup_download_service/backup_download_web.dart'
    if (dart.library.io) 'package:aco_plus/app/core/services/backup_download_service/backup_download_mobile.dart';
import 'package:aco_plus/app/modules/backup/backup_view_model.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

final backupCtrl = BackupController();

class BackupController {
  static final BackupController _instance = BackupController._();

  BackupController._();

  factory BackupController() => _instance;

  final AppStream<List<BackupModel>> backupsStream =
      AppStream<List<BackupModel>>();
  List<BackupModel> get backups => backupsStream.value;
  final AppStream<BackupUtils> utilsStream = AppStream<BackupUtils>();
  BackupUtils get utils => utilsStream.value;

  Future<void> onInit() async {
    onFetch();
  }

  Future<void> onFetch() async {
    final backups = <BackupModel>[];
    try {
      final items = await SupabaseService.client.storage.from('backups').list();
      for (var file in items) {
        if (!file.name.endsWith('.json')) continue;
        final backup = BackupModel.fromFileObject(file);
        backup.url = SupabaseService.client.storage.from('backups').getPublicUrl(file.name);
        backups.add(backup);
      }
      // Ordena por decrescente (mais novo primeiro)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {}
    backupsStream.add(backups);
  }

  Future<void> onCreateBackup() async {
    Map<String, List<dynamic>> backup = {};
    
    // Lista completa de todas as tabelas em ordem de abstração
    final tables = [
      'usuarios', 'clientes', 'materia_primas', 'fabricantes', 'produtos',
      'steps', 'step_from_steps', 'step_move_roles', 'tags',
      'pedidos', 'pedido_produtos', 'pedido_status_history', 'pedido_steps_history', 'pedido_tags',
      'ordens', 'ordem_produtos', 'ordem_status_history',
      'checklists', 'notificacoes', 'automatizacao'
    ];

    for (final table in tables) {
      try {
        final data = await SupabaseService.client.from(table).select();
        backup[table] = data as List<dynamic>;
      } catch (e) {
        print('Erro ao exportar tabela \$table: \$e');
        backup[table] = []; // fallback vazio em caso de erro/inexistência momentânea
      }
    }

    final bytes = utf8.encode(json.encode(backup));
    final name = 'backup_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.json';
    
    await backupDownload(name, 'backups', bytes);
    await onInit();
  }

  Future<void> onRestoreBackup() async {
    final file = await FilePicker.platform.pickFiles();
    if (file == null) return;

    Map<String, dynamic> backup;
    try {
      backup = json.decode(utf8.decode(file.files.first.bytes!));
    } catch (_) {
      print('Erro ao ler .json');
      return;
    }

    // 1. Ordem de Deleção (Filhos -> Pais)
    final cascadeOrder = [
      'pedido_status_history', 'pedido_steps_history', 'pedido_produtos', 'pedido_tags',
      'ordem_produtos', 'ordem_status_history',
      'step_from_steps', 'step_move_roles',
      'pedidos', 'ordens', 'notificacoes', 'checklists',
      'produtos', 'materia_primas', 'fabricantes', 'steps', 'tags',
      'clientes', 'usuarios', 'automatizacao'
    ];

    print('Iniciando deleção massiva remota...');
    for (final table in cascadeOrder) {
      if (!backup.containsKey(table)) continue;
      try {
        // Tenta excluir todos os registros baseando-se em uma lógica de varredura
        final allCurrent = await SupabaseService.client.from(table).select();
        // Agrupa deleções por ID quando possível para evitar timeout de request
        final ids = allCurrent.where((e) => e.containsKey('id')).map((e) => e['id']).toList();
        if (ids.isNotEmpty) {
           // Delete in chunks of 200
           for (var i = 0; i < ids.length; i += 200) {
             final chunk = ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200);
             await SupabaseService.client.from(table).delete().inFilter('id', chunk);
           }
        } else {
           // Tabelas relacionais sem ID (ex: pedido_tags)
           // Exclui individualmente (ineficiente, mas necessário via REST sem PK simples)
           for (var item in allCurrent) {
              var q = SupabaseService.client.from(table).delete();
              item.forEach((k, v) => q = q.eq(k, v));
              await q;
           }
        }
      } catch (e) {
        print('Erro ao limpar \$table: \$e');
      }
    }

    print('Iniciando restauração e inserções...');
    // 2. Ordem de Inserção (Pais -> Filhos)
    final insertOrder = cascadeOrder.reversed.toList();

    for (final table in insertOrder) {
      if (!backup.containsKey(table)) continue;
      final dataList = backup[table] as List<dynamic>;
      if (dataList.isEmpty) continue;
      
      try {
        final payloads = dataList.cast<Map<String, dynamic>>();
        // Inserir em chunks de 1000
        for (var i = 0; i < payloads.length; i += 1000) {
          final chunk = payloads.sublist(i, i + 1000 > payloads.length ? payloads.length : i + 1000);
          await SupabaseService.client.from(table).upsert(chunk);
        }
      } catch (e) {
        print('Erro ao inserir em \$table: \$e');
      }
    }
    
    print('Backup restaurado com sucesso. Realocando local memory cache...');
    html.window.location.reload();
  }
}
