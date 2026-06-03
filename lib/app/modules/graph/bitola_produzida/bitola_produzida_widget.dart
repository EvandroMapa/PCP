import 'dart:async';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/graph/bitola_produzida/bitola_produzida_controller.dart';
import 'package:aco_plus/app/modules/graph/bitola_produzida/bitola_produzida_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class BitolaProduzidaWidget extends StatefulWidget {
  const BitolaProduzidaWidget({super.key});

  @override
  State<BitolaProduzidaWidget> createState() => _GrapOrdemhTotalWidgetState();
}

class _GrapOrdemhTotalWidgetState extends State<BitolaProduzidaWidget> {
  late List<BarSeries<BitolaProduzidaModel, DateTime>> data;

  late StreamSubscription<List<PedidoModel>> pedidoStream;

  @override
  void initState() {
    data = bitolaProduzidaCtrl.getSource();
    pedidoStream =
        FirestoreClient.pedidos.pedidosUnarchivedsStream.listen.listen((e) {
      setState(() {
        data = bitolaProduzidaCtrl.getSource();
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    pedidoStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const H(16),
        Expanded(
          child: SfCartesianChart(
            zoomPanBehavior: ZoomPanBehavior(
              enablePanning: true,
              enablePinching: true,
              enableSelectionZooming: true,
              enableDoubleTapZooming: true,
              enableMouseWheelZooming: true,
              zoomMode: ZoomMode.xy,
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'point.x : point.y Kg',
            ),
            enableMultiSelection: true,
            onDataLabelRender: (dataLabelArgs) {
              dataLabelArgs.textStyle = AppCss.smallRegular.copyWith(
                color: dataLabelArgs.color,
                fontSize: 12,
              );
              double qtde = double.parse(dataLabelArgs.text ?? '0');
              dataLabelArgs.text = qtde == 0 ? empty : qtde.toKg();
            },
            primaryXAxis: DateTimeCategoryAxis(
              dateFormat: DateFormat('dd/MM'),
              intervalType: DateTimeIntervalType.days,
              interval: 1,
            ),
            primaryYAxis: NumericAxis(
              axisLabelFormatter: (axisLabelRenderArgs) {
                return ChartAxisLabel(
                  axisLabelRenderArgs.value.toDouble().toKg(),
                  AppCss.smallRegular.copyWith(fontSize: 12),
                );
              },
            ),
            series: data,
          ),
        ),
      ],
    );
  }
}
