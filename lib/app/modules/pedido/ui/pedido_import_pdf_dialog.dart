import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_arquivo_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

Future<List<PlatformFile>?> showPedidoImportPdfDialog() async {
  return await showDialog<List<PlatformFile>>(
    context: contextGlobal,
    builder: (context) => const PedidoImportPdfDialog(),
  );
}

class PedidoImportPdfDialog extends StatefulWidget {
  const PedidoImportPdfDialog({super.key});

  @override
  State<PedidoImportPdfDialog> createState() => _PedidoImportPdfDialogState();
}

class _PedidoImportPdfDialogState extends State<PedidoImportPdfDialog> {
  List<PlatformFile> selectedFiles = [];
  bool isUploading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true, // Necessário para Web
    );

    if (result != null) {
      setState(() {
        selectedFiles.addAll(result.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadFiles() async {
    if (selectedFiles.isEmpty) return;

    setState(() {
      isUploading = true;
    });

    try {
      for (final file in selectedFiles) {
        if (file.bytes == null) continue;

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final path = 'arquivos/$fileName';

        // Upload binário para o Storage
        await SupabaseService.client.storage.from('pedidos').uploadBinary(
              path,
              file.bytes!,
            );

        // Obter URL pública
        final url = SupabaseService.client.storage.from('pedidos').getPublicUrl(path);

        // Criar modelo de metadados
        final model = PedidoArquivoModel(
          id: '', // Supabase gera
          nome: file.name,
          url: url,
          tamanho: file.size,
          tipo: 'application/pdf',
          extensao: 'pdf',
          criadoEm: DateTime.now(),
          isProcessed: false,
        );

        // Salvar metadados na tabela
        await AppSupabaseClient.pedidoArquivos.add(model);
      }

      if (mounted) {
        Navigator.pop(context, selectedFiles);
        NotificationService.showPositive(
          'Sucesso',
          '${selectedFiles.length} arquivo(s) importado(s) com sucesso. Já estão no banco para uso futuro.',
        );
      }
    } catch (e) {
      print('Erro ao importar PDF: $e');
      if (mounted) {
        NotificationService.showNegative('Erro', 'Falha ao fazer upload do(s) arquivo(s). Verifique se o bucket "pedidos" foi criado no Supabase.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppCss.radius12),
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppCss.radius12,
        ),
        child: Column(
          children: [
            // Header
            Container(
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
                  const Icon(Icons.picture_as_pdf, color: Colors.white),
                  const W(12),
                  Expanded(
                    child: Text(
                      'IMPORTAR PEDIDO (PDF)',
                      style: AppCss.mediumBold.setColor(Colors.white),
                    ),
                  ),
                  if (!isUploading)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drop/Pick Area
                    if (!isUploading)
                      InkWell(
                        onTap: _pickFiles,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primaryMain.withValues(alpha: 0.05),
                            borderRadius: AppCss.radius12,
                            border: Border.all(
                              color: AppColors.primaryMain.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 40, color: AppColors.primaryMain),
                              const H(8),
                              Text(
                                'Clique para selecionar os PDFs',
                                style: AppCss.minimumBold.setColor(AppColors.primaryMain),
                              ),
                              Text(
                                'Selecione um ou mais arquivos de pedido',
                                style: AppCss.minimumRegular.setSize(12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const H(16),

                    // Files List
                    Expanded(
                      child: selectedFiles.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum arquivo selecionado',
                                style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
                              ),
                            )
                          : ListView.separated(
                              itemCount: selectedFiles.length,
                              separatorBuilder: (context, index) => const H(8),
                              itemBuilder: (context, index) {
                                final file = selectedFiles[index];
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.neutralLight),
                                    borderRadius: AppCss.radius8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_drive_file,
                                          color: Colors.red, size: 24),
                                      const W(12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file.name,
                                              style: AppCss.minimumBold,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${(file.size / 1024).toStringAsFixed(1)} KB',
                                              style: AppCss.minimumRegular.setSize(10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isUploading)
                                        IconButton(
                                          onPressed: () => _removeFile(index),
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red, size: 20),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    if (isUploading)
                      const Column(
                        children: [
                          H(16),
                          CircularProgressIndicator(),
                          H(8),
                          Text('Fazendo upload dos arquivos...'),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextButton.outlined(
                      label: 'Cancelar',
                      onPressed: () => Navigator.pop(context),
                      isEnable: !isUploading,
                    ),
                  ),
                  const W(12),
                  Expanded(
                    child: AppTextButton(
                      label: isUploading ? 'Importando...' : 'Importar (${selectedFiles.length})',
                      onPressed: _uploadFiles,
                      isEnable: selectedFiles.isNotEmpty && !isUploading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
