import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/modulo_importacao/ui/spe/spe_importar_dialog.dart';
import 'package:aco_plus/app/modules/modulo_importacao/ui/tqs/tqs_importar_dialog.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_create_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PedidoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final PedidoModel pedido;
  final PedidoInitReason reason;
  final Function()? onDelete;

  const PedidoTopBar({
    required this.pedido,
    required this.reason,
    this.onDelete,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return reason == PedidoInitReason.kanban
        ? _kanbanWidget(context)
        : _pedidoWidget(context);
  }

  // ── Helper: botão de ação padronizado 36×36 ──────────────────────────────
  Widget _botaoAcao({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? corIcone,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: corIcone ?? AppColors.white, size: 20),
        ),
      ),
    );
  }

  // ── Título com badges MESTRE / PARCIAL ───────────────────────────────────
  Widget _titulo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                pedido.isArchived
                    ? '${pedido.localizador} - Arquivado'
                    : pedido.localizador,
                style: AppCss.largeBold.setColor(AppColors.white).setSize(20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pedido.isMestre) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('MESTRE',
                    style: AppCss.minimumBold.copyWith(
                        fontSize: 9, color: const Color(0xFF92400E))),
              ),
            ],
            if (pedido.isParcial) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PARCIAL',
                    style: AppCss.minimumBold.copyWith(
                        fontSize: 9, color: const Color(0xFF1E40AF))),
              ),
            ],
          ],
        ),
        Text(
          pedido.cliente.nome,
          style: AppCss.minimumRegular
              .setColor(Colors.white.withValues(alpha: 0.7))
              .setSize(11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Lista de botões de ação (mesma lógica nos dois modos) ────────────────
  List<Widget> _acoes(BuildContext context, {required bool isKanban}) {
    // Pedido arquivado: exibe somente o botão de desarquivar (modo leitura)
    if (pedido.isArchived) {
      return [
        _botaoAcao(
          icon: Icons.unarchive,
          tooltip: 'Desarquivar pedido',
          onTap: () => pedidoCtrl.onUnArchivePedido(
              context, pedido, isKanban ? 0 : 1),
        ),
      ];
    }

    return [
      _botaoAcao(
        icon: Icons.cloud_download_rounded,
        tooltip: 'Importar dados',
        onTap: () => _mostrarModulosImportacao(context),
      ),
      if (pedido.podeGerarParcial)
        _botaoAcao(
          icon: Icons.add,
          tooltip: 'Criar Pedido Parcial',
          onTap: () => push(context, PedidoCreatePage(pai: pedido)),
        ),
      _botaoAcao(
        icon: Icons.local_shipping,
        tooltip: 'Acompanhar pedido',
        onTap: () => context.push('/acompanhamento/pedidos/${pedido.id}'),
      ),
      if (pedido.step.isArchivedAvailable && !pedido.isArchived)
        _botaoAcao(
          icon: Icons.archive,
          tooltip: 'Arquivar pedido',
          onTap: () => isKanban
              ? pedidoCtrl
                  .onArchive(context, pedido, isPedido: false)
                  .then((result) {
                  if (result) kanbanCtrl.setPedido(null);
                })
              : pedidoCtrl.onArchive(context, pedido),
        ),
      _botaoAcao(
        icon: Icons.edit,
        tooltip: 'Editar pedido',
        onTap: () => push(context, PedidoCreatePage(pedido: pedido)),
      ),
      _botaoAcao(
        icon: Icons.delete,
        tooltip: 'Excluir pedido',
        onTap: () => isKanban
            ? pedidoCtrl
                .onDelete(context, pedido, isPedido: false)
                .then((e) {
                if (e) kanbanCtrl.setPedido(null);
              })
            : pedidoCtrl.onDelete(context, pedido),
      ),
    ];
  }


  // ── Versão Kanban ─────────────────────────────────────────────────────────
  Widget _kanbanWidget(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final botoesAcao = _acoes(context, isKanban: true)
              .expand((btn) => [btn, const SizedBox(width: 4)])
              .toList()
            ..removeLast();

          return Container(
            width: double.maxFinite,
            padding: EdgeInsets.symmetric(
                vertical: 8, horizontal: isMobile ? 8 : 16),
            decoration: BoxDecoration(color: AppColors.primaryMain),
            child: Row(
              children: [
                InkWell(
                  onTap: () => onDelete!(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(Icons.close, color: AppColors.white),
                  ),
                ),
                const SizedBox(width: 8),
                if (isMobile)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _titulo(),
                          const SizedBox(width: 12),
                          ...botoesAcao,
                        ],
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(width: 4),
                  Expanded(child: _titulo()),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: botoesAcao,
                  ),
                ],
              ],
            ),
          );
        },
      );

  // ── Versão Página (AppBar) ────────────────────────────────────────────────
  Widget _pedidoWidget(BuildContext context) => AppBar(
        title: _titulo(),
        backgroundColor: AppColors.primaryMain,
        actions: [
          // Wrap em Row para aplicar gap uniforme de 4px entre os botões
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _acoes(context, isKanban: false)
                  .expand((btn) => [btn, const SizedBox(width: 4)])
                  .toList()
                ..removeLast(),
            ),
          ),
        ],
      );

  // ── Importar dados de módulos habilitados ──────────────────────────────
  Future<void> _mostrarModulosImportacao(BuildContext context) async {
    try {
      // Buscar módulos habilitados
      final response = await SupabaseService.client
          .from('modulos_importacao')
          .select()
          .eq('habilitado', true);

      final modulos = List<Map<String, dynamic>>.from(response);

      if (modulos.isEmpty) {
        NotificationService.showNeutral(
          'Sem módulos',
          'Nenhum módulo de importação habilitado. Habilite em Configurações → Módulos de Importação.',
        );
        return;
      }

      // Se apenas 1 módulo habilitado, abre direto
      if (modulos.length == 1) {
        final moduloId = modulos.first['id'];
        await _abrirModulo(moduloId);
        return;
      }

      // Se múltiplos, mostra dialog centralizado
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Selecione o módulo de importação',
            style: AppCss.mediumBold,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: modulos.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  hoverColor: AppColors.primaryMain.withValues(alpha: 0.05),
                  leading: Icon(
                    _iconeModulo(m['id']),
                    color: AppColors.primaryMain,
                  ),
                  title: Text(
                    _nomeModulo(m['id']),
                    style: AppCss.minimumBold.setSize(13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _abrirModulo(m['id']);
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      log('PedidoTopBar._mostrarModulosImportacao erro: $e');
      NotificationService.showNegative('Erro', 'Falha ao verificar módulos: $e');
    }
  }

  IconData _iconeModulo(String id) {
    switch (id) {
      case 'spe':
        return Icons.cloud_download_rounded;
      case 'tqs':
        return Icons.table_chart_rounded;
      default:
        return Icons.cloud_download_rounded;
    }
  }

  Future<void> _abrirModulo(String moduloId) async {
    switch (moduloId) {
      case 'spe':
        await showSpeImportarDialog(pedido);
        break;
      case 'tqs':
        await showTqsImportarDialog(pedido);
        break;
      default:
        NotificationService.showNeutral(
          'Módulo indisponível',
          'O módulo "$moduloId" ainda não foi implementado.',
        );
    }
  }

  String _nomeModulo(String id) {
    switch (id) {
      case 'spe':
        return 'SPE — Pedido Técnico';
      case 'tqs':
        return 'TQS — Importar CSV';
      default:
        return id.toUpperCase();
    }
  }
}
