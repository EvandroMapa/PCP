import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';


import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/dashboard/dashboard_controller.dart';

import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    setWebTitle('AçoPlus - Gestão a Vista');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return body();
  }

  Widget body() {
    return StreamOut(
      stream: FirestoreClient.pedidos.pedidosUnarchivedsStream.listen,
      builder: (_, pedidos) => StreamOut(
        stream: FirestoreClient.ordens.dataStream.listen,
        builder: (_, __) => StreamOut(
          stream: dashCtrl.utilsStream.listen,
          builder: (_, utils) => LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 1000;
              return Container(
                color: const Color(0xFFF8FAFC),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _kpiCards(pedidos),
                    const H(32),

                    if (isMobile) ...[
                      _ordemProducaoWidget(),
                      const H(32),
                      _consumoBitolaWidget(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _ordemProducaoWidget()),
                          const W(32),
                          Expanded(flex: 4, child: _consumoBitolaWidget()),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kpiCards(List<PedidoModel> pedidos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalKg = pedidos.fold(0.0, (sum, p) => sum + p.getQtdeTotal());
    final entregasHoje = pedidos.where((p) => p.deliveryAt != null && p.deliveryAt!.isSameDay(today)).length;
    final atrasados = pedidos.where((p) => p.deliveryAt != null && p.deliveryAt!.isBefore(today) && !p.deliveryAt!.isSameDay(today)).length;
    final novos24h = pedidos.where((p) => p.createdAt.isAfter(now.subtract(const Duration(days: 1)))).length;

    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth > 1000 ? (constraints.maxWidth - 72) / 4 : (constraints.maxWidth - 24) / 2;

      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _cardKPI('TOTAL EM PRODUÇÃO', totalKg.toKg(), Symbols.factory, AppColors.primaryMain, cardWidth),
          _cardKPI('ENTREGAS HOJE', entregasHoje.toString(), Symbols.local_shipping, AppColors.success, cardWidth),
          _cardKPI('PEDIDOS ATRASADOS', atrasados.toString(), Symbols.warning, AppColors.error, cardWidth),
          _cardKPI('NOVOS (24H)', novos24h.toString(), Symbols.new_releases, AppColors.secondary, cardWidth),
        ],
      );
    });
  }

  Widget _cardKPI(String label, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppCss.minimumBold.setSize(12).setColor(Colors.grey[500]!)),
              Icon(icon, color: color.withAlpha(200), size: 24),
            ],
          ),
          const H(12),
          Text(value, style: AppCss.largeBold.setSize(24).setColor(AppColors.primaryMain)),
        ],
      ),
    );
  }

  Widget _consumoBitolaWidget() {
    final consumoMap = dashCtrl.getConsumoEstimado();
    final produtos = FirestoreClient.produtos.data
        .where((p) => consumoMap.containsKey(p.id))
        .toList();

    produtos.sort((a, b) => a.number.compareTo(b.number));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.analytics, color: AppColors.primaryMain),
              const W(12),
              Text('CONSUMO ESTIMADO', style: AppCss.mediumBold.setSize(18)),
            ],
          ),
          const H(8),
          Text('Peso pendente por bitola (Corte e Dobra)', style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
          const H(24),
          if (produtos.isEmpty)
            Center(child: Text('Nenhum consumo pendente.', style: AppCss.mediumRegular.setColor(Colors.grey[400]!)))
          else
            ...produtos.map((p) {
              final peso = consumoMap[p.id] ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.descricao, style: AppCss.mediumBold.setSize(15)),
                        Text(peso.toKg(), style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
                      ],
                    ),
                    const H(8),
                    LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryMain.withAlpha(25)),
                      minHeight: 4,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _ordemProducaoWidget() => StreamOut<List<OrdemModel>>(
    stream: FirestoreClient.ordens.ordensNaoArquivadasStream.listen,
    builder: (_, ordens) {
      List<OrdemModel> ordensFiltradas = ordens.toList();
      ordensFiltradas.removeWhere((element) => element.freezed.isFreezed);
      ordensFiltradas = ordensFiltradas
          .where((element) => element.status != PedidoProdutoStatus.pronto)
          .toList();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Symbols.reorder, color: AppColors.primaryMain),
                  const W(12),
                  Text('ESTEIRA DE PRODUÇÃO', style: AppCss.mediumBold.setSize(18)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withAlpha(25),
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text('${ordensFiltradas.length} ORDENS ATIVAS',
                      style: AppCss.minimumBold.setSize(11).setColor(AppColors.primaryMain)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: ordensFiltradas.isEmpty
                ? Center(child: Text('Nenhuma ordem em produção agora.', style: AppCss.mediumRegular.setColor(Colors.grey[400]!)))
                : ListView.builder(
                    itemCount: ordensFiltradas.length,
                    itemBuilder: (_, i) => _ordemProducaoItemWidget(context, ordensFiltradas[i], i),
                  ),
            ),
          ],
        ),
      );
    },
  );

  Widget _ordemProducaoItemWidget(
    BuildContext context,
    OrdemModel ordem,
    int index,
  ) =>
      InkWell(
        onTap: () => push(context, OrdemPage(ordem.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: Center(child: Text('${index + 1}º', style: AppCss.minimumBold.setSize(12))),
              ),
              const W(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ordem.localizator, style: AppCss.mediumBold.setSize(14)),
                    const H(4),
                    Text(
                      '${ordem.produto.nome} ${ordem.produto.descricao} • ${ordem.produtos.fold(0.0, (sum, p) => sum + p.qtde).toKg()}',
                      style: AppCss.minimumRegular.setSize(12).setColor(Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
              const W(16),
              if (ordem.produtos.isNotEmpty)
                Row(
                  children: [
                    _progressChartWidget(PedidoProdutoStatus.aguardandoProducao, ordem.getPrcntgAguardando(), ordem.freezed.isFreezed),
                    const W(12),
                    _progressChartWidget(PedidoProdutoStatus.produzindo, ordem.getPrcntgProduzindo(), ordem.freezed.isFreezed),
                    const W(12),
                    _progressChartWidget(PedidoProdutoStatus.pronto, ordem.getPrcntgPronto(), ordem.freezed.isFreezed),
                  ],
                ),
            ],
          ),
        ),
      );

  Widget _progressChartWidget(
    PedidoProdutoStatus status,
    double porcentagem,
    bool isFreezed,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: porcentagem,
          backgroundColor: (isFreezed ? Colors.grey[600]! : status.color).withAlpha(50),
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            isFreezed ? Colors.grey[600]! : status.color,
          ),
        ),
        Text(
          '${(porcentagem * 100).percent}%',
          style: AppCss.minimumBold.setSize(10),
        ),
      ],
    );
  }
}
