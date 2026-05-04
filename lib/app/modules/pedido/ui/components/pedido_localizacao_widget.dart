import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/models/pedido_box_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PedidoLocalizacaoWidget extends StatefulWidget {
  final PedidoModel pedido;
  const PedidoLocalizacaoWidget(this.pedido, {super.key});

  @override
  State<PedidoLocalizacaoWidget> createState() =>
      _PedidoLocalizacaoWidgetState();
}

class _PedidoLocalizacaoWidgetState extends State<PedidoLocalizacaoWidget> {
  PatioModel? _patioSelecionado;
  bool _salvando = false;
  final _patioScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarPatioAtual();
  }

  @override
  void dispose() {
    _patioScrollCtrl.dispose();
    super.dispose();
  }

  void _carregarPatioAtual() {
    final alocacoes =
        FirestoreClient.pedidoBoxes.getByPedidoId(widget.pedido.id);
    if (alocacoes.isEmpty) return;

    final allBoxes = FirestoreClient.boxes.data;
    final primeiroBox =
        allBoxes.where((b) => b.id == alocacoes.first.boxId).firstOrNull;
    if (primeiroBox == null) return;

    final patio = FirestoreClient.patios.data
        .where((p) => p.id == primeiroBox.patioId)
        .firstOrNull;
    if (patio != null) {
      setState(() => _patioSelecionado = patio);
    }
  }

  /// Boxes do pátio selecionado que estão alocados para ESTE pedido (dados do banco).
  Set<String> get _boxesSalvosNoPatio {
    if (_patioSelecionado == null) return {};
    final alocacoes =
        FirestoreClient.pedidoBoxes.getByPedidoId(widget.pedido.id);
    final boxIdsDoPatio =
        FirestoreClient.boxes.data
            .where((b) => b.patioId == _patioSelecionado!.id)
            .map((b) => b.id)
            .toSet();
    return alocacoes
        .map((a) => a.boxId)
        .where((id) => boxIdsDoPatio.contains(id))
        .toSet();
  }

  List<BoxModel> get _boxesDoPatio {
    if (_patioSelecionado == null) return [];
    return FirestoreClient.boxes.data
        .where((b) => b.patioId == _patioSelecionado!.id)
        .toList();
  }

  bool _saoAdjacentes(List<BoxModel> boxes) {
    if (boxes.length <= 1) return true;
    final visitados = <String>{boxes.first.id};
    final fila = [boxes.first];
    while (fila.isNotEmpty) {
      final atual = fila.removeAt(0);
      for (final outro in boxes) {
        if (visitados.contains(outro.id)) continue;
        if (_toca(atual, outro)) {
          visitados.add(outro.id);
          fila.add(outro);
        }
      }
    }
    return visitados.length == boxes.length;
  }

  bool _toca(BoxModel a, BoxModel b) {
    final tocaH = (a.x + a.comprimento == b.x || b.x + b.comprimento == a.x) &&
        a.y < b.y + b.largura &&
        b.y < a.y + a.largura;
    final tocaV = (a.y + a.largura == b.y || b.y + b.largura == a.y) &&
        a.x < b.x + b.comprimento &&
        b.x < a.x + a.comprimento;
    return tocaH || tocaV;
  }

  /// Verifica se há alocações deste pedido em OUTROS pátios.
  /// Retorna nomes dos pátios, ou lista vazia se não houver.
  List<String> _nomesPatiosAnteriores() {
    final alocacoes =
        FirestoreClient.pedidoBoxes.getByPedidoId(widget.pedido.id);
    if (alocacoes.isEmpty) return [];

    final allBoxes = FirestoreClient.boxes.data;
    final patioIds = <String>{};
    for (final a in alocacoes) {
      final box = allBoxes.where((b) => b.id == a.boxId).firstOrNull;
      if (box != null && box.patioId != _patioSelecionado?.id) {
        patioIds.add(box.patioId);
      }
    }

    return patioIds
        .map((pid) =>
            FirestoreClient.patios.data
                .where((p) => p.id == pid)
                .firstOrNull
                ?.nome ??
            'Pátio')
        .toList();
  }

  Future<void> _toggleBox(BoxModel box) async {
    if (_salvando) return;

    final salvos = _boxesSalvosNoPatio;

    // ── Desmarcar ──
    if (salvos.contains(box.id)) {
      setState(() => _salvando = true);
      try {
        final alocacao = FirestoreClient.pedidoBoxes.data.where(
            (pb) => pb.boxId == box.id && pb.pedidoId == widget.pedido.id);
        for (final a in alocacao.toList()) {
          await FirestoreClient.pedidoBoxes.delete(a);
        }
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
      return;
    }

    // ── Marcar: verificar capacidade do box ──
    final ocupantes = FirestoreClient.pedidoBoxes.data
        .where((pb) => pb.boxId == box.id && pb.pedidoId != widget.pedido.id)
        .toList();

    if (ocupantes.length >= box.maxPedidos) {
      final nomes = ocupantes.map((a) {
        final p = FirestoreClient.pedidos.data
            .where((p) => p.id == a.pedidoId)
            .firstOrNull;
        return p?.localizador ?? '—';
      }).join(', ');
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Box lotado', textAlign: TextAlign.center),
          content: Text(
            'Este box comporta no máximo ${box.maxPedidos} pedido${box.maxPedidos > 1 ? 's' : ''} '
            'e já está com: $nomes.\n\nEscolha outro box ou aumente a capacidade.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    // ── Verificar adjacência ──
    final tentativa = {...salvos, box.id};
    final boxesTentativa =
        _boxesDoPatio.where((b) => tentativa.contains(b.id)).toList();
    if (!_saoAdjacentes(boxesTentativa)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title:
              const Text('Seleção Inválida', textAlign: TextAlign.center),
          content: const Text(
            'Os boxes precisam ser adjacentes (vizinhos).\nVocê não pode pular espaços.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    // ── Verificar se já tem alocação em outro pátio ──
    final patiosAnteriores = _nomesPatiosAnteriores();
    if (patiosAnteriores.isNotEmpty && salvos.isEmpty) {
      // Primeiro box neste pátio, mas já existe em outro
      final nomes = patiosAnteriores.join(', ');
      if (!mounted) return;

      final escolha = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon:
              Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Pedido já alocado',
              textAlign: TextAlign.center),
          content: Text(
            'Este pedido já está alocado no pátio $nomes.\n\nO que deseja fazer?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'descartar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
              ),
              child: const Text('Descartar anterior'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'ambos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
              child: const Text('Alocar em ambos'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (escolha == null) return; // cancelou

      if (escolha == 'descartar') {
        // Remove alocações de outros pátios
        setState(() => _salvando = true);
        try {
          final boxIdsDoPatio =
              _boxesDoPatio.map((b) => b.id).toSet();
          final alocacoes =
              FirestoreClient.pedidoBoxes.getByPedidoId(widget.pedido.id);
          for (final a in alocacoes) {
            if (!boxIdsDoPatio.contains(a.boxId)) {
              await FirestoreClient.pedidoBoxes.delete(a);
            }
          }
        } finally {
          if (mounted) setState(() => _salvando = false);
        }
      }
      // Se 'ambos' → simplesmente continua e adiciona
    }

    // ── Salvar o novo box ──
    setState(() => _salvando = true);
    try {
      final model = PedidoBoxModel(
        id: HashService.get,
        pedidoId: widget.pedido.id,
        boxId: box.id,
        createdAt: DateTime.now(),
      );
      await FirestoreClient.pedidoBoxes.add(model);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PatioModel>>(
      stream: FirestoreClient.patios.dataStream.listen,
      builder: (_, patios) => StreamOut<List<BoxModel>>(
        stream: FirestoreClient.boxes.dataStream.listen,
        builder: (_, __) => StreamOut<List<PedidoBoxModel>>(
          stream: FirestoreClient.pedidoBoxes.dataStream.listen,
          builder: (_, ___) => _buildConteudo(patios),
        ),
      ),
    );
  }

  Widget _buildConteudo(List<PatioModel> patios) {
    if (patios.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Nenhum pátio cadastrado.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      );
    }

    final salvos = _boxesSalvosNoPatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Seletor de Pátio ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Text(
                'PÁTIO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: Scrollbar(
                  controller: _patioScrollCtrl,
                  thumbVisibility: true,
                  thickness: 3,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _patioScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                    children: patios.map((p) {
                    final sel = _patioSelecionado?.id == p.id;
                    // Contar boxes com alocação deste pedido neste pátio
                    final boxIds = FirestoreClient.boxes.data
                        .where((b) => b.patioId == p.id)
                        .map((b) => b.id)
                        .toSet();
                    final qtdAlocados = FirestoreClient.pedidoBoxes
                        .getByPedidoId(widget.pedido.id)
                        .where((a) => boxIds.contains(a.boxId))
                        .length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                      onTap: () {
                        if (_patioSelecionado?.id == p.id) return;
                        setState(() => _patioSelecionado = p);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primaryMain
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? AppColors.primaryMain
                                : const Color(0xFFE2E8F0),
                            width: sel ? 1.5 : 1,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryMain
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 14,
                              color:
                                  sel ? Colors.white : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.nome,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                            if (p.latitude != null && p.longitude != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final url =
                                      'https://www.google.com/maps/search/${p.latitude},${p.longitude}/@${p.latitude},${p.longitude},21z/data=!3m1!1e3';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url),
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : AppColors.primaryMain
                                            .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.map_rounded,
                                    size: 14,
                                    color: sel ? Colors.white : AppColors.primaryMain,
                                  ),
                                ),
                              ),
                            ],
                            if (qtdAlocados > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : const Color(0xFF16A34A)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$qtdAlocados',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ),
                    );
                  }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Indicador de salvamento ──
        if (_salvando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),

        // ── Mapa compacto ──
        if (_patioSelecionado != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MapaCompacto(
              patio: _patioSelecionado!,
              boxes: _boxesDoPatio,
              selecionados: salvos,
              onToggle: _toggleBox,
              localizador: widget.pedido.localizador,
            ),
          ),

          // ── Legenda dos boxes selecionados ──
          if (salvos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 6,
                children: _boxesDoPatio
                    .where((b) => salvos.contains(b.id))
                    .map((b) => Chip(
                          label: Text('Box ${b.nome}',
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor:
                              b.color.withValues(alpha: 0.15),
                          side: BorderSide(
                              color: b.color.withValues(alpha: 0.4)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _toggleBox(b),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Mapa compacto de boxes clicáveis ──────────────────────────────────────────

class _MapaCompacto extends StatelessWidget {
  final PatioModel patio;
  final List<BoxModel> boxes;
  final Set<String> selecionados;
  final String localizador;
  final void Function(BoxModel) onToggle;

  const _MapaCompacto({
    required this.patio,
    required this.boxes,
    required this.selecionados,
    required this.onToggle,
    required this.localizador,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cellSize = maxW / patio.comprimento;
        final alturaTotal = cellSize * patio.largura;

        return Container(
          height: alturaTotal,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: CustomPaint(
              size: Size(maxW, alturaTotal),
              painter: _MapaCompactoPainter(
                patio: patio,
                boxes: boxes,
                selecionados: selecionados,
                cellSize: cellSize,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: boxes.map((box) {
                  final sel = selecionados.contains(box.id);

                  // Pedidos de outros alocados neste box
                  final outrosAlocados = FirestoreClient.pedidoBoxes.data
                      .where((pb) => pb.boxId == box.id)
                      .map((pb) {
                        final p = FirestoreClient.pedidos.data
                            .where((p) => p.id == pb.pedidoId)
                            .firstOrNull;
                        return p?.localizador ?? '—';
                      })
                      .toList();

                  // Monta label
                  String label = 'Box ${box.nome}';
                  if (sel) {
                    label += '\n$localizador';
                  }
                  if (outrosAlocados.isNotEmpty && !sel) {
                    label += '\n${outrosAlocados.join(', ')}';
                  } else if (outrosAlocados.length > 1 || (outrosAlocados.isNotEmpty && sel)) {
                    // Mostra os outros que não são este pedido
                    final outros = outrosAlocados.where((l) => l != localizador).toList();
                    if (outros.isNotEmpty) {
                      label += '\n${outros.join(', ')}';
                    }
                  }

                  final lotado = outrosAlocados.length >= box.maxPedidos && !sel;

                  return Positioned(
                    left: box.x * cellSize,
                    top: box.y * cellSize,
                    width: box.comprimento * cellSize,
                    height: box.largura * cellSize,
                    child: GestureDetector(
                      onTap: () => onToggle(box),
                      child: Tooltip(
                        message: 'Box ${box.nome} (${outrosAlocados.length}/${box.maxPedidos})',
                        child: Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: sel
                                ? box.color.withValues(alpha: 0.4)
                                : lotado
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : box.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: sel
                                  ? box.color
                                  : lotado
                                      ? Colors.red.withValues(alpha: 0.4)
                                      : box.color.withValues(alpha: 0.4),
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: Builder(builder: (_) {
                            final w = box.comprimento * cellSize;
                            final h = box.largura * cellSize;
                            final vertical = h > w * 1.3;

                            final textWidget = FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      sel ? FontWeight.w900 : FontWeight.w700,
                                  color: sel
                                      ? box.color.withValues(alpha: 0.95)
                                      : lotado
                                          ? Colors.red.withValues(alpha: 0.6)
                                          : box.color,
                                  height: 1.3,
                                ),
                              ),
                            );

                            if (vertical) {
                              return Center(
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: textWidget,
                                  ),
                                ),
                              );
                            }

                            return Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: textWidget,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapaCompactoPainter extends CustomPainter {
  final PatioModel patio;
  final List<BoxModel> boxes;
  final Set<String> selecionados;
  final double cellSize;

  _MapaCompactoPainter({
    required this.patio,
    required this.boxes,
    required this.selecionados,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.3;
    for (int i = 0; i <= patio.largura; i++) {
      canvas.drawLine(
          Offset(0, i * cellSize), Offset(size.width, i * cellSize), gridPaint);
    }
    for (int i = 0; i <= patio.comprimento; i++) {
      canvas.drawLine(
          Offset(i * cellSize, 0), Offset(i * cellSize, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
