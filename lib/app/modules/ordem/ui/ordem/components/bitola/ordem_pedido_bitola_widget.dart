import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/posicao_progresso_helper.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materia_prima_bottom.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/ordem_pedido_elementos_dialog.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/ordem_pedido_bitola_pause_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/status/ordem_pedido_status_normal_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/status/ordem_pedido_status_operator_widget.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class OrdemPedidoProdutoWidget extends StatelessWidget {
  final PedidoBitolaModel produto;
  final OrdemModel ordem;
  final MateriaPrimaModel? materiaPrima;

  const OrdemPedidoProdutoWidget({
    super.key,
    required this.produto,
    required this.ordem,
    required this.materiaPrima,
  });

  @override
  Widget build(BuildContext context) {
    final status = produto.statusView.status;
    final statusColor = produto.isPaused ? Colors.orange : status.color;

    // Modo "por OS": operador com elementos cadastrados
    final isModoPorOS = usuario.isOperador &&
        PreferencesService.apontamentoProducaoCD.value == 'por_os' &&
        _pedidoTemElementos();

    // Modo "por pedido": operador que não está no modo por OS
    final isModoPorPedido = usuario.isOperador && !isModoPorOS;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: isModoPorOS
            ? () => _openElementosDialog(context)
            : isModoPorPedido
                ? () => _openStatusDialog(context)
                : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: produto.isPaused
                ? Colors.orange.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Borda lateral colorida pelo status
                Container(width: 4, color: statusColor),
                // Conteúdo principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: localizador + tags + badge status (modo por pedido)
                        Row(
                          children: [
                            if (produto.isPaused) _pauseTagWidget(),
                            if (produto.pedido.tags.isNotEmpty)
                              _tagWidget(produto.pedido.tags.first),
                            Text(
                              produto.pedido.localizador,
                              style: AppCss.mediumBold.setSize(15),
                            ),
                            if (isModoPorPedido) ...[
                              const Spacer(),
                              // Badge de status clicável
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          statusColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      status ==
                                              PedidoBitolaStatus
                                                  .aguardandoProducao
                                          ? 'AGUARDANDO'
                                          : status.label.toUpperCase(),
                                      style: AppCss.minimumBold
                                          .setSize(11)
                                          .setColor(statusColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.touch_app_rounded,
                                        size: 13, color: statusColor),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Peso + cliente/obra
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain
                                    .withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                produto.qtde.toKg(),
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(AppColors.primaryMain),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${produto.cliente.nome} · ${produto.obra.descricao}',
                                style: AppCss.minimumRegular
                                    .setSize(12)
                                    .setColor(Colors.grey[600]!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (produto.pedido.deliveryAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Entrega: ${produto.pedido.deliveryAt?.text()}',
                                style: AppCss.minimumRegular
                                    .setSize(11)
                                    .setColor(Colors.grey[500]!),
                              ),
                            ],
                          ),
                        ],
                        if (materiaPrima != null) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final result =
                                  await showMateriaPrimaBottom(materiaPrima!);
                              if (result != null) {
                                push(
                                    context,
                                    MateriaPrimaCreatePage(
                                        materiaPrima: materiaPrima));
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 12, color: Colors.orange[400]),
                                const SizedBox(width: 4),
                                Text(
                                  materiaPrima!.label,
                                  style: AppCss.minimumRegular
                                      .setSize(11)
                                      .setColor(Colors.orange[700]!)
                                      .copyWith(
                                          decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Botões de status laterais (somente quando NÃO é modo por pedido)
                if (!isModoPorPedido)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _statusWidget(readOnly: isModoPorOS),
                        if (!isModoPorOS &&
                            produto.statusView.status ==
                                PedidoBitolaStatus.produzindo)
                          OrdemPedidoProdutoPauseWidget(
                              ordem: ordem, produto: produto),
                        if (isModoPorOS) _buildMiniProgressOS(),
                      ],
                    ),
                  ),
                // Mini progress (modo por OS)
                if (isModoPorOS)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildMiniProgressOS(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _pedidoTemElementos() {
    return AppSupabaseClient.elementos.data
        .any((e) => e.pedidoId == produto.pedidoId);
  }

  void _openElementosDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdemPedidoElementosPage(
          produto: produto,
          ordem: ordem,
        ),
      ),
    );
  }

  void _openStatusDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => _OperadorStatusDialog(
        produto: produto,
        ordem: ordem,
      ),
    );
  }

  Widget _buildMiniProgressOS() {
    final result =
        calcularProgressoPosicoes(produto.pedidoId, ordem.produto.id);
    if (!result.hasData) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text('Clique para abrir OS',
                style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniCircle(
                  'Ag.', result.prcntAguardando, PosicaoStatus.aguardando.color),
              const SizedBox(width: 8),
              _miniCircle('Prod.', result.prcntProduzindo,
                  PosicaoStatus.produzindo.color),
              const SizedBox(width: 8),
              _miniCircle(
                  'Pronto', result.prcntPronto, PosicaoStatus.pronto.color),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 10, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text('Abrir OS',
                  style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniCircle(String label, double prcnt, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: prcnt,
                backgroundColor: color.withValues(alpha: 0.15),
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(prcnt * 100).toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[500])),
      ],
    );
  }

  Widget _statusWidget({bool readOnly = false}) {
    return usuario.isOperador
        ? OrdemPedidoStatusOperatorWidget(
            produto: produto, ordem: ordem, readOnly: readOnly)
        : OrdemPedidoStatusNormalWidget(produto: produto, ordem: ordem);
  }

  Widget _tagWidget(TagModel tag) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag.nome,
        style: TextStyle(
          color:
              tag.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pauseTagWidget() {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PAUSADO',
        style: TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── DIALOG FULLSCREEN DE STATUS (MODO POR PEDIDO) ───────────────────────────

class _OperadorStatusDialog extends StatefulWidget {
  final PedidoBitolaModel produto;
  final OrdemModel ordem;

  const _OperadorStatusDialog({
    required this.produto,
    required this.ordem,
  });

  @override
  State<_OperadorStatusDialog> createState() => _OperadorStatusDialogState();
}

class _OperadorStatusDialogState extends State<_OperadorStatusDialog> {
  PedidoBitolaStatus? _selecionando;
  PedidoBitolaStatus? _statusAtualLocal;

  @override
  void initState() {
    super.initState();
    _statusAtualLocal = widget.produto.statusView.status;
  }

  Future<void> _onSelectStatus(PedidoBitolaStatus status) async {
    if (status == _statusAtualLocal) return;
    setState(() => _selecionando = status);
    await ordemCtrl.onSelectProdutoStatus(
        widget.ordem, widget.produto, status);
    if (mounted) {
      setState(() {
        _statusAtualLocal = status;
        _selecionando = null;
      });
    }
  }

  IconData _iconFor(PedidoBitolaStatus status) {
    switch (status) {
      case PedidoBitolaStatus.aguardandoProducao:
        return Icons.hourglass_bottom_rounded;
      case PedidoBitolaStatus.produzindo:
        return Icons.construction_rounded;
      case PedidoBitolaStatus.pronto:
        return Icons.check_circle_rounded;
      default:
        return Icons.circle;
    }
  }

  String _labelFor(PedidoBitolaStatus status) {
    if (status == PedidoBitolaStatus.aguardandoProducao) return 'AGUARDANDO';
    return status.label.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusAtual = _statusAtualLocal ?? widget.produto.statusView.status;
    final statuses = [
      PedidoBitolaStatus.aguardandoProducao,
      PedidoBitolaStatus.produzindo,
      PedidoBitolaStatus.pronto,
    ];

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── HEADER ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.produto.pedido.localizador,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.produto.cliente.nome,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.produto.obra.descricao,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── BOTÕES DE STATUS ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  children: statuses.map((status) {
                    final isAtivo = status == statusAtual;
                    final isCarregando = _selecionando == status;
                    final color = status.color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: isCarregando
                            ? null
                            : () => _onSelectStatus(status),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: isAtivo
                                ? color.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isAtivo
                                  ? color.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.10),
                              width: isAtivo ? 2.5 : 1.5,
                            ),
                            boxShadow: isAtivo
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.25),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: isAtivo ? 0.25 : 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: isCarregando
                                    ? Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: color,
                                        ),
                                      )
                                    : Icon(
                                        _iconFor(status),
                                        size: 24,
                                        color: color,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _labelFor(status),
                                  style: TextStyle(
                                    color: isAtivo
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.75),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              if (isAtivo)
                                Icon(Icons.check_circle_rounded,
                                    color: color, size: 26),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ─── BOTÃO FECHAR ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.07),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Text(
                      'FECHAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
