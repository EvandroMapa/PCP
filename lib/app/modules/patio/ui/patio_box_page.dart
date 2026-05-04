import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/models/pedido_box_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/patio/box_controller.dart';
import 'package:flutter/material.dart';

class PatioBoxPage extends StatelessWidget {
  const PatioBoxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PatioModel>>(
      stream: FirestoreClient.patios.dataStream.listen,
      builder: (_, patios) => StreamOut<List<BoxModel>>(
        stream: FirestoreClient.boxes.dataStream.listen,
        builder: (_, boxes) => StreamOut<List<PedidoBoxModel>>(
          stream: FirestoreClient.pedidoBoxes.dataStream.listen,
          builder: (_, __) => StreamOutNull<PatioModel>(
            stream: boxCtrl.selectedPatioStream.listen,
            child: (_, selectedPatio) => StreamOutNull<BoxModel>(
              stream: boxCtrl.selectedBoxStream.listen,
              child: (_, selectedBox) => _PatioBoxLayout(
                patios: patios,
                boxes: boxes,
                selectedPatio: selectedPatio,
                selectedBox: selectedBox,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatioBoxLayout extends StatelessWidget {
  final List<PatioModel> patios;
  final List<BoxModel> boxes;
  final PatioModel? selectedPatio;
  final BoxModel? selectedBox;

  const _PatioBoxLayout({
    required this.patios,
    required this.boxes,
    required this.selectedPatio,
    required this.selectedBox,
  });

  @override
  Widget build(BuildContext context) {
    final boxesDoPatio = selectedPatio != null
        ? boxCtrl.getBoxesDoPatio(selectedPatio!.id, boxes)
        : <BoxModel>[];

    return Row(
      children: [
        // ── Coluna esquerda ────────────────────────────────────────────────
        SizedBox(
          width: 268,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Pátios ─────────────────────────────────────────
                _ColHeader(
                  title: 'Pátios',
                  icon: Icons.grid_view_rounded,
                  badge: patios.length,
                ),
                Flexible(
                  flex: patios.length > 4 ? 2 : 1,
                  child: patios.isEmpty
                      ? const _EmptyHint(text: 'Nenhum pátio cadastrado')
                      : ListView.builder(
                          itemCount: patios.length,
                          itemBuilder: (_, i) => _PatioItem(
                            patio: patios[i],
                            selecionado: selectedPatio?.id == patios[i].id,
                            boxCount: boxCtrl
                                .getBoxesDoPatio(patios[i].id, boxes)
                                .length,
                            onTap: () => boxCtrl.selectPatio(patios[i]),
                          ),
                        ),
                ),
                // ── Divider ───────────────────────────────────────────────
                if (selectedPatio != null)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                // ── Header Boxes ──────────────────────────────────────────
                if (selectedPatio != null) ...[
                  _ColHeader(
                    title: 'Boxes',
                    subtitle: selectedPatio!.nome,
                    icon: Icons.dashboard_customize_rounded,
                    badge: boxesDoPatio.length,
                  ),
                  Expanded(
                    child: boxesDoPatio.isEmpty
                        ? const _EmptyHint(
                            text: 'Arraste no mapa\npara criar boxes',
                            icon: Icons.touch_app_outlined,
                          )
                        : _BoxListComScrollbar(
                            boxes: boxesDoPatio,
                            selectedBox: selectedBox,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Mapa (2/3) ────────────────────────────────────────────────────
        Expanded(
          child: selectedPatio == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Selecione um pátio para visualizar o mapa',
                        style: AppCss.mediumRegular
                            .setColor(Colors.grey[400]!),
                      ),
                    ],
                  ),
                )
              : _PatioMapEditor(
                  patio: selectedPatio!,
                  boxes: boxesDoPatio,
                  selectedBox: selectedBox,
                  onCreateBox: (x, y, comp, larg) => boxCtrl.onCreateBox(
                    context: context,
                    patioId: selectedPatio!.id,
                    x: x,
                    y: y,
                    comprimento: comp,
                    largura: larg,
                  ),
                  onMoveBox: (box, nx, ny) => boxCtrl.onMoveBox(box, nx, ny),
                  onSelectBox: (box) => boxCtrl.selectBox(box),
                ),
        ),
      ],
    );
  }

  void _mostrarDicaCriar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.info_outline, color: Colors.blue, size: 36),
        title: const Text('Como criar um Box'),
        content: const Text(
          'Clique e arraste no mapa para desenhar a área do box.\n\n'
          'Após soltar, você poderá dar um nome e escolher a cor.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain),
            child: const Text('Entendi',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares da coluna esquerda ───────────────────────────────────

class _ColHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final int? badge;

  const _ColHeader({
    required this.title,
    required this.icon,
    this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF4F8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDDE3EA), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13, // 11 -> 13
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.4,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12, // 10 -> 12
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (badge != null && badge! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  fontSize: 12, // 10 -> 12
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const _EmptyHint({
    required this.text,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFADB5C4),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatioItem extends StatelessWidget {
  final PatioModel patio;
  final bool selecionado;
  final int boxCount;
  final VoidCallback onTap;
  const _PatioItem({
      required this.patio,
      required this.selecionado,
      required this.boxCount,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primaryMain.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selecionado ? AppColors.primaryMain : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selecionado
                    ? AppColors.primaryMain.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 15,
                color: selecionado
                    ? AppColors.primaryMain
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    patio.nome,
                    style: TextStyle(
                      fontSize: 14, // 12 -> 14
                      fontWeight: FontWeight.w600,
                      color: selecionado
                          ? AppColors.primaryMain
                          : const Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${patio.comprimento}m × ${patio.largura}m',
                    style: const TextStyle(
                      fontSize: 12, // 10 -> 12
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (selecionado)
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.primaryMain)
            else if (boxCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$boxCount',
                  style: TextStyle(
                    fontSize: 12, // 10 -> 12
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryMain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _BoxListComScrollbar extends StatefulWidget {
  final List<BoxModel> boxes;
  final BoxModel? selectedBox;
  const _BoxListComScrollbar({required this.boxes, required this.selectedBox});

  @override
  State<_BoxListComScrollbar> createState() => _BoxListComScrollbarState();
}

class _BoxListComScrollbarState extends State<_BoxListComScrollbar> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(4),
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: widget.boxes.length,
        itemBuilder: (_, i) => _BoxItem(
          box: widget.boxes[i],
          selecionado: widget.selectedBox?.id == widget.boxes[i].id,
          onTap: () => boxCtrl.selectBox(widget.boxes[i]),
          onEdit: () => boxCtrl.onEditBox(context, widget.boxes[i]),
          onDelete: () => boxCtrl.onDeleteBox(context, widget.boxes[i]),
        ),
      ),
    );
  }
}

class _BoxItem extends StatelessWidget {

  final BoxModel box;
  final bool selecionado;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BoxItem({
    required this.box,
    required this.selecionado,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: selecionado
              ? box.color.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selecionado ? box.color : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Quadrado de cor
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: box.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: box.color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  box.nome,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: box.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Box ${box.nome} - ${box.comprimento}×${box.largura}m',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'máx. ${box.maxPedidos} pedido${box.maxPedidos > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Botão editar
            Tooltip(
              message: 'Editar Box ${box.nome}',
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Botão excluir
            Tooltip(
              message: 'Excluir Box ${box.nome}',
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor de Mapa ──────────────────────────────────────────────────────────

enum _MapMode { idle, drawing, dragging }

class _PatioMapEditor extends StatefulWidget {
  final PatioModel patio;
  final List<BoxModel> boxes;
  final BoxModel? selectedBox;
  final void Function(int x, int y, int comprimento, int largura) onCreateBox;
  final void Function(BoxModel box, int newX, int newY) onMoveBox;
  final void Function(BoxModel? box) onSelectBox;

  const _PatioMapEditor({
    required this.patio,
    required this.boxes,
    required this.selectedBox,
    required this.onCreateBox,
    required this.onMoveBox,
    required this.onSelectBox,
  });

  @override
  State<_PatioMapEditor> createState() => _PatioMapEditorState();
}

class _PatioMapEditorState extends State<_PatioMapEditor> {
  _MapMode _mode = _MapMode.idle;

  // Desenho de novo box
  Point<int>? _drawStart;
  Point<int>? _drawCurrent;

  // Arrasto de box existente
  BoxModel? _draggingBox;
  Point<int>? _dragOffset; // offset do toque dentro do box

  double _cellSize = 20;

  /// Monta mapa boxId → localizadores para exibição no mapa
  Map<String, String> _buildAlocacoes() {
    final result = <String, String>{};
    final boxIds = widget.boxes.map((b) => b.id).toSet();
    final alocacoes = FirestoreClient.pedidoBoxes.data
        .where((pb) => boxIds.contains(pb.boxId));

    final porBox = <String, List<String>>{};
    for (final a in alocacoes) {
      final pedido = FirestoreClient.pedidos.data
          .where((p) => p.id == a.pedidoId)
          .firstOrNull;
      final loc = pedido?.localizador ?? '—';
      porBox.putIfAbsent(a.boxId, () => []).add(loc);
    }

    for (final entry in porBox.entries) {
      result[entry.key] = entry.value.join(', ');
    }
    return result;
  }

  Point<int> _toCell(Offset local) {
    final x = (local.dx / _cellSize).floor().clamp(0, widget.patio.comprimento - 1);
    final y = (local.dy / _cellSize).floor().clamp(0, widget.patio.largura - 1);
    return Point(x, y);
  }

  BoxModel? _boxAt(Point<int> cell) {
    for (final b in widget.boxes) {
      if (cell.x >= b.x &&
          cell.x < b.x + b.comprimento &&
          cell.y >= b.y &&
          cell.y < b.y + b.largura) {
        return b;
      }
    }
    return null;
  }

  Rect _previewRect() {
    if (_drawStart == null || _drawCurrent == null) return Rect.zero;
    final x1 = _drawStart!.x < _drawCurrent!.x ? _drawStart!.x : _drawCurrent!.x;
    final y1 = _drawStart!.y < _drawCurrent!.y ? _drawStart!.y : _drawCurrent!.y;
    final x2 = _drawStart!.x > _drawCurrent!.x ? _drawStart!.x : _drawCurrent!.x;
    final y2 = _drawStart!.y > _drawCurrent!.y ? _drawStart!.y : _drawCurrent!.y;
    return Rect.fromLTWH(x1.toDouble(), y1.toDouble(),
        (x2 - x1 + 1).toDouble(), (y2 - y1 + 1).toDouble());
  }

  Rect? _dragPreviewRect() {
    if (_draggingBox == null || _dragOffset == null || _drawCurrent == null) {
      return null;
    }
    final nx = (_drawCurrent!.x - _dragOffset!.x)
        .clamp(0, widget.patio.comprimento - _draggingBox!.comprimento);
    final ny = (_drawCurrent!.y - _dragOffset!.y)
        .clamp(0, widget.patio.largura - _draggingBox!.largura);
    return Rect.fromLTWH(nx.toDouble(), ny.toDouble(),
        _draggingBox!.comprimento.toDouble(), _draggingBox!.largura.toDouble());
  }

  bool _previewValido() {
    if (_mode == _MapMode.drawing) {
      final r = _previewRect();
      return boxCtrl.posicaoValida(
        excluirId: null,
        x: r.left.toInt(),
        y: r.top.toInt(),
        comprimento: r.width.toInt(),
        largura: r.height.toInt(),
        boxes: widget.boxes,
        patio: widget.patio,
      );
    }
    if (_mode == _MapMode.dragging) {
      final r = _dragPreviewRect();
      if (r == null) return false;
      return boxCtrl.posicaoValida(
        excluirId: _draggingBox?.id,
        x: r.left.toInt(),
        y: r.top.toInt(),
        comprimento: r.width.toInt(),
        largura: r.height.toInt(),
        boxes: widget.boxes,
        patio: widget.patio,
      );
    }
    return true;
  }

  void _onPanStart(DragStartDetails d) {
    final cell = _toCell(d.localPosition);
    final box = _boxAt(cell);
    if (box != null) {
      setState(() {
        _mode = _MapMode.dragging;
        _draggingBox = box;
        _dragOffset = Point(cell.x - box.x, cell.y - box.y);
        _drawCurrent = cell;
      });
      widget.onSelectBox(box);
    } else {
      setState(() {
        _mode = _MapMode.drawing;
        _drawStart = cell;
        _drawCurrent = cell;
      });
      widget.onSelectBox(null);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final cell = _toCell(d.localPosition);
    setState(() => _drawCurrent = cell);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_mode == _MapMode.drawing) {
      final r = _previewRect();
      if (_previewValido() && r.width > 0 && r.height > 0) {
        widget.onCreateBox(
            r.left.toInt(), r.top.toInt(), r.width.toInt(), r.height.toInt());
      }
    } else if (_mode == _MapMode.dragging && _draggingBox != null) {
      final r = _dragPreviewRect();
      if (r != null && _previewValido()) {
        widget.onMoveBox(_draggingBox!, r.left.toInt(), r.top.toInt());
      }
    }
    setState(() {
      _mode = _MapMode.idle;
      _drawStart = null;
      _drawCurrent = null;
      _draggingBox = null;
      _dragOffset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralLightest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do mapa
            Row(
              children: [
                Icon(Icons.map_outlined, size: 16, color: AppColors.primaryMain),
                const SizedBox(width: 6),
                Text(
                  widget.patio.nome,
                  style: AppCss.mediumBold.setColor(AppColors.primaryMain),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.patio.comprimento}m × ${widget.patio.largura}m',
                    style:
                        AppCss.minimumBold.setColor(AppColors.primaryMain),
                  ),
                ),
                const Spacer(),
                Text(
                  'Arraste para criar ou mover boxes',
                  style:
                      AppCss.minimumRegular.setColor(Colors.grey[400]!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Mapa
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellByW =
                      constraints.maxWidth / widget.patio.comprimento;
                  final cellByH =
                      constraints.maxHeight / widget.patio.largura;
                  _cellSize = cellByW < cellByH ? cellByW : cellByH;
                  final gw = _cellSize * widget.patio.comprimento;
                  final gh = _cellSize * widget.patio.largura;

                  final previewR = _mode == _MapMode.drawing ? _previewRect() : null;
                  final dragR = _mode == _MapMode.dragging ? _dragPreviewRect() : null;
                  final valido = _previewValido();

                  return Center(
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        width: gw,
                        height: gh,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            size: Size(gw, gh),
                            painter: _MapPainter(
                              patio: widget.patio,
                              boxes: widget.boxes,
                              selectedBoxId: widget.selectedBox?.id,
                              cellSize: _cellSize,
                              previewRect: previewR,
                              dragRect: dragR,
                              dragColor: _draggingBox?.color,
                              isValid: valido,
                              alocacoesPorBox: _buildAlocacoes(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Point<T extends num> {
  final T x;
  final T y;
  const Point(this.x, this.y);
}

// ── CustomPainter ───────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  final PatioModel patio;
  final List<BoxModel> boxes;
  final String? selectedBoxId;
  final double cellSize;
  final Rect? previewRect;
  final Rect? dragRect;
  final Color? dragColor;
  final bool isValid;
  final Map<String, String> alocacoesPorBox;

  _MapPainter({
    required this.patio,
    required this.boxes,
    required this.selectedBoxId,
    required this.cellSize,
    this.previewRect,
    this.dragRect,
    this.dragColor,
    required this.isValid,
    required this.alocacoesPorBox,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = patio.comprimento * cellSize;
    final H = patio.largura * cellSize;

    // Fundo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..color = const Color(0xFFF8FAFC),
    );

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= patio.largura; i++) {
      canvas.drawLine(Offset(0, i * cellSize), Offset(W, i * cellSize), gridPaint);
    }
    for (int i = 0; i <= patio.comprimento; i++) {
      canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, H), gridPaint);
    }

    // Boxes existentes
    for (final box in boxes) {
      final isSelecionado = box.id == selectedBoxId;

      // Não desenhar o box sendo arrastado (substitui pelo dragRect)
      final rect = Rect.fromLTWH(
        box.x * cellSize,
        box.y * cellSize,
        box.comprimento * cellSize,
        box.largura * cellSize,
      );

      // Fundo do box
      canvas.drawRect(
        rect.deflate(1),
        Paint()..color = box.color.withValues(alpha: isSelecionado ? 0.45 : 0.20),
      );

      // Glow externo se selecionado
      if (isSelecionado) {
        canvas.drawRect(
          rect.inflate(2),
          Paint()
            ..color = box.color.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Borda
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = box.color
          ..strokeWidth = isSelecionado ? 3.0 : 1.5
          ..style = PaintingStyle.stroke,
      );

      // Badge de seleção (check) no canto superior direito
      if (isSelecionado) {
        final badgeSize = (cellSize * 0.35).clamp(10.0, 18.0);
        final badgeCenter = Offset(
          rect.right - badgeSize * 0.7,
          rect.top + badgeSize * 0.7,
        );
        canvas.drawCircle(
          badgeCenter,
          badgeSize * 0.55,
          Paint()..color = box.color,
        );
        // Desenha o check
        final checkPath = Path();
        final s = badgeSize * 0.25;
        checkPath.moveTo(badgeCenter.dx - s, badgeCenter.dy);
        checkPath.lineTo(badgeCenter.dx - s * 0.2, badgeCenter.dy + s * 0.7);
        checkPath.lineTo(badgeCenter.dx + s, badgeCenter.dy - s * 0.5);
        canvas.drawPath(
          checkPath,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }

      // Nome do box + localizadores
      if (cellSize * box.comprimento > 30 && cellSize * box.largura > 16) {
        final localizador = alocacoesPorBox[box.id];
        final texto = localizador != null
            ? '${box.nome}\n$localizador'
            : box.nome;

        final w = box.comprimento * cellSize;
        final h = box.largura * cellSize;
        final vertical = h > w * 1.3;

        final tp = TextPainter(
          text: TextSpan(
            text: texto,
            style: TextStyle(
              color: isSelecionado
                  ? box.color
                  : box.color.withValues(alpha: 0.9),
              fontSize: (cellSize * 0.30).clamp(7, 12),
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );

        if (vertical) {
          // Rotaciona 90° → usar h como maxWidth
          tp.layout(maxWidth: h - 4);
          canvas.save();
          final cx = rect.left + w / 2;
          final cy = rect.top + h / 2;
          canvas.translate(cx, cy);
          canvas.rotate(3.14159 / 2); // 90°
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        } else {
          tp.layout(maxWidth: w - 4);
          tp.paint(
            canvas,
            Offset(
              rect.left + (w - tp.width) / 2,
              rect.top + (h - tp.height) / 2,
            ),
          );
        }
      }
    }

    // Preview: novo box sendo desenhado
    if (previewRect != null) {
      final r = Rect.fromLTWH(
        previewRect!.left * cellSize,
        previewRect!.top * cellSize,
        previewRect!.width * cellSize,
        previewRect!.height * cellSize,
      );
      final cor = isValid ? const Color(0xFF3B82F6) : Colors.red;
      canvas.drawRect(r.deflate(1),
          Paint()..color = cor.withValues(alpha: 0.20));
      canvas.drawRect(
          r.deflate(1),
          Paint()
            ..color = cor
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }

    // Preview: box sendo arrastado
    if (dragRect != null && dragColor != null) {
      final r = Rect.fromLTWH(
        dragRect!.left * cellSize,
        dragRect!.top * cellSize,
        dragRect!.width * cellSize,
        dragRect!.height * cellSize,
      );
      final cor = isValid ? dragColor! : Colors.red;
      canvas.drawRect(r.deflate(1),
          Paint()..color = cor.withValues(alpha: 0.45));
      canvas.drawRect(
          r.deflate(1),
          Paint()
            ..color = cor
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke);
    }

    // Borda externa
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..color = AppColors.primaryMain
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
