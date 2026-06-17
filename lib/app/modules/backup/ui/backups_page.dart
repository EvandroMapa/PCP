import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/backup/backup_controller.dart';
import 'package:aco_plus/app/modules/backup/backup_explorer_controller.dart';
import 'package:aco_plus/app/modules/backup/backup_scheduler_service.dart';
import 'package:aco_plus/app/modules/backup/backup_view_model.dart';
import 'package:aco_plus/app/modules/backup/ui/backup_explorer_page.dart';
import 'package:aco_plus/app/modules/backup/ui/backup_schedule_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';

class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key});

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  @override
  void initState() {
    setWebTitle('Backup');
    backupCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Backups',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Configurar agendamento automático',
            onPressed: () => showBackupScheduleDialog(context),
            icon: Icon(Icons.schedule, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Restaurar Backup',
            onPressed: () => backupCtrl.onRestoreBackup(context),
            icon: Icon(Icons.upload, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Criar Backup agora',
            onPressed: () => backupCtrl.onCreateBackup(context),
            icon: Icon(Icons.add, color: AppColors.white),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<BackupModel>>(
        stream: backupCtrl.backupsStream.listen,
        builder: (_, backups) {
          if (backups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.backup_outlined,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum backup encontrado',
                    style:
                        AppCss.mediumRegular.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clique em + para criar o primeiro',
                    style:
                        AppCss.smallRegular.copyWith(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Backups Realizados (${backups.length})',
                  style: AppCss.mediumBold,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: backups.length,
                  separatorBuilder: (_, i) => const Divisor(),
                  itemBuilder: (_, i) => _itemWidget(backups[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemWidget(BackupModel backup) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(Icons.description_outlined, color: AppColors.primaryMain),
      title: Text(backup.nome, style: AppCss.mediumRegular),
      subtitle: Text(
        'Criado em ${DateFormat('dd/MM/yyyy HH:mm').format(backup.createdAt)}',
        style: AppCss.smallRegular.copyWith(color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.manage_search, size: 20),
            onPressed: () => _onExplorar(backup),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.file_download_outlined, size: 20),
            onPressed: () => backupCtrl.onDownloadBackup(backup),
          ),
        ],
      ),
    );
  }

  Future<void> _onExplorar(BackupModel backup) async {
    showLoadingDialog();
    try {
      final bytes = await SupabaseService.client.storage
          .from('backups')
          .download(backup.nome);

      backupExplorerCtrl.carregarJson(bytes);

      if (mounted) Navigator.pop(context); // fecha loading
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BackupExplorerPage(nomeBackup: backup.nome),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // fecha loading
      NotificationService.showNegative(
        'Erro ao carregar backup',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}

