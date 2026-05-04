import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/patio/patio_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final patioCtrl = PatioController();

class PatioController {
  static final PatioController _instance = PatioController._();

  PatioController._();

  factory PatioController() => _instance;

  final AppStream<PatioModel?> patioStream = AppStream<PatioModel?>.seed(null);
  PatioModel? get patio => patioStream.value;

  final AppStream<PatioUtils> utilsStream =
      AppStream<PatioUtils>.seed(PatioUtils());
  PatioUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(PatioUtils());
    FirestoreClient.patios.fetch();
  }

  final AppStream<PatioCreateModel> formStream =
      AppStream<PatioCreateModel>();
  PatioCreateModel get form => formStream.value;

  void init(PatioModel? patio) {
    formStream
        .add(patio != null ? PatioCreateModel.edit(patio) : PatioCreateModel());
  }

  List<PatioModel> getPatiosFiltered(String search, List<PatioModel> patios) {
    if (search.length < 3) return patios;
    List<PatioModel> filtered = [];
    for (final patio in patios) {
      if (patio.toString().toCompare.contains(search.toCompare)) {
        filtered.add(patio);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, PatioModel? patio) async {
    try {
      onValid(patio);
      final newPatio = form.toPatioModel();

      if (form.isEdit) {
        await FirestoreClient.patios.update(newPatio);
      } else {
        await FirestoreClient.patios.add(newPatio);
      }
      pop(value);

      NotificationService.showPositive(
        'Pátio ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
      await FirestoreClient.patios.fetch();
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(dynamic value, PatioModel patio) async {
    final boxesDoPatio =
        FirestoreClient.boxes.data.where((b) => b.patioId == patio.id).toList();

    // Verificar se algum box tem pedido alocado
    final boxesComPedido = <String>[];
    for (final box in boxesDoPatio) {
      final alocacoes =
          FirestoreClient.pedidoBoxes.data.where((pb) => pb.boxId == box.id);
      if (alocacoes.isNotEmpty) {
        boxesComPedido.add('Box ${box.nome}');
      }
    }

    if (boxesComPedido.isNotEmpty) {
      // Bloqueio: não pode excluir
      showDialog(
        context: value,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Pátio em uso', textAlign: TextAlign.center),
          content: Text(
            'O pátio "${patio.nome}" possui pedidos alocados em: '
            '${boxesComPedido.join(', ')}.\n\n'
            'Remova as alocações antes de excluir.',
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

    // Confirmação
    final mensagem = boxesDoPatio.isNotEmpty
        ? 'O pátio "${patio.nome}" possui ${boxesDoPatio.length} box(es) que também serão excluídos.\n\nDeseja continuar?'
        : 'Deseja excluir o pátio "${patio.nome}"?';

    final confirmar = await showDialog<bool>(
      context: value,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Pátio'),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Excluir boxes do pátio primeiro
    for (final box in boxesDoPatio) {
      await FirestoreClient.boxes.delete(box);
    }

    await FirestoreClient.patios.delete(patio);
    NotificationService.showPositive(
      'Pátio Excluído',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );
    await FirestoreClient.patios.fetch();
  }

  void onValid(PatioModel? patio) {
    if (form.nome.text.trim().isEmpty) {
      throw Exception('O nome do pátio é obrigatório');
    }
    if (form.comprimentoInt <= 0) {
      throw Exception('O comprimento deve ser maior que zero');
    }
    if (form.larguraInt <= 0) {
      throw Exception('A largura deve ser maior que zero');
    }
  }
}
