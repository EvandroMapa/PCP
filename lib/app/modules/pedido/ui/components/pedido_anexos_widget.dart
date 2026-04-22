import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/components/archive/ui/archives_grid_widget.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:flutter/material.dart';

class PedidoAnexosWidget extends StatelessWidget {
  final PedidoModel pedido;
  const PedidoAnexosWidget(this.pedido, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!pedido.isParcial) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _gridProprios(),
      );
    }

    // Pedido Parcial: dois blocos empilhados
    // BackendClient busca em ativos E arquivados — necessário quando o mestre foi arquivado
    final mestre = BackendClient.pedidos.getById(pedido.pai!);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _gridProprios(),
          if (!mestre.localizador.startsWith('NOTFOUND')) ...[
            const SizedBox(height: 16),
            _AnexosMestreBox(mestre: mestre),
          ],
        ],
      ),
    );
  }

  Widget _gridProprios() {
    return ArchivesGridWidget(
      path: 'pedidos/${pedido.id}',
      archives: pedido.archives,
      onChanged: pedidoCtrl.onArquivosChanged,
    );
  }
}

/// Bloco somente-leitura com os anexos do Pedido Mestre.
class _AnexosMestreBox extends StatelessWidget {
  final PedidoModel mestre;
  const _AnexosMestreBox({required this.mestre});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF59E0B), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_special_outlined,
                      size: 16, color: Color(0xFF92400E)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arquivos do Pedido Mestre',
                        style: AppCss.mediumBold.copyWith(
                          fontSize: 13,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        mestre.localizador,
                        style: AppCss.minimumRegular.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF92400E).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mestre.archives.length} arquivo${mestre.archives.length == 1 ? '' : 's'}',
                    style: AppCss.minimumBold.copyWith(
                      fontSize: 11,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Grid somente leitura ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: mestre.archives.isEmpty
                ? Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: AppColors.neutralDark.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(
                        'O pedido mestre não possui arquivos.',
                        style: AppCss.minimumRegular.copyWith(
                          fontSize: 12,
                          color: AppColors.neutralDark.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : ArchivesGridWidget(
                    archives: mestre.archives,
                    // sem onChanged → somente leitura (sem botão excluir/adicionar)
                  ),
          ),
        ],
      ),
    );
  }
}
