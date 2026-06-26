import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abre o dialog de importação TQS (CSV) para o pedido informado.
Future<bool> showTqsImportarDialog(PedidoModel pedido) async {
  final resultado = await showDialog<bool>(
    context: contextGlobal,
    barrierDismissible: false,
    builder: (context) => TqsImportarDialog(pedido: pedido),
  );
  return resultado == true;
}

class TqsImportarDialog extends StatefulWidget {
  final PedidoModel pedido;
  const TqsImportarDialog({super.key, required this.pedido});

  @override
  State<TqsImportarDialog> createState() => _TqsImportarDialogState();
}

class _TqsImportarDialogState extends State<TqsImportarDialog> {
  bool _importando = false;

  Future<void> _selecionarArquivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.bytes == null) return;
    if (!mounted) return;

    // Verificar se já existem elementos e perguntar o que fazer
    bool clearExisting = false;

    // Inicializa o controller de elementos se necessário
    await elementoCtrl.onInit(widget.pedido.id);

    if (elementoCtrl.elementos.isNotEmpty) {
      final canClearAll = elementoCtrl.elementos
          .every((e) => e.status == ElementoStatus.aguardando);

      final String? choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Elementos Existentes'),
          content: Text(canClearAll
              ? 'Já existem elementos cadastrados neste pedido. O que deseja fazer com a lista atual?'
              : 'Já existem elementos cadastrados neste pedido. Como alguns já estão em produção, você apenas pode acrescentar os novos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'append'),
              child: const Text('Acrescentar Novos'),
            ),
            if (canClearAll)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, 'clear'),
                child: const Text('Apagar Tudo e Importar'),
              ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;
      clearExisting = (choice == 'clear');
    }

    if (!mounted) return;
    setState(() => _importando = true);

    elementoCtrl.importProgressStream.add(
      ImportProgress(status: 'Lendo dados do CSV...'),
    );

    await Future.delayed(const Duration(milliseconds: 100));

    final res = await elementoCtrl.onImportCSV(
        result.files.single.bytes!, widget.pedido, clearExisting);

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context, true);
      NotificationService.showPositive(
        'Importação Concluída',
        '${res['elementsFound']} elementos importados via CSV',
      );
    } else {
      setState(() => _importando = false);

      // Se for apenas cancelamento, não mostra erro
      if (res['error'] == 'Operação cancelada.' ||
          res['error'] == 'Importação cancelada pelo usuário.') {
        return;
      }

      _mostrarErroCSV(res);
    }
  }

  void _mostrarErroCSV(Map<String, dynamic> res) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.info_outline_rounded,
                        color: AppColors.secondary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ajuste na Planilha', style: AppCss.largeBold),
                        Text('O formato do CSV precisa de correção',
                            style: AppCss.mediumRegular
                                .copyWith(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Mensagem de Erro
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200, width: 1),
                ),
                child: Text(
                  (res['error'] ?? '').toString().replaceAll('Erro: ', ''),
                  style: AppCss.mediumRegular
                      .copyWith(color: Colors.grey[800], height: 1.5),
                ),
              ),
              // Texto Bruto Lido
              if (res['rawText'] != null &&
                  res['rawText'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('O que o sistema leu do seu arquivo:',
                        style: AppCss.mediumBold
                            .copyWith(color: Colors.grey[800])),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: res['rawText']));
                        NotificationService.showPositive('Copiado',
                            'Texto copiado para a área de transferência');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar Leitura'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      res['rawText'],
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDI, VOU ARRUMAR A PLANILHA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppCss.radius12),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: AppCss.radius12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_importando)
              _buildProgresso()
            else
              _buildConteudo(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_chart_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            'IMPORTAR CSV — TQS',
            style: AppCss.smallBold.setSize(14).setColor(Colors.white),
          ),
          const Spacer(),
          if (!_importando)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  // ── Conteúdo principal (selecionar arquivo) ───────────────────────────────
  Widget _buildConteudo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone decorativo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              size: 40,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Selecione o arquivo CSV',
            style: AppCss.mediumBold.setColor(AppColors.black),
          ),
          const SizedBox(height: 8),

          Text(
            'Escolha a planilha CSV com os elementos e posições '
            'para importar automaticamente neste pedido.',
            textAlign: TextAlign.center,
            style: AppCss.minimumRegular
                .setColor(AppColors.neutralMedium)
                .setSize(13),
          ),
          const SizedBox(height: 24),

          // Botão selecionar arquivo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selecionarArquivo,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Selecionar Arquivo CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info do formato
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Colunas obrigatórias: ELEMENTO, POSICAO, BITOLA, PESO',
                    style: AppCss.minimumRegular
                        .setColor(Colors.grey[600]!)
                        .setSize(11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progresso da importação ────────────────────────────────────────────────
  Widget _buildProgresso() {
    return StreamOut<ImportProgress?>(
      stream: elementoCtrl.importProgressStream.listen,
      builder: (_, progress) {
        final p = progress;
        final isCancelling = p?.isCancelling ?? false;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCancelling) ...[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_upload_rounded,
                      color: AppColors.secondary, size: 32),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                p?.status ?? 'Iniciando importação...',
                style: isCancelling
                    ? AppCss.mediumBold.copyWith(color: Colors.red)
                    : AppCss.mediumBold,
                textAlign: TextAlign.center,
              ),
              if (!isCancelling && p != null && p.total > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: p.percent,
                    minHeight: 8,
                    backgroundColor:
                        AppColors.secondary.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(p.percent * 100).toInt()}% concluído',
                  style: AppCss.minimumRegular
                      .copyWith(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: isCancelling
                      ? null
                      : () {
                          elementoCtrl.cancelImport();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isCancelling ? 'Cancelando...' : 'Cancelar Importação',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCancelling ? Colors.grey : Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
