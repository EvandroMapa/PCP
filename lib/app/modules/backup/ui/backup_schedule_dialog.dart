import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/backup/backup_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showBackupScheduleDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const BackupScheduleDialog(),
  );
}

class BackupScheduleDialog extends StatefulWidget {
  const BackupScheduleDialog({super.key});

  @override
  State<BackupScheduleDialog> createState() => _BackupScheduleDialogState();
}

class _BackupScheduleDialogState extends State<BackupScheduleDialog> {
  BackupScheduleConfig? _config;
  bool _loading = true;

  final _diasNomes = {
    1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await BackupScheduleConfig.load();
    setState(() {
      _config = cfg;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _config!.save();
    await BackupSchedulerService().reload();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _config!.hora, minute: _config!.minuto),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _config!.hora = picked.hour;
        _config!.minuto = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _config == null) {
      return const AlertDialog(
        content: Center(child: CircularProgressIndicator()),
      );
    }

    final proximo = _config!.proximoBackup;

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.primaryMain),
          const SizedBox(width: 8),
          Text('Backup Automático', style: AppCss.largeBold),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle ativo
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Agendamento ativo', style: AppCss.mediumBold),
              subtitle: Text(
                _config!.enabled
                    ? 'Backup automático habilitado'
                    : 'Backup automático desabilitado',
                style: AppCss.smallRegular
                    .copyWith(color: _config!.enabled ? Colors.green : Colors.grey),
              ),
              value: _config!.enabled,
              activeColor: AppColors.primaryMain,
              onChanged: (v) => setState(() => _config!.enabled = v),
            ),

            const Divider(),

            // Dias da semana
            Text('Dias da semana', style: AppCss.mediumBold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _diasNomes.entries.map((e) {
                final selected = _config!.dias.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  selectedColor: AppColors.primaryMain.withOpacity(0.15),
                  checkmarkColor: AppColors.primaryMain,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primaryMain : Colors.grey[600],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _config!.dias.remove(e.key);
                      } else {
                        _config!.dias.add(e.key);
                        _config!.dias.sort();
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Horário
            Text('Horário', style: AppCss.mediumBold),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: AppColors.primaryMain, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_config!.hora.toString().padLeft(2, '0')}:${_config!.minuto.toString().padLeft(2, '0')}',
                      style: AppCss.largeBold.setColor(AppColors.primaryMain),
                    ),
                    const SizedBox(width: 8),
                    Text('(clique para alterar)', style: AppCss.smallRegular.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            // Próximo backup
            if (proximo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Próximo backup: ${DateFormat('EEE, dd/MM/yyyy \'às\' HH:mm', 'pt_BR').format(proximo)}',
                        style: AppCss.smallRegular.copyWith(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_config!.ultimoBackup != null) ...[
              const SizedBox(height: 8),
              Text(
                'Último backup automático: ${DateFormat('dd/MM/yyyy HH:mm').format(_config!.ultimoBackup!)}',
                style: AppCss.smallRegular.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
