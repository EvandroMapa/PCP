import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
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
                    ),
                  ),
                  const W(12),
                  Expanded(
                    child: AppTextButton(
                      label: 'Importar (${selectedFiles.length})',
                      onPressed: selectedFiles.isEmpty
                          ? null
                          : () {
                              // TODO: Lógica de upload e processamento
                              Navigator.pop(context, selectedFiles);
                            },
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
