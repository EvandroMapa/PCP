import 'dart:async';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_body_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_top_bar_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/shimmer/kanban_body_shimmer_widget.dart';
import 'package:flutter/material.dart';

class KanbanPage extends StatefulWidget {
  final bool standalone;
  const KanbanPage({this.standalone = false, super.key});

  @override
  State<KanbanPage> createState() => _KanbanPageState();
}

class _KanbanPageState extends State<KanbanPage> {
  late StreamSubscription<List<PedidoModel>> pedidoStream;
  late StreamSubscription<List<StepModel>> stepStream;

  @override
  void dispose() {
    pedidoStream.cancel();
    stepStream.cancel();
    super.dispose();
  }

  @override
  void initState() {
    setWebTitle(widget.standalone ? 'AçoPlus - Kanban' : 'AçoPlus - Planejamento e controle de Produção');
    kanbanCtrl.onInit().then((_) {
      pedidoStream = FirestoreClient.pedidos.pedidosUnarchivedsStream.listen
          .listen((e) {
            kanbanCtrl.onMount();
          });
      stepStream = FirestoreClient.steps.dataStream.listen.listen((e) {
        kanbanCtrl.onMount();
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget body = StreamOut(
      loading: const KanbanBodyShimmerWidget(),
      stream: kanbanCtrl.utilsStream.listen,
      builder: (context, utils) => StreamBuilder<AutomatizacaoModel>(
        stream: FirestoreClient.automatizacao.dataStream.listen,
        builder: (context, snapshot) {
          final automatizacao = snapshot.data ?? AutomatizacaoModel.empty;
          return KanbanBodyWidget(utils, automatizacao);
        },
      ),
    );
    if (widget.standalone) {
      return Scaffold(
        appBar: const KanbanTopBarWidget(standalone: true),
        body: body,
      );
    }
    return body;
  }
}
