
import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/modules/patio/box_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final boxCtrl = BoxController();

class BoxController {
  static final BoxController _instance = BoxController._();
  BoxController._();
  factory BoxController() => _instance;

  final AppStream<PatioModel?> selectedPatioStream =
      AppStream<PatioModel?>.seed(null);
  PatioModel? get selectedPatio => selectedPatioStream.value;

  final AppStream<BoxModel?> selectedBoxStream =
      AppStream<BoxModel?>.seed(null);
  BoxModel? get selectedBox => selectedBoxStream.value;

  void selectPatio(PatioModel patio) {
    selectedPatioStream.add(patio);
    selectedBoxStream.add(null);
  }

  void selectBox(BoxModel? box) {
    selectedBoxStream.add(box);
  }

  List<BoxModel> getBoxesDoPatio(String patioId, List<BoxModel> todos) =>
      todos.where((b) => b.patioId == patioId).toList();

  bool intersecta(int ax, int ay, int aw, int ah, int bx, int by, int bw, int bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }

  bool posicaoValida({
    required String? excluirId,
    required int x,
    required int y,
    required int comprimento,
    required int largura,
    required List<BoxModel> boxes,
    required PatioModel patio,
  }) {
    if (x < 0 || y < 0) return false;
    if (x + comprimento > patio.comprimento) return false;
    if (y + largura > patio.largura) return false;
    for (final b in boxes) {
      if (b.id == excluirId) continue;
      if (intersecta(x, y, comprimento, largura, b.x, b.y, b.comprimento, b.largura)) {
        return false;
      }
    }
    return true;
  }

  int _proximoNumero(String patioId, List<BoxModel> todosBoxes) {
    final boxesDoPatio = todosBoxes.where((b) => b.patioId == patioId).toList();
    if (boxesDoPatio.isEmpty) return 1;
    final numeros = boxesDoPatio.map((b) => int.tryParse(b.nome) ?? 0);
    return numeros.reduce((a, b) => a > b ? a : b) + 1;
  }

  Color _proximaCor(String patioId, List<BoxModel> todosBoxes) {
    final boxesDoPatio = todosBoxes.where((b) => b.patioId == patioId).toList();
    final coresUsadas = boxesDoPatio.map((b) => b.cor).toSet();
    // Procura a próxima cor da paleta que ainda não foi usada
    final disponivel = boxPaleta.firstWhere(
      (c) => !coresUsadas.contains(c.toARGB32()),
      orElse: () => boxPaleta[boxesDoPatio.length % boxPaleta.length],
    );
    return disponivel;
  }



  Future<void> onCreateBox({
    required BuildContext context,
    required String patioId,
    required int x,
    required int y,
    required int comprimento,
    required int largura,
  }) async {
    final todosBoxes = FirestoreClient.boxes.data;
    final numero = _proximoNumero(patioId, todosBoxes);
    final cor = _proximaCor(patioId, todosBoxes);
    try {
      final box = BoxModel(
        id: HashService.get,
        patioId: patioId,
        nome: '$numero',
        x: x,
        y: y,
        comprimento: comprimento,
        largura: largura,
        cor: cor.toARGB32(),
        createdAt: DateTime.now(),
      );
      await FirestoreClient.boxes.add(box);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  Future<void> onMoveBox(BoxModel box, int newX, int newY) async {
    try {
      final updated = box.copyWith(x: newX, y: newY);
      await FirestoreClient.boxes.update(updated);
    } catch (e) {
      NotificationService.showNegative('Erro ao mover', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  Future<void> onEditBox(BuildContext context, BoxModel box) async {
    final result = await showDialog<BoxModel>(
      context: context,
      builder: (_) => _BoxEditDialog(box: box),
    );
    if (result == null) return;
    try {
      await FirestoreClient.boxes.update(result);
      NotificationService.showPositive(
        'Box ${box.nome} atualizado',
        'Configurações atualizadas com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  Future<void> onDeleteBox(BuildContext context, BoxModel box) async {
    // Verifica se há pedidos alocados neste box
    final alocacoes = FirestoreClient.pedidoBoxes.data
        .where((pb) => pb.boxId == box.id)
        .toList();

    if (alocacoes.isNotEmpty) {
      final nomes = alocacoes.map((a) {
        final pedido = FirestoreClient.pedidos.data
            .where((p) => p.id == a.pedidoId)
            .firstOrNull;
        return pedido?.localizador ?? a.pedidoId;
      }).join(', ');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Box em uso', textAlign: TextAlign.center),
          content: Text(
            'Este box possui ${alocacoes.length == 1 ? 'o pedido' : 'os pedidos'} $nomes alocado${alocacoes.length > 1 ? 's' : ''}.\n\nRemova a alocação antes de excluir o box.',
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Box'),
        content: Text('Deseja excluir o box "${box.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirestoreClient.boxes.delete(box);
      if (selectedBox?.id == box.id) selectedBoxStream.add(null);
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }
}


class _BoxEditDialog extends StatefulWidget {
  final BoxModel box;
  const _BoxEditDialog({required this.box});

  @override
  State<_BoxEditDialog> createState() => _BoxEditDialogState();
}

class _BoxEditDialogState extends State<_BoxEditDialog> {
  late Color _cor;
  late int _maxPedidos;

  @override
  void initState() {
    super.initState();
    _cor = widget.box.color;
    _maxPedidos = widget.box.maxPedidos;
  }

  @override
  Widget build(BuildContext context) {
    final limiteGlobal = PreferencesService.maxPedidosPorBox.value;

    return AlertDialog(
      title: Text('Editar Box ${widget.box.nome}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pedidos alocados ──
          Builder(builder: (_) {
            final alocacoes = FirestoreClient.pedidoBoxes.data
                .where((pb) => pb.boxId == widget.box.id)
                .toList();
            if (alocacoes.isEmpty) return const SizedBox.shrink();

            final nomes = alocacoes.map((a) {
              final pedido = FirestoreClient.pedidos.data
                  .where((p) => p.id == a.pedidoId)
                  .firstOrNull;
              return pedido?.localizador ?? '—';
            }).join(', ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${alocacoes.length == 1 ? 'Pedido' : 'Pedidos'}: $nomes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Text('Cor',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: boxPaleta.map((cor) {
              final selecionada = _cor.toARGB32() == cor.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _cor = cor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selecionada ? Colors.black87 : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selecionada
                        ? [BoxShadow(color: cor.withValues(alpha: 0.5), blurRadius: 8)]
                        : [],
                  ),
                  child: selecionada
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Máximo de pedidos neste box',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Limite global: $limiteGlobal (definido em Automações)',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(limiteGlobal, (i) {
              final valor = i + 1;
              final selecionado = _maxPedidos == valor;
              return GestureDetector(
                onTap: () => setState(() => _maxPedidos = valor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selecionado
                        ? AppColors.primaryMain
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selecionado
                          ? AppColors.primaryMain
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$valor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selecionado ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            widget.box.copyWith(
              cor: _cor.toARGB32(),
              maxPedidos: _maxPedidos,
            ),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
