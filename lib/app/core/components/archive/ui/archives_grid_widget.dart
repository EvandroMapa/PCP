import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/components/archive/archive_type.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_add_bottom.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_type_widgets/archive_image_widget.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_type_widgets/archive_other_widget.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_type_widgets/archive_pdf_widget.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_type_widgets/archive_video_widget.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/services/download_file_url_service/download_file_url_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

/// Grid de anexos em 3 colunas.
/// Cada card mostra o thumbnail/ícone e a legenda abaixo.
/// Quando [onChanged] é null, o widget é somente leitura (sem botão de excluir / adicionar).
class ArchivesGridWidget extends StatelessWidget {
  final String? path;
  final List<ArchiveModel> archives;
  final void Function(List<ArchiveModel>)? onChanged;

  const ArchivesGridWidget({
    super.key,
    required this.archives,
    this.path,
    this.onChanged,
  });

  bool get _readOnly => onChanged == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho com botão "+" ──────────────────────────────────────
        if (!_readOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Arquivos', style: AppCss.largeBold),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _onAdd(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),

        // ── Estado vazio ─────────────────────────────────────────────────
        if (archives.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhum arquivo adicionado',
              style: AppCss.minimumRegular.copyWith(
                fontSize: 12,
                color: AppColors.neutralDark.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // ── Grid 3 colunas ───────────────────────────────────────────────
        if (archives.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: archives
                .map((archive) => _ArchiveGridCard(
                      archive: archive,
                      readOnly: _readOnly,
                      onDelete: _readOnly
                          ? null
                          : () => _onDelete(archive),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _onAdd() async {
    if (path == null) return;
    final archive = await showArchiveAddBottom(path!);
    if (archive == null) return;
    final nova = List<ArchiveModel>.from(archives)..add(archive);
    onChanged?.call(nova);
  }

  Future<void> _onDelete(ArchiveModel archive) async {
    if (!await showConfirmDialog(
      'Deseja excluir anexo?',
      'Anexo não estará mais disponível',
    )) return;
    final nova = List<ArchiveModel>.from(archives)..remove(archive);
    onChanged?.call(nova);
  }
}

// ── Card individual do grid ───────────────────────────────────────────────────

class _ArchiveGridCard extends StatefulWidget {
  final ArchiveModel archive;
  final bool readOnly;
  final VoidCallback? onDelete;

  const _ArchiveGridCard({
    required this.archive,
    required this.readOnly,
    this.onDelete,
  });

  @override
  State<_ArchiveGridCard> createState() => _ArchiveGridCardState();
}

class _ArchiveGridCardState extends State<_ArchiveGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Largura fixa de cada card — 3 por linha em telas médias
    const double cardW = 110;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: cardW,
        child: InkWell(
          onTap: () {
            if (widget.archive.url != null) {
              DownloadFileURLService.call(widget.archive.url!);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──────────────────────────────────────────────
              Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: cardW,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hovered
                            ? AppColors.primaryMain.withValues(alpha: 0.4)
                            : Colors.grey.shade300,
                        width: _hovered ? 1.5 : 1,
                      ),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: AppColors.primaryMain
                                    .withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: _buildThumb(),
                    ),
                  ),
                  // Botão excluir (só quando não é read-only e está com hover)
                  if (!widget.readOnly && _hovered && widget.onDelete != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.delete_outline,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  // Ícone de link (para qualquer arquivo clicável)
                  if (_hovered)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.open_in_new,
                            size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),

              // ── Legenda ───────────────────────────────────────────────
              const SizedBox(height: 5),
              Text(
                (widget.archive.description?.isNotEmpty == true
                        ? widget.archive.description!
                        : widget.archive.name) ??
                    '',
                style: AppCss.minimumRegular.copyWith(
                  fontSize: 10,
                  color: const Color(0xFF374151),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    switch (widget.archive.type) {
      case ArchiveType.image:
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: ArchiveImageWidget(widget.archive),
        );
      case ArchiveType.video:
        return ArchiveVideoWidget(widget.archive);
      case ArchiveType.pdf:
        return ArchivePDFWidget(widget.archive, inList: false);
      default:
        return ArchiveOtherWidget(widget.archive);
    }
  }
}
