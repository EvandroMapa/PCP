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
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:file_picker/file_picker.dart';

class ElementosTab extends StatefulWidget {
  final PedidoModel pedido;
  const ElementosTab({required this.pedido, super.key});

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
            Builder(
              builder: (context) {
                final isMobile = MediaQuery.sizeOf(context).width < 600;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Elementos (${elementos.length})',
                          style: AppCss.smallBold.setSize(13),
                        ),
                      ),
                      if (isMobile) ...[
                        // ── MOBILE: ícones compactos ──
                        // Comparativo
                        _iconBtn(
                          icon: validacao.isOk
                              ? Icons.check_circle_outlined
                              : Icons.warning_amber_rounded,
                          color: validacao.isOk
                              ? AppColors.success
                              : AppColors.error,
                          tooltip: 'Comparativo',
                          onTap: () => showElementoComparativoDialog(
                            context,
                            validacao: validacao,
                          ),
                        ),
                        if (usuarioCtrl.usuario?.podeEditarElementos ??
                            false) ...[
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
                      ] else ...[
                        // ── DESKTOP: botões pill com texto ──
                        if (usuarioCtrl.usuario?.podeEditarElementos ??
                            false) ...[
                          // Limpar
                          StreamOut<List<ElementoModel>>(
                            stream: elementoCtrl.elementosStream.listen,
                            builder: (_, elementos) {
                              if (elementos.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return _ActionButton(
                                icon: Icons.delete_sweep_rounded,
                                label: 'Limpar',
                                color: AppColors.error,
                                variant: _ButtonVariant.outlined,
                                onTap: () => _onLimpar(elementos),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          // Novo Elemento
                          _ActionButton(
                            icon: Icons.add_rounded,
                            label: 'Novo Elemento',
                            color: AppColors.primaryMain,
                            variant: _ButtonVariant.filled,
                            onTap: () => showElementoFormDialog(
                              context,
                              pedido: widget.pedido,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Comparativo
                        _ActionButton(
                          icon: validacao.isOk
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          label: 'Comparativo',
                          color: validacao.isOk
                              ? AppColors.success
                              : AppColors.error,
                          variant: _ButtonVariant.outlined,
                          onTap: () => showElementoComparativoDialog(
                            context,
                            validacao: validacao,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

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
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ElementoTile(
                          elemento: filtrados[i],
                          pedido: widget.pedido,
                          fmt: _fmt,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
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
    double totalPeso = 0;
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
      totalPeso += e.pesoTotal;

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

    Widget col(ElementoStatus status) {
      final qtd = qtdPorStatus[status] ?? 0;
      final peso = pesoPorStatus[status] ?? 0;
      final pctQtd = totalQtd > 0 ? (qtd / totalQtd * 100) : 0;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _statusVisivel[status] =
              !(_statusVisivel[status] ?? true)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: status.backgroundColor,
              border: Border(
                top: BorderSide(color: status.color, width: 3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        status.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: (_statusVisivel[status] ?? true)
                              ? status.color
                              : Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      (_statusVisivel[status] ?? true)
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 12,
                      color: (_statusVisivel[status] ?? true)
                          ? status.color
                          : Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${qtd % 1 == 0 ? qtd.toInt() : qtd.toStringAsFixed(1)} (${pctQtd.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmt(peso)} kg',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            col(ElementoStatus.aguardando),
            Container(width: 0.5, height: 60, color: Colors.grey.shade300),
            col(ElementoStatus.armando),
            Container(width: 0.5, height: 60, color: Colors.grey.shade300),
            col(ElementoStatus.pronto),
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
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: el.status.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: el.status.color.withValues(alpha: 0.3)),
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
                  Container(
                    width: 4,
                    color: el.status.color
                        .withValues(alpha: _expanded ? 1.0 : 0.6),
                  ),
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
                                  style: AppCss.mediumBold.setSize(15)),
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
                                      el.status.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: el.status.color
                                          .withValues(alpha: 0.4),
                                      width: 0.5),
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
                            '${el.posicoes.length} pos. · Unit: ${widget.fmt(el.pesoUnitario)} kg',
                            style: AppCss.minimumRegular
                                .copyWith(color: Colors.grey[600]),
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
                                  color: AppColors.primaryMain
                                      .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.fmt(el.pesoTotal)} kg',
                                  style: AppCss.mediumBold
                                      .setColor(AppColors.primaryMain)
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
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        el.status == ElementoStatus.pronto
                            ? Colors.green[700]!
                            : Colors.green[500]!,
                      ),
                    ),
                  ),
                  Text(
                    '${el.qtdePronto} / ${el.qtde} PÇ PRONTAS',
                    style: AppCss.minimumBold.setSize(10).setColor(
                        el.progressoPronto > 0.5
                            ? Colors.white
                            : Colors.green[900]!),
                  ),
                ],
              ),
            ),

          // ── Posições expandidas ───────────────────────────────────────────
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: Colors.grey.shade50.withValues(alpha: 0.5),
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
            if (elementoSync.arquivos.isEmpty)
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
