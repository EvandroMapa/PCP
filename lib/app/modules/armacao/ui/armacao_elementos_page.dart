import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/fullscreen_button.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/services/fullscreen_service.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:dio/dio.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:flutter/material.dart';

class ArmacaoElementosPage extends StatefulWidget {
  final PedidoModel pedido;
  const ArmacaoElementosPage({required this.pedido, super.key});

  @override
  State<ArmacaoElementosPage> createState() => _ArmacaoElementosPageState();
}

class _ArmacaoElementosPageState extends State<ArmacaoElementosPage> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  // Filtros de visibilidade por status (todos visíveis por padrão)
  final Map<ElementoStatus, bool> _statusVisivel = {
    ElementoStatus.aguardando: true,
    ElementoStatus.armando: true,
    ElementoStatus.pronto: true,
  };

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Garante que o lock global (isStatusChanging) seja liberado ao sair da tela.
    // Sem isso, o Realtime fica bloqueado indefinidamente se o usuário sair
    // durante uma troca de status.
    armacaoCtrl.liberarLockSeAtivo();
    super.dispose();
  }

  Future<void> _init() async {
    await armacaoCtrl.onFetchElementos(widget.pedido);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _showImageDialog(ElementoModel elemento) async {
    if (elemento.arquivos.isEmpty) return;

    // 1. Restrição de Status: Desenho só visível em produção ou pronto
    if (elemento.status == ElementoStatus.aguardando) {
      showInfoDialog(
        'VISUALIZAÇÃO BLOQUEADA!\n\n'
        'O desenho técnico só fica disponível após o início da produção.\n\n'
        'Mude o status para "ARMANDO" para liberar a visualização.',
      );
      return;
    }

    // Entra em tela cheia logo no clique (navegador exige)
    final wasFullscreen = FullscreenService.isFullscreen;
    FullscreenService.enter();

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => _MediaViewerDialog(elemento: elemento),
    );

    // Restaura se não estava em tela cheia antes
    if (!wasFullscreen) {
      FullscreenService.exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pedido.localizador,
              style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
            ),
            Text(
              widget.pedido.cliente.nome,
              style: AppCss.minimumRegular
                  .setColor(AppColors.white.withValues(alpha: 0.8)),
            ),
            if (widget.pedido.descricao.isNotEmpty)
              Text(
                widget.pedido.descricao,
                style: AppCss.minimumRegular
                    .setSize(11)
                    .setColor(AppColors.white.withValues(alpha: 0.65)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        actions: [
          FullscreenButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Aguarde, carregando elementos...',
                      style: AppCss.mediumRegular),
                ],
              ),
            )
          // Usa APENAS elementosStream (protegido pelo lock anti-flickering).
          // O StreamOut<List<PedidoModel>> foi removido pois o Realtime de pedidos
          // disparava fora do lock, causando flicker no header e nos cards.
          : StreamOut<List<ElementoModel>>(
              stream: armacaoCtrl.elementosStream.listen,
              builder: (_, elementos) {
                final filtrados = elementos.where((e) {
                  if (e.isProntoParcial) {
                    return (_statusVisivel[ElementoStatus.armando] ?? true) ||
                        (_statusVisivel[ElementoStatus.pronto] ?? true);
                  }
                  return _statusVisivel[e.status] ?? true;
                }).toList();

                return Column(
                  children: [
                    _ResumoProducaoBar(
                      elementos: elementos,
                      statusVisivel: _statusVisivel,
                      onToggle: (status) => setState(() =>
                          _statusVisivel[status] =
                              !(_statusVisivel[status] ?? true)),
                    ),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const EmptyData(
                              message:
                                  'Nenhum elemento visível com os filtros ativos.')
                          : Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final screenWidth = constraints.maxWidth;
                                  final isSmall = screenWidth < 400;
                                  final padding = isSmall ? 12.0 : 24.0;
                                  final spacing = isSmall ? 12.0 : 20.0;
                                  // 2 cards/linha no mobile, 3-4 no desktop
                                  final maxExtent = isSmall ? 300.0 : 350.0;
                                  // Altura: label + barra segmentada + info cabe confortavelmente
                                  final mainExtent = isSmall ? 190.0 : 200.0;

                                  return GridView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.all(padding),
                                    gridDelegate:
                                        SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: maxExtent,
                                      mainAxisExtent: mainExtent,
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: spacing,
                                    ),
                                    itemCount: filtrados.length,
                                    itemBuilder: (context, index) {
                                      final elemento = filtrados[index];
                                      return _ElementoArmacaoCard(
                                        key: ValueKey(elemento.id),
                                        elemento: elemento,
                                        onStatusPressed: () async {
                                          // Para qtde > 1: sempre abre o dialog de quantidade.
                                          // A regra de fluxo (aguardando → armando, nunca pula para pronto)
                                          // é aplicada dentro do openProgressoParcialDirect.
                                          if (elemento.qtde > 1) {
                                            await armacaoCtrl
                                                .openProgressoParcialDirect(
                                                    widget.pedido, elemento);
                                          } else {
                                            await _showStatusPicker(elemento);
                                          }
                                        },
                                        onImagePressed: () =>
                                            _showImageDialog(elemento),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _showStatusPicker(ElementoModel elemento) async {
    final allowedStatuses = <ElementoStatus>[];
    if (elemento.status == ElementoStatus.aguardando) {
      allowedStatuses
          .addAll([ElementoStatus.aguardando, ElementoStatus.armando]);
    } else if (elemento.status == ElementoStatus.armando) {
      allowedStatuses.addAll([
        ElementoStatus.aguardando,
        ElementoStatus.armando,
        ElementoStatus.pronto
      ]);
    } else if (elemento.status == ElementoStatus.pronto) {
      allowedStatuses.addAll([ElementoStatus.armando, ElementoStatus.pronto]);
    }

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ALTERAR STATUS: ${elemento.nome}',
                style: AppCss.mediumBold
                    .setSize(18)
                    .setColor(AppColors.primaryMain),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'O fluxo deve obrigatoriamente passar por "Armando"',
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...allowedStatuses.map((status) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: elemento.status == status
                              ? status.color
                              : Colors.grey[200]!,
                          width: 1.5,
                        ),
                      ),
                      tileColor: elemento.status == status
                          ? status.backgroundColor
                          : Colors.transparent,
                      leading: CircleAvatar(
                        backgroundColor: status.color,
                        radius: 12,
                        child: elemento.status == status
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      title: Text(status.label, style: AppCss.mediumBold),
                      onTap: () async {
                        Navigator.pop(context);
                        await armacaoCtrl.updateElementoStatus(
                            widget.pedido, elemento, status);
                        // NÃO chamar setState aqui: a tela reage via StreamOut<elementosStream>
                        // O setState causava rebuild com closure stale, gerando flicker no PC (mouse).
                      },
                    ),
                  )),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCELAR',
                    style: AppCss.mediumBold.setColor(Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de resumo de produção.
/// Computa o resumo DIRETAMENTE de [elementos] (elementosStream),
/// que está protegido pelo lock anti-flickering do controller.
/// Não depende mais de pedido.armacaoResumo nem do Realtime de pedidos.
class _ResumoProducaoBar extends StatelessWidget {
  final List<ElementoModel> elementos;
  final Map<ElementoStatus, bool> statusVisivel;
  final ValueChanged<ElementoStatus> onToggle;
  const _ResumoProducaoBar({
    required this.elementos,
    required this.statusVisivel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Calcula resumo localmente — mesma lógica de updatePedidoSummary no controller
    int totalQtd = 0;
    double totalPeso = 0;
    double qtdAgu = 0, qtdArm = 0, qtdPronto = 0;
    double pesoAgu = 0, pesoArm = 0, pesoPronto = 0;

    for (final e in elementos) {
      totalQtd += e.qtde;
      totalPeso += e.pesoTotal;
      final ppUnit = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

      if (e.qtde == 1) {
        // qtde=1: status é a fonte de verdade
        switch (e.status) {
          case ElementoStatus.aguardando:
            qtdAgu += 1;
            pesoAgu += e.pesoTotal;
          case ElementoStatus.armando:
            qtdArm += 1;
            pesoArm += e.pesoTotal;
          case ElementoStatus.pronto:
            qtdPronto += 1;
            pesoPronto += e.pesoTotal;
        }
      } else {
        // qtde>1: contadores individuais são a fonte de verdade
        qtdPronto += e.qtdePronto;
        pesoPronto += e.qtdePronto * ppUnit;
        qtdArm += e.qtdeArmando;
        pesoArm += e.qtdeArmando * ppUnit;
        qtdAgu += e.qtdeAguardando;
        pesoAgu += e.qtdeAguardando * ppUnit;
      }
    }

    _Item agu = _Item(qtd: qtdAgu, peso: pesoAgu, totalQtd: totalQtd, totalPeso: totalPeso);
    _Item arm = _Item(qtd: qtdArm, peso: pesoArm, totalQtd: totalQtd, totalPeso: totalPeso);
    _Item pro = _Item(qtd: qtdPronto, peso: pesoPronto, totalQtd: totalQtd, totalPeso: totalPeso);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          _buildItem('AGUARDANDO', ElementoStatus.aguardando, agu),
          const SizedBox(width: 8),
          _buildItem('ARMANDO', ElementoStatus.armando, arm),
          const SizedBox(width: 8),
          _buildItem('PRONTO', ElementoStatus.pronto, pro),
        ],
      ),
    );
  }

  Widget _buildItem(String label, ElementoStatus status, _Item data) {
    final bool isVisible = statusVisivel[status] ?? true;
    final prcntQtd = data.prcntQtd;

    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isVisible ? status.backgroundColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isVisible ? Colors.black : Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          children: [
            // ── Cabeçalho com label + ícone visibilidade ──────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              color: isVisible ? Colors.grey[800] : Colors.grey[400],
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppCss.largeBold
                            .setSize(14)
                            .setColor(Colors.white),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onToggle(status),
                    child: Icon(
                      isVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // ── Dados: elementos e peso ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ELEM',
                          style: AppCss.largeBold.setSize(10).setColor(
                              isVisible ? Colors.black54 : Colors.grey[400]!)),
                      Text('KG',
                          style: AppCss.largeBold.setSize(10).setColor(
                              isVisible ? Colors.black54 : Colors.grey[400]!)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${data.qtd.toStringAsFixed(0)} (${prcntQtd.toStringAsFixed(0)}%)',
                          style: AppCss.largeBold.setSize(16).setColor(
                              isVisible ? Colors.black : Colors.grey[400]!),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.peso.toStringAsFixed(1),
                          style: AppCss.largeBold.setSize(16).setColor(
                              isVisible ? Colors.black : Colors.grey[400]!),
                        ),
                      ),
                    ],
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

/// DTO simples para evitar re-cálculo inline
class _Item {
  final double qtd;
  final double peso;
  final int totalQtd;
  final double totalPeso;
  const _Item({
    required this.qtd,
    required this.peso,
    required this.totalQtd,
    required this.totalPeso,
  });
  double get prcntQtd => totalQtd > 0 ? (qtd / totalQtd) * 100 : 0;
  double get prcntPeso => totalPeso > 0 ? (peso / totalPeso) * 100 : 0;
}

class _ElementoArmacaoCard extends StatelessWidget {
  final ElementoModel elemento;
  final VoidCallback onStatusPressed;
  final VoidCallback onImagePressed;

  const _ElementoArmacaoCard({
    super.key,
    required this.elemento,
    required this.onStatusPressed,
    required this.onImagePressed,
  });

  // Cor do card baseada nos contadores reais (qtde > 1)
  // Para qtde=1: usa status diretamente
  Color get _cardColor {
    if (elemento.qtde == 1) {
      if (elemento.status == ElementoStatus.pronto) return Colors.green[50]!;
      return elemento.status.backgroundColor;
    }
    // qtde > 1: derivado dos contadores
    if (elemento.qtdePronto >= elemento.qtde) return Colors.green[50]!; // tudo pronto
    if (elemento.qtdePronto > 0) return Colors.lime[50]!;             // algum pronto, não tudo
    if (elemento.qtdeArmando > 0) return Colors.yellow[50]!;          // só armando
    return Colors.grey[100]!;                                          // tudo aguardando
  }

  Color get _cardBorderColor {
    if (elemento.qtde == 1) {
      if (elemento.status == ElementoStatus.pronto) return Colors.green[700]!;
      if (elemento.status == ElementoStatus.armando) return Colors.amber[700]!;
      return Colors.grey[400]!;
    }
    // qtde > 1: derivado dos contadores
    if (elemento.qtdePronto >= elemento.qtde) return Colors.green[700]!;
    if (elemento.qtdePronto > 0) return Colors.lime[700]!;
    if (elemento.qtdeArmando > 0) return Colors.amber[700]!;
    return Colors.grey[400]!;
  }

  /// Label de status derivado dos contadores (para qtde > 1)
  String get _statusLabelCard {
    if (elemento.qtde == 1) return elemento.status.label.toUpperCase();
    if (elemento.qtdePronto >= elemento.qtde) return 'PRONTO';
    if (elemento.qtdePronto > 0 || elemento.qtdeArmando > 0) return 'ARMANDO';
    return 'AGUARDANDO';
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = elemento.qtde > 1 &&
        (elemento.qtdeArmando > 0 || elemento.qtdePronto > 0);

    return InkWell(
      onTap: onStatusPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            if (hasProgress) ...[
              // Label compacto — visivel acima da barra segmentada
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Text(
                  _statusLabelCard,
                  style: AppCss.largeBold
                      .setSize(16)
                      .setColor(Colors.black)
                      .copyWith(letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ),
              _buildSegmentedBar(),
              const Spacer(),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    _statusLabelCard,
                    style: AppCss.largeBold
                        .setSize(22)
                        .setColor(Colors.black)
                        .copyWith(letterSpacing: 1.5),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfo('QTDE', '${elemento.qtde} pc'),
                  _buildInfo(
                      'PESO', '${elemento.pesoTotal.toStringAsFixed(1)} kg'),
                  _buildInfo('OS', '${elemento.posicoes.length} os'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra segmentada: uma única barra com 3 cores proporcionais (pronto/armando/aguardando)
  Widget _buildSegmentedBar() {
    final qtde = elemento.qtde;
    final pronto = elemento.qtdePronto;
    final armando = elemento.qtdeArmando;
    final aguardando = elemento.qtdeAguardando;

    final corPronto = pronto >= qtde ? Colors.green[600]! : Colors.lime[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra segmentada
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  if (pronto > 0)
                    Expanded(
                      flex: pronto,
                      child: Container(color: corPronto),
                    ),
                  if (armando > 0)
                    Expanded(
                      flex: armando,
                      child: Container(color: Colors.amber[500]),
                    ),
                  if (aguardando > 0)
                    Expanded(
                      flex: aguardando,
                      child: Container(color: Colors.grey[300]),
                    ),
                  // fallback: se tudo zero (nunca deveria ocorrer)
                  if (pronto == 0 && armando == 0 && aguardando == 0)
                    Expanded(child: Container(color: Colors.grey[300])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Mini-legenda com bolinhas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pronto > 0) ...[
                _buildDot(corPronto),
                const SizedBox(width: 3),
                Text('$pronto pron.', style: _legendStyle),
              ],
              if (pronto > 0 && armando > 0) const SizedBox(width: 8),
              if (armando > 0) ...[
                _buildDot(Colors.amber[600]!),
                const SizedBox(width: 3),
                Text('$armando arm.', style: _legendStyle),
              ],
              if ((pronto > 0 || armando > 0) && aguardando > 0) const SizedBox(width: 8),
              if (aguardando > 0) ...[
                _buildDot(Colors.grey[400]!),
                const SizedBox(width: 3),
                Text('$aguardando agu.', style: _legendStyle),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _legendStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Color(0xFF555555),
  );

  Widget _buildDot(Color cor) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      );

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            elemento.nome.toUpperCase(),
            style: AppCss.largeBold.setSize(20).setColor(Colors.white),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (elemento.arquivos.isNotEmpty)
            Positioned(
              right: 0,
              child: GestureDetector(
                onTap: onImagePressed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${elemento.arquivos.length}',
                      style:
                          AppCss.mediumBold.setSize(14).setColor(Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.image_outlined,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppCss.largeBold
              .setSize(15)
              .setColor(Colors.black.withValues(alpha: 0.7)),
        ),
        Text(
          value,
          style: AppCss.largeBold.setSize(20).setColor(Colors.black),
        ),
      ],
    );
  }
}

class _MediaViewerDialog extends StatefulWidget {
  final ElementoModel elemento;
  const _MediaViewerDialog({required this.elemento});

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  void _close() {
    Navigator.pop(context);
  }

  void _openPdfViewer(BuildContext context, String title, String url) {
    final PdfControllerPinch controller = PdfControllerPinch(
      document: PdfDocument.openData(Dio()
          .get<List<int>>(url,
              options: Options(responseType: ResponseType.bytes))
          .then((r) => Uint8List.fromList(r.data!))),
    );

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PdfViewPinch(
              controller: controller,
              scrollDirection: Axis.vertical,
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(
                  loaderSwitchDuration: Duration(milliseconds: 100),
                ),
                documentLoaderBuilder: (_) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                pageLoaderBuilder: (_) => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
                errorBuilder: (_, error) => Center(
                    child: Text('Erro: $error',
                        style: const TextStyle(color: Colors.white))),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    controller.dispose();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 12),
                        Text('VOLTAR',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFull(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: InteractiveViewer(
          minScale: 0.1,
          maxScale: 10.0,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, prog) => prog == null
                  ? child
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elemento.arquivos.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF141423),
      body: Stack(
        children: [
          // ─── BACKGROUND DECOR ────────────────────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.architecture_rounded,
                  size: 400, color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),

          // ─── GRID CENTRAL DE ARQUIVOS ────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
              child: Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: widget.elemento.arquivos.map((arq) {
                  final isPdf = arq.extensao.toLowerCase() == 'pdf' ||
                      arq.tipo.contains('pdf');

                  return GestureDetector(
                    onTap: () {
                      if (isPdf) {
                        _openPdfViewer(context, arq.nome, arq.url);
                      } else {
                        _showImageFull(context, arq.url);
                      }
                    },
                    child: Container(
                      width: 220, // Cards bem grandes no meio da tela
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF23233D),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isPdf
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : Colors.blueAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isPdf
                                ? const Center(
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 70,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : Image.network(
                                    arq.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.white24,
                                        size: 40),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            arq.nome.toUpperCase(),
                            style: AppCss.mediumBold
                                .setSize(14)
                                .setColor(Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.open_in_new_rounded
                                    : Icons.fullscreen_rounded,
                                size: 16,
                                color: isPdf
                                    ? Colors.redAccent
                                    : Colors.blueAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isPdf ? 'ABRIR PDF' : 'VER IMAGEM',
                                style: AppCss.minimumBold.setSize(12).setColor(
                                    isPdf
                                        ? Colors.redAccent
                                        : Colors.blueAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ─── HEADER ───────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 24,
                right: 24,
                bottom: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF141423).withValues(alpha: 0.95),
                    const Color(0xFF141423).withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.elemento.nome.toUpperCase(),
                          style: AppCss.largeBold
                              .setSize(24)
                              .setColor(Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DESENHOS TÉCNICOS DISPONÍVEIS',
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(Colors.white.withValues(alpha: 0.5))
                              .copyWith(letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
