import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
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

  // ── Título: localizador, selos e cliente ─────────────────────────────────
  Widget _selo(String texto, {Color? fundo, Color? cor, Widget? icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fundo ?? Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[icone, const SizedBox(width: 5)],
          Text(
            texto,
            style: AppCss.minimumBold.copyWith(
                fontSize: 11, color: cor ?? AppColors.white),
          ),
        ],
      ),
    );
  }

  String get _tipoCurto => switch (pedido.tipo) {
        PedidoTipo.cd => 'CD',
        PedidoTipo.cda => 'CDA',
        PedidoTipo.outros => 'Outros',
      };

  /// Entrega com cor: âmbar hoje, vermelho atrasado (exceto entregues)
  Widget? _seloEntrega() {
    final entrega = pedido.deliveryAt;
    if (entrega == null) return null;
    final hoje = DateTime.now();
    final dias = DateTime(entrega.year, entrega.month, entrega.day)
        .difference(DateTime(hoje.year, hoje.month, hoje.day))
        .inDays;
    String texto = 'Entrega ${entrega.ddMMyyyy()}';
    Color? fundo;
    if (!pedido.isEntregue) {
      if (dias < 0) {
        texto = '$texto · ${-dias == 1 ? '1 dia' : '${-dias} dias'} de atraso';
        fundo = AppColors.statusCritico;
      } else if (dias == 0) {
        texto = 'Entrega hoje';
        fundo = AppColors.statusAtencao;
      } else {
        texto = '$texto · em ${dias == 1 ? '1 dia' : '$dias dias'}';
      }
    }
    return _selo(
      texto,
      fundo: fundo,
      icone: const Icon(Icons.event, size: 13, color: Colors.white),
    );
  }

  Widget _titulo() {
    final entrega = _seloEntrega();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Selos só cabem com espaço; em telas estreitas fica o essencial
        final largo = constraints.maxWidth >= 640;
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
                    style:
                        AppCss.largeBold.setColor(AppColors.white).setSize(19),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pedido.isMestre) ...[
                  const SizedBox(width: 8),
                  _selo('MESTRE',
                      fundo: const Color(0xFFFEF3E2),
                      cor: const Color(0xFFB45309)),
                ],
                if (pedido.isParcial) ...[
                  const SizedBox(width: 8),
                  _selo('PARCIAL',
                      fundo: const Color(0xFFE8EFFE),
                      cor: const Color(0xFF1D4ED8)),
                ],
                if (largo) ...[
                  const SizedBox(width: 10),
                  _selo(_tipoCurto),
                  if (pedido.steps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _selo(
                      pedido.step.name,
                      icone: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pedido.step.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  if (entrega != null) ...[const SizedBox(width: 6), entrega],
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [pedido.cliente.nome.trim(), pedido.obra.descricao.trim()]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              style: AppCss.minimumRegular
                  .setColor(Colors.white.withValues(alpha: 0.7))
                  .setSize(11.5),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
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
      // Editar com nome, em destaque
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.primaryMain,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: AppCss.minimumBold.setSize(13),
          ),
          onPressed: () => push(context, PedidoCreatePage(pedido: pedido)),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Editar'),
        ),
      ),
      // Arquivar e Excluir no menu ⋮ (longe de um clique acidental)
      PopupMenuButton<String>(
        tooltip: 'Mais ações',
        icon: Icon(Icons.more_vert, color: AppColors.white),
        style: IconButton.styleFrom(backgroundColor: Colors.transparent),
        onSelected: (acao) {
          if (acao == 'arquivar') {
            isKanban
                ? pedidoCtrl
                    .onArchive(context, pedido, isPedido: false)
                    .then((result) {
                    if (result) kanbanCtrl.setPedido(null);
                  })
                : pedidoCtrl.onArchive(context, pedido);
          } else if (acao == 'excluir') {
            isKanban
                ? pedidoCtrl
                    .onDelete(context, pedido, isPedido: false)
                    .then((e) {
                    if (e) kanbanCtrl.setPedido(null);
                  })
                : pedidoCtrl.onDelete(context, pedido);
          }
        },
        itemBuilder: (_) => [
          if (pedido.step.isArchivedAvailable && !pedido.isArchived)
            const PopupMenuItem(
              value: 'arquivar',
              child: Row(children: [
                Icon(Icons.archive_outlined, size: 18),
                SizedBox(width: 10),
                Text('Arquivar pedido'),
              ]),
            ),
          PopupMenuItem(
            value: 'excluir',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Text('Excluir pedido',
                  style: TextStyle(color: AppColors.error)),
            ]),
          ),
        ],
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
