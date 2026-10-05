import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/ui/elemento_comparativo_dialog.dart';
import 'package:aco_plus/app/modules/elemento/ui/elemento_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:file_picker/file_picker.dart';

class ElementosTab extends StatefulWidget {
  final PedidoModel pedido;

  /// Botão extra na barra de ações (ex.: relatório), antes do Comparativo
  final Widget? acaoExtra;
  const ElementosTab({required this.pedido, this.acaoExtra, super.key});

  @override
  State<ElementosTab> createState() => _ElementosTabState();
}

class _ElementosTabState extends State<ElementosTab> {
  bool _isLoading = false;
  // Filtros de visibilidade por status (true = visível)
  final Map<ElementoStatus, bool> _statusVisivel = {
    ElementoStatus.aguardando: true,
    ElementoStatus.armando: true,
    ElementoStatus.pronto: true,
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      await elementoCtrl
          .onInit(widget.pedido.id)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Se deu timeout ou erro, garante que o loader desaparece.
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _fmt(double v) => NumberFormat('#,##0.000', 'pt_BR').format(v);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            StreamOut<String>(
              stream: elementoCtrl.loadingMessageStream.listen,
              builder: (_, msg) => Text(
                msg,
                style: AppCss.mediumRegular,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return StreamOut<List<ElementoModel>>(
      stream: elementoCtrl.elementosStream.listen,
      builder: (_, elementos) {
        final validacao = elementoCtrl.getCachedValidacao(widget.pedido);
        return Column(
          children: [
            const SizedBox(height: 8),

            // ── Toolbar ───────────────────────────────────────────────────
            MediaQuery.sizeOf(context).width < 600
                ? _buildToolbarMobile(validacao, elementos)
                : _buildToolbarDesktop(validacao, elementos),

            // ── Barra de Resumo de Status ──────────────────────────────────
            if (elementos.isNotEmpty) _buildStatusSummaryBar(elementos),
            // ── Lista de elementos ────────────────────────────────────────
            if (elementos.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Nenhum elemento cadastrado',
                          style: AppCss.mediumRegular
                              .copyWith(color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text('Clique em "Novo Elemento" para começar',
                          style: AppCss.smallRegular
                              .copyWith(color: Colors.grey[400])),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Builder(
                  builder: (_) {
                    final filtrados = elementos.where((e) {
                      // Elemento com progresso parcial tem peças em armando E pronto
                      if (e.isProntoParcial) {
                        return (_statusVisivel[ElementoStatus.armando] ??
                                true) ||
                            (_statusVisivel[ElementoStatus.pronto] ?? true);
                      }
                      return _statusVisivel[e.status] ?? true;
                    }).toList();
                    if (filtrados.isEmpty) {
                      return Center(
                        child: Text(
                            'Nenhum elemento visível com os filtros ativos',
                            style: AppCss.mediumRegular
                                .copyWith(color: Colors.grey[500])),
                      );
                    }
                    return LayoutBuilder(builder: (context, constraints) {
                      const gap = 10.0;
                      final util = constraints.maxWidth - 32;
                      final colunas = util >= 1100
                          ? 3
                          : util >= 700
                              ? 2
                              : 1;
                      final largura = (util - gap * (colunas - 1)) / colunas;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            for (final el in filtrados)
                              SizedBox(
                                width: largura,
                                child: _ElementoTile(
                                  elemento: el,
                                  pedido: widget.pedido,
                                  fmt: _fmt,
                                ),
                              ),
                          ],
                        ),
                      );
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── TOOLBAR DESKTOP (restaurada do original) ──────────────────────────────
  Widget _buildToolbarDesktop(
      ElementoValidacaoResult validacao, List<ElementoModel> elementos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Elementos (${elementos.length})',
            style: AppCss.mediumBold,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.acaoExtra != null) widget.acaoExtra!,
              // ── Comparativo (contorno, cor indica se bate) ──
              _ActionButton(
                icon: validacao.isOk
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                label: 'Comparativo',
                color: validacao.isOk ? AppColors.success : AppColors.error,
                variant: _ButtonVariant.outlined,
                onTap: () => showElementoComparativoDialog(
                  context,
                  validacao: validacao,
                ),
              ),
              if (usuarioCtrl.usuario?.podeEditarElementos ?? false) ...[
                // ── Novo elemento (principal) ──
                _ActionButton(
                  icon: Icons.add_rounded,
                  label: 'Novo elemento',
                  color: AppColors.primaryMain,
                  variant: _ButtonVariant.filled,
                  onTap: () => showElementoFormDialog(
                    context,
                    pedido: widget.pedido,
                  ),
                ),
                // ── Limpar: ação destrutiva no menu ⋮ ──
                if (elementos.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações',
                    icon: Icon(Icons.more_vert, color: AppColors.neutralDark),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.neutralLight),
                    ),
                    onSelected: (_) => _onLimpar(elementos),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'limpar',
                        child: Row(children: [
                          Icon(Icons.delete_sweep_rounded,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 10),
                          Text('Limpar todos os elementos',
                              style: TextStyle(color: AppColors.error)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── TOOLBAR MOBILE (ícones compactos) ─────────────────────────────────────
  Widget _buildToolbarMobile(
      ElementoValidacaoResult validacao, List<ElementoModel> elementos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Elementos (${elementos.length})',
              style: AppCss.smallBold.setSize(13),
            ),
          ),
          if (widget.acaoExtra != null) ...[
            widget.acaoExtra!,
            const SizedBox(width: 8),
          ],
          // Comparativo
          _iconBtn(
            icon: validacao.isOk
                ? Icons.check_circle_outlined
                : Icons.warning_amber_rounded,
            color: validacao.isOk ? AppColors.success : AppColors.error,
            tooltip: 'Comparativo',
            onTap: () => showElementoComparativoDialog(
              context,
              validacao: validacao,
            ),
          ),
          if (usuarioCtrl.usuario?.podeEditarElementos ?? false) ...[
            const SizedBox(width: 8),
            // Limpar
            StreamOut<List<ElementoModel>>(
              stream: elementoCtrl.elementosStream.listen,
              builder: (_, elementos) {
                if (elementos.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _iconBtn(
                  icon: Icons.delete_sweep_rounded,
                  color: AppColors.error,
                  tooltip: 'Limpar tudo',
                  onTap: () => _onLimpar(elementos),
                );
              },
            ),
            const SizedBox(width: 8),
            // Novo
            _iconBtn(
              icon: Icons.add,
              color: Colors.white,
              bgColor: AppColors.primaryMain,
              tooltip: 'Novo Elemento',
              onTap: () => showElementoFormDialog(
                context,
                pedido: widget.pedido,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── AÇÃO LIMPAR (compartilhada entre mobile/desktop) ──────────────────────
  Future<void> _onLimpar(List<ElementoModel> elementos) async {
    final hasInProduction =
        elementos.any((e) => e.status != ElementoStatus.aguardando);
    if (hasInProduction) {
      showInfoDialog(
          'Não é possível limpar a lista porque existem elementos que já estão em produção ou concluídos. Exclua individualmente os itens aguardando.');
      return;
    }
    if (await showConfirmDialog(
      'Apagar TODOS os elementos?',
      'Esta ação não pode ser desfeita. Deseja continuar?',
    )) {
      await elementoCtrl.onDeleteAllElementos(widget.pedido.id);
    }
  }

  // ─── ÍCONE COMPACTO (mobile toolbar) ───────────────────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    Color? bgColor,
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
          decoration: BoxDecoration(
            color: bgColor ?? color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // ─── BARRA DE RESUMO DE STATUS ──────────────────────────────────────────────
  Widget _buildStatusSummaryBar(List<ElementoModel> elementos) {
    int totalQtd = 0;
    final Map<ElementoStatus, double> qtdPorStatus = {
      ElementoStatus.aguardando: 0,
      ElementoStatus.armando: 0,
      ElementoStatus.pronto: 0,
    };
    final Map<ElementoStatus, double> pesoPorStatus = {
      ElementoStatus.aguardando: 0,
      ElementoStatus.armando: 0,
      ElementoStatus.pronto: 0,
    };

    for (final e in elementos) {
      totalQtd += e.qtde;

      if (e.status == ElementoStatus.aguardando) {
        qtdPorStatus[ElementoStatus.aguardando] =
            (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + e.qtde;
        pesoPorStatus[ElementoStatus.aguardando] =
            (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + e.pesoTotal;
      } else if (e.status == ElementoStatus.pronto) {
        qtdPorStatus[ElementoStatus.pronto] =
            (qtdPorStatus[ElementoStatus.pronto] ?? 0) + e.qtde;
        pesoPorStatus[ElementoStatus.pronto] =
            (pesoPorStatus[ElementoStatus.pronto] ?? 0) + e.pesoTotal;
      } else {
        // armando — cálculo proporcional baseado no qtdePronto
        final qtdeProntoFrac = e.qtdePronto.toDouble();
        final qtdeArmandoFrac = (e.qtde - e.qtdePronto).toDouble();
        final pesoPorUnidade = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

        qtdPorStatus[ElementoStatus.pronto] =
            (qtdPorStatus[ElementoStatus.pronto] ?? 0) + qtdeProntoFrac;
        pesoPorStatus[ElementoStatus.pronto] =
            (pesoPorStatus[ElementoStatus.pronto] ?? 0) +
                (qtdeProntoFrac * pesoPorUnidade);

        qtdPorStatus[ElementoStatus.armando] =
            (qtdPorStatus[ElementoStatus.armando] ?? 0) + qtdeArmandoFrac;
        pesoPorStatus[ElementoStatus.armando] =
            (pesoPorStatus[ElementoStatus.armando] ?? 0) +
                (qtdeArmandoFrac * pesoPorUnidade);
      }
    }

    Widget chip(ElementoStatus status) {
      final qtd = qtdPorStatus[status] ?? 0;
      final peso = pesoPorStatus[status] ?? 0;
      final pct = totalQtd > 0 ? (qtd / totalQtd * 100) : 0;
      final visivel = _statusVisivel[status] ?? true;
      final qtdTxt = qtd % 1 == 0 ? qtd.toInt().toString() : qtd.toStringAsFixed(1);

      return Tooltip(
        message: visivel ? 'Ocultar ${status.label.toLowerCase()}' : 'Mostrar ${status.label.toLowerCase()}',
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: () => setState(() => _statusVisivel[status] = !visivel),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: visivel ? Colors.white : AppColors.neutralLightest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: visivel
                    ? status.color.withValues(alpha: 0.5)
                    : AppColors.neutralLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  visivel ? Icons.check_circle : Icons.circle_outlined,
                  size: 15,
                  color: visivel ? status.color : AppColors.primaryMedium,
                ),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: AppCss.minimumBold.setSize(12.5).setColor(
                      visivel ? AppColors.black : AppColors.neutralMedium),
                ),
                const SizedBox(width: 6),
                Text(
                  '$qtdTxt (${pct.toStringAsFixed(0)}%) · ${_fmt(peso)} kg',
                  style: AppCss.minimumRegular
                      .setSize(12)
                      .setColor(AppColors.neutralMedium),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(ElementoStatus.aguardando),
            chip(ElementoStatus.armando),
            chip(ElementoStatus.pronto),
          ],
        ),
      ),
    );
  }
}

// ─── TILE DE ELEMENTO ─────────────────────────────────────────────────────────
class _ElementoTile extends StatefulWidget {
  final ElementoModel elemento;
  final PedidoModel pedido;
  final String Function(double) fmt;
  const _ElementoTile(
      {required this.elemento, required this.pedido, required this.fmt});

  @override
  State<_ElementoTile> createState() => _ElementoTileState();
}

class _ElementoTileState extends State<_ElementoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final el = widget.elemento;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _expanded
                ? el.status.color.withValues(alpha: 0.5)
                : AppColors.neutralLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Linha do elemento ─────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Indicador lateral colorido pelo status
                  Container(width: 3, color: el.status.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome + badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(el.nome,
                                  style: AppCss.mediumBold.setSize(14.5)),
                              if (el.qtde > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMain
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('x${el.qtde}',
                                      style: AppCss.minimumBold
                                          .setColor(AppColors.primaryMain)
                                          .setSize(11)),
                                ),
                              // Badge de status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      el.status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  el.status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: el.status.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${el.posicoes.length} posições · unitário ${widget.fmt(el.pesoUnitario)} kg',
                            style: AppCss.minimumRegular
                                .setSize(12.5)
                                .copyWith(color: AppColors.neutralMedium),
                          ),
                          const SizedBox(height: 6),
                          // Peso + botões na mesma linha
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.neutralLightest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${widget.fmt(el.pesoTotal)} kg',
                                  style: AppCss.mediumBold
                                      .setColor(AppColors.black)
                                      .setSize(13),
                                ),
                              ),
                              // Botão de Anexos
                              _tileAction(
                                icon: el.arquivos.isEmpty
                                    ? Icons.attach_file_rounded
                                    : Icons.attachment_rounded,
                                color: el.arquivos.isEmpty
                                    ? Colors.grey[400]!
                                    : AppColors.secondary,
                                tooltip: 'Anexos (${el.arquivos.length})',
                                onTap: () =>
                                    _showArquivosDialog(context, el),
                              ),
                              // Ações
                              if (usuarioCtrl.usuario?.podeEditarElementos ??
                                  false) ...[
                                _tileAction(
                                  icon: Icons.edit_rounded,
                                  color: Colors.grey[600]!,
                                  tooltip: 'Editar',
                                  onTap: () => showElementoFormDialog(
                                      context,
                                      pedido: widget.pedido,
                                      elemento: el),
                                ),
                                _tileAction(
                                  icon: Icons.delete_outline_rounded,
                                  color:
                                      el.status == ElementoStatus.aguardando
                                          ? Colors.red[400]!
                                          : Colors.grey[300]!,
                                  tooltip:
                                      el.status == ElementoStatus.aguardando
                                          ? 'Excluir'
                                          : 'Não é possível excluir',
                                  onTap:
                                      el.status == ElementoStatus.aguardando
                                          ? () => elementoCtrl
                                              .onDeleteElemento(el)
                                          : null,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // ── Barra de progresso parcial ─────────────────────────────────────
          if (el.qtde > 1 && el.qtdePronto > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: el.progressoPronto,
                      minHeight: 18,
                      backgroundColor: AppColors.neutralLightest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.statusPronto),
                    ),
                  ),
                  Text(
                    '${el.qtdePronto} de ${el.qtde} peças prontas',
                    style: AppCss.minimumBold.setSize(10).setColor(
                        el.progressoPronto > 0.5
                            ? Colors.white
                            : AppColors.black),
                  ),
                ],
              ),
            ),

          // ── Posições expandidas ───────────────────────────────────────────
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: AppColorsSystem.light.primary[50],
              child: Column(
                children: [
                  const Divisor(height: 1),
                  const SizedBox(height: 12),
                  // Cabeçalho das colunas
                  Row(
                    children: [
                      _colHead('Posição', 2),
                      _colHead('OS', 2),
                      _colHead('Bitola', 3),
                      _colHead('Peso Un.', 2, isEnd: true),
                      _colHead('T. Item', 2, isEnd: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...el.posicoes.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child:
                                    Text(p.nome, style: AppCss.minimumRegular)),
                            Expanded(
                                flex: 2,
                                child: Text(p.numeroOs,
                                    style: AppCss.minimumRegular
                                        .copyWith(color: Colors.grey[600]))),
                            Expanded(
                              flex: 3,
                              child: Text(
                                p.produto?.labelMinified ?? p.produtoId,
                                style: AppCss.minimumBold.setSize(12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                widget.fmt(p.pesoKg),
                                style: AppCss.minimumRegular,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                widget.fmt(p.pesoKg * el.qtde),
                                style: AppCss.minimumBold
                                    .setColor(AppColors.primaryMain),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      )),
                  // Subtotal
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Total do Elemento: ',
                          style: AppCss.minimumRegular
                              .copyWith(color: Colors.grey[600])),
                      Text(
                        '${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.mediumBold
                            .setColor(AppColors.primaryMain)
                            .setSize(15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _colHead(String label, int flex, {bool isEnd = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style:
            AppCss.minimumBold.copyWith(color: Colors.grey[400], fontSize: 11),
        textAlign: isEnd ? TextAlign.end : TextAlign.start,
      ),
    );
  }

  Widget _tileAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  void _showArquivosDialog(BuildContext context, ElementoModel elemento) {
    showDialog(
      context: context,
      builder: (_) =>
          _ElementoArquivosDialog(elemento: elemento, pedido: widget.pedido),
    );
  }
}

// ─── DIÁLOGO DE ARQUIVOS DO ELEMENTO ─────────────────────────────────────────
class _ElementoArquivosDialog extends StatefulWidget {
  final ElementoModel elemento;
  final PedidoModel pedido;
  const _ElementoArquivosDialog({required this.elemento, required this.pedido});

  @override
  State<_ElementoArquivosDialog> createState() =>
      _ElementoArquivosDialogState();
}

class _ElementoArquivosDialogState extends State<_ElementoArquivosDialog> {
  bool _carregandoArquivos = false;

  @override
  void initState() {
    super.initState();
    _carregarArquivos();
  }

  Future<void> _carregarArquivos() async {
    if (widget.elemento.arquivos.isEmpty) {
      if (mounted) setState(() => _carregandoArquivos = true);
      final arqs = await AppSupabaseClient.elementoArquivos
          .fetchByElementoId(widget.elemento.id);
      if (mounted) {
        final elementoSync = elementoCtrl.elementos.firstWhere(
          (e) => e.id == widget.elemento.id,
          orElse: () => widget.elemento,
        );
        elementoSync.arquivos
          ..clear()
          ..addAll(arqs);
        setState(() => _carregandoArquivos = false);
      }
    }
  }

  void _onUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.bytes != null) {
      final name = result.files.single.name;
      final bytes = result.files.single.bytes!;
      final extension = name.split('.').last.toLowerCase();
      final mimeType =
          extension == 'pdf' ? 'application/pdf' : 'image/$extension';
      final isPdf = mimeType == 'application/pdf';

      // Para PDF: abre dialog com mensagem reativa do stream
      if (isPdf && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => StreamOut<String>(
            stream: elementoCtrl.loadingMessageStream.listen,
            builder: (_, msg) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.picture_as_pdf_outlined,
                          color: AppColors.secondary, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      msg,
                      style: AppCss.mediumBold,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await elementoCtrl.onAddArquivo(
        widget.elemento,
        name,
        bytes,
        mimeType,
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Busca a edição mais atual do elemento diretamente do cache centralizado
    final elementoSync = elementoCtrl.elementos.firstWhere(
      (e) => e.id == widget.elemento.id,
      orElse: () => widget.elemento,
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.attachment_rounded, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text('Anexos: ${elementoSync.nome}')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_carregandoArquivos)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (elementoSync.arquivos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.file_present_rounded,
                        size: 48, color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    Text('Nenhum anexo encontrado',
                        style: AppCss.mediumRegular
                            .copyWith(color: Colors.grey[400])),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: elementoSync.arquivos.map((arq) {
                      return ListTile(
                        leading: Icon(
                          arq.tipo.contains('image')
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                          color: AppColors.secondary,
                        ),
                        title: Text(arq.nome, style: AppCss.minimumBold),
                        subtitle: Text(
                            '${(arq.tamanho / 1024).toStringAsFixed(1)} KB · ${DateFormat('dd/MM/yy').format(arq.criadoEm)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.open_in_new_rounded, size: 20),
                              onPressed: () => openInNewTab(arq.url),
                              tooltip: 'Abrir',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 20),
                              onPressed: (usuarioCtrl.usuario?.podeEditarElementos ?? false)
                                  ? () async {
                                      if (await showConfirmDialog('Apagar anexo?',
                                          'Deseja remover este arquivo permanentemente?')) {
                                        await elementoCtrl.onDeleteArquivo(
                                            arq, widget.pedido.id);
                                        setState(() {});
                                      }
                                    }
                                  : null,
                              tooltip: 'Excluir',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: (usuarioCtrl.usuario?.podeEditarElementos ?? false)
                  ? ElevatedButton.icon(
                      onPressed: _onUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.secondary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Adicionar Foto ou PDF',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      actions: [
        if (elementoSync.arquivos.isNotEmpty &&
            (usuarioCtrl.usuario?.podeEditarElementos ?? false))
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: Colors.red, size: 18),
            label: const Text('Apagar Todos',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (await showConfirmDialog(
                'Apagar todos os anexos?',
                'Deseja remover permanentemente todos os ${elementoSync.arquivos.length} arquivo(s) deste elemento?',
              )) {
                await elementoCtrl.onDeleteAllArquivos(
                    elementoSync, widget.pedido.id);
                setState(() {});
              }
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Design System: Action Button Padronizado
// ═════════════════════════════════════════════════════════════════════════════
enum _ButtonVariant { filled, outlined }

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final _ButtonVariant variant;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == _ButtonVariant.filled;

    return Material(
      color: isFilled ? color : color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isFilled
                ? null
                : Border.all(color: color.withValues(alpha: 0.18), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isFilled ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isFilled ? Colors.white : color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
