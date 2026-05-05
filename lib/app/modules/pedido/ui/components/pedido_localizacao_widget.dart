import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/models/pedido_box_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    final boxIds = FirestoreClient.boxes.data
                        .where((b) => b.patioId == p.id)
                        .map((b) => b.id)
                        .toSet();
                    final qtdAlocados = FirestoreClient.pedidoBoxes
                        .getByPedidoId(widget.pedido.id)
                        .where((a) => boxIds.contains(a.boxId))
                        .length;
                    final temPedido = qtdAlocados > 0;

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
                              : temPedido
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? AppColors.primaryMain
                                : temPedido
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.5)
                                    : const Color(0xFFE2E8F0),
                            width: sel ? 1.5 : temPedido ? 1.5 : 1,
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
                              temPedido && !sel ? Icons.check_circle_rounded : Icons.grid_view_rounded,
                              size: 14,
                              color: sel ? Colors.white : temPedido ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.nome,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel || temPedido ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : temPedido ? const Color(0xFF15803D) : const Color(0xFF475569),
                              ),
                            ),
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
              onAbrirMapa: _temLinkMapa(_patioSelecionado!) ? () => _abrirMapa(context, _patioSelecionado!) : null,
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

  bool _temLinkMapa(PatioModel p) {
    if (PreferencesService.modoMapa.value == 'geo') {
      return p.latitude != null && p.longitude != null;
    } else {
      return p.parqueX != null && p.parqueY != null;
    }
  }

  void _abrirMapa(BuildContext context, PatioModel p) async {
    if (PreferencesService.modoMapa.value == 'geo') {
      if (p.latitude != null && p.longitude != null) {
        final url = 'https://www.google.com/maps/place/${p.latitude},${p.longitude}/@${p.latitude},${p.longitude},21z/data=!3m1!1e3';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }
    } else {
      if (p.parqueX != null && p.parqueY != null) {
        showDialog(
          context: context,
          builder: (ctx) => _DialogCroquiParque(patioDestaque: p, localizador: widget.pedido.localizador),
        );
      }
    }
  }
}

// ── Mapa compacto de boxes clicáveis ──────────────────────────────────────────

class _MapaCompacto extends StatelessWidget {
  final PatioModel patio;
  final List<BoxModel> boxes;
  final Set<String> selecionados;
  final String localizador;
  final void Function(BoxModel) onToggle;
  final VoidCallback? onAbrirMapa;

  const _MapaCompacto({
    required this.patio,
    required this.boxes,
    required this.selecionados,
    required this.onToggle,
    required this.localizador,
    this.onAbrirMapa,
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
                              child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w900 : FontWeight.w700, color: sel ? box.color.withValues(alpha: 0.95) : lotado ? Colors.red.withValues(alpha: 0.6) : box.color, height: 1.3)),
                            );
                            Widget content;
                            if (vertical) {
                              content = Center(child: RotatedBox(quarterTurns: 1, child: Padding(padding: const EdgeInsets.all(2), child: textWidget)));
                            } else {
                              content = Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.all(2), child: textWidget));
                            }
                            if (sel && onAbrirMapa != null) {
                              return Stack(children: [
                                content,
                                Positioned(top: 2, right: 2, child: GestureDetector(
                                  onTap: onAbrirMapa,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: box.color.withValues(alpha: 0.85), shape: BoxShape.circle),
                                    child: Icon(PreferencesService.modoMapa.value == 'geo' ? Icons.map_rounded : Icons.grid_on_rounded, size: 16, color: Colors.white),
                                  ),
                                )),
                              ]);
                            }
                            return content;
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

class _DialogCroquiParque extends StatefulWidget {
  final PatioModel patioDestaque;
  final String localizador;
  const _DialogCroquiParque({required this.patioDestaque, required this.localizador});
  @override
  State<_DialogCroquiParque> createState() => _DialogCroquiParqueState();
}

class _DialogCroquiParqueState extends State<_DialogCroquiParque> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  static const _cores = [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFEC4899)];
  Color _corDoPatio(int i) => _cores[i % _cores.length];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 0.9).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final comp = PreferencesService.parqueComprimento.value;
    final larg = PreferencesService.parqueLargura.value;
    if (comp <= 0 || larg <= 0) return Dialog(child: Padding(padding: const EdgeInsets.all(32), child: Text('Parque n\u00e3o configurado.')));
    final patios = FirestoreClient.patios.data.where((p) => p.parqueX != null && p.parqueY != null).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        },
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: SizedBox(
            width: 1000, height: 800,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final maxH = constraints.maxHeight;
              final cellSize = (maxW / comp) < (maxH / larg) ? maxW / comp : maxH / larg;
              final totalW = cellSize * comp;
              final totalH = cellSize * larg;
              return Center(child: Container(
                width: totalW, height: totalH,
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(
                    size: Size(totalW, totalH),
                    painter: _ParqueGridPainter(comprimento: comp, largura: larg, cellSize: cellSize),
                    child: Stack(children: patios.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final cor = _corDoPatio(idx);
                      final isDestaque = p.id == widget.patioDestaque.id;
                      return Positioned(
                        left: p.parqueX! * cellSize, top: p.parqueY! * cellSize,
                        width: p.comprimento * cellSize, height: p.largura * cellSize,
                        child: isDestaque
                          ? AnimatedBuilder(animation: _pulseAnim, builder: (_, __) => Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: cor, width: 3),
                                boxShadow: [BoxShadow(color: cor.withValues(alpha: _pulseAnim.value), blurRadius: 12, spreadRadius: 2)],
                              ),
                              child: Stack(children: [
                                Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(4), child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(p.nome, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cor)),
                                  Text('${p.comprimento}m \u00d7 ${p.largura}m', style: TextStyle(fontSize: 9, color: cor.withValues(alpha: 0.7))),
                                ])))),
                                Positioned(top: 2, right: 4, child: Icon(Icons.location_on, size: 16, color: cor)),
                              ]),
                            ))
                          : Tooltip(
                              message: '${p.nome} (${p.comprimento}m \u00d7 ${p.largura}m)',
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: cor.withValues(alpha: 0.4), width: 1)),
                                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(4), child: Text(p.nome, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cor.withValues(alpha: 0.7)))))),
                              ),
                            ),
                      );
                    }).toList()),
                  ),
                ),
              ));
            }),
           ),
        ),
        ),
      ),
    );
  }
}

class _ParqueGridPainter extends CustomPainter {
  final int comprimento, largura;
  final double cellSize;
  _ParqueGridPainter({required this.comprimento, required this.largura, required this.cellSize});
  @override
  void paint(Canvas canvas, Size size) {
    final sw = (cellSize * 0.04).clamp(0.3, 1.5);
    final paint = Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = sw;
    for (int i = 0; i <= largura; i++) {
      canvas.drawLine(Offset(0, i * cellSize), Offset(size.width, i * cellSize), paint);
    }
    for (int i = 0; i <= comprimento; i++) {
      canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
