import 'dart:async';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_bottom_nav.dart';
import 'package:aco_plus/app/core/components/drawer/app_drawer.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_body_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_top_bar_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/shimmer/kanban_body_shimmer_widget.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class KanbanPage extends StatefulWidget {
  const KanbanPage({super.key});

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
    setWebTitle('Kanban');
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
    return StreamOut(
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
  }
}
