import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/dashboard/dashboard_controller.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_elementos_page.dart';

import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/ponta/ponta_model.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List<PontaBitolaGrupo> _pontasGrupos = [];
  double _totalPontasKg = 0.0;
  bool _pontasCarregando = true;
  int _modoDash = 0; // 0 = Gestão a Vista, 1 = Mapa de Pedidos

  @override
  void initState() {
    setWebTitle('AçoPlus - Planejamento e controle de Produção');
    super.initState();
    _carregarPontas();
  }

  Future<void> _carregarPontas() async {
    try {
      final data = await SupabaseService.client.from('pontas').select();
      final pontas = data.map((e) => PontaModel.fromSupabaseMap(e)).toList();

      final Map<String, PontaBitolaGrupo> mapa = {};
      for (final p in pontas) {
        mapa.putIfAbsent(
          p.bitolaId,
          () => PontaBitolaGrupo(
            bitolaId: p.bitolaId,
            bitolaDescricao: p.bitolaDescricao,
            pontas: [],
          ),
        );
        mapa[p.bitolaId]!.pontas.add(p);
      }

      final grupos = mapa.values.toList();
      double total = 0.0;
      for (final g in grupos) {
        total += g.totalPeso;
      }
      if (mounted) setState(() { _pontasGrupos = grupos; _totalPontasKg = total; _pontasCarregando = false; });
    } catch (_) {
      if (mounted) setState(() => _pontasCarregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(child: _modoDash == 0 ? body() : _mapaParqueWidget()),
      ],
    );
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
              return Container(
                color: const Color(0xFFCBD5E1),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _kpiCards(pedidos),
                    const H(12),
                    _pontasStripWidget(),
                    const H(16),
                    if (constraints.maxWidth < 1000) ...[
                      // 1 Coluna (Mobile)
                      _ordemProducaoWidget(),
                      const H(16),
                      _armacaoWidget(pedidos),
                      const H(16),
                      _consumoBitolaWidget(),
                    ] else if (constraints.maxWidth < 1450) ...[
                      // 2 Colunas (Telas Médias)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ordemProducaoWidget()),
                          const W(16),
                          Expanded(child: _armacaoWidget(pedidos)),
                        ],
                      ),
                      const H(16),
                      _consumoBitolaWidget(),
                    ] else ...[
                      // 3 Colunas (Telas Grandes)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ordemProducaoWidget()),
                          const W(16),
                          Expanded(child: _armacaoWidget(pedidos)),
                          const W(16),
                          Expanded(child: _consumoBitolaWidget()),
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
    final entregasHoje = pedidos
        .where((p) => p.deliveryAt != null && p.deliveryAt!.isSameDay(today))
        .length;
    final atrasados = pedidos
        .where((p) =>
            p.deliveryAt != null &&
            p.deliveryAt!.isBefore(today) &&
            !p.deliveryAt!.isSameDay(today))
        .length;
    final novos24h = pedidos
        .where(
            (p) => p.createdAt.isAfter(now.subtract(const Duration(days: 1))))
        .length;

    return LayoutBuilder(builder: (context, constraints) {
      double cardWidth;
      if (constraints.maxWidth < 700) {
        cardWidth = constraints.maxWidth; // 1 por linha
      } else if (constraints.maxWidth < 1100) {
        cardWidth = (constraints.maxWidth - 24) / 2; // 2 por linha
      } else {
        cardWidth = (constraints.maxWidth - 72) / 4; // 4 por linha
      }

      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _cardKPI('TOTAL EM PRODUÇÃO', totalKg.toKg(), Symbols.factory,
              AppColors.primaryMain, cardWidth),
          _cardKPI('ENTREGAS HOJE', entregasHoje.toString(),
              Symbols.local_shipping, AppColors.success, cardWidth),
          _cardKPI('PEDIDOS ATRASADOS', atrasados.toString(), Symbols.warning,
              AppColors.error, cardWidth),
          _cardKPI('NOVOS (24H)', novos24h.toString(), Symbols.new_releases,
              AppColors.secondary, cardWidth),
        ],
      );
    });
  }

  Widget _cardKPI(
      String label, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(Colors.grey[500]!)),
              Icon(icon, color: color.withAlpha(200), size: 24),
            ],
          ),
          const H(12),
          Text(value,
              style:
                  AppCss.largeBold.setSize(24).setColor(AppColors.primaryMain)),
        ],
      ),
    );
  }

  Widget _pontasStripWidget() {
    if (_pontasCarregando) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_pontasGrupos.isEmpty) return const SizedBox.shrink();

    // Ordenar por descrição
    final grupos = List<PontaBitolaGrupo>.from(_pontasGrupos);
    grupos.sort((a, b) => a.bitolaDescricao.compareTo(b.bitolaDescricao));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.flip_to_back, size: 18, color: Colors.teal[700]),
          const W(8),
          Text('PONTAS',
              style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[700]!)),
          const W(6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_totalPontasKg.toStringAsFixed(1)} kg',
              style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[800]!),
            ),
          ),
          const W(12),
          Container(width: 1, height: 24, color: Colors.grey[200]),
          const W(12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: grupos.map((g) {
                  // Extrair só a descrição curta (ex: "8.0mm")
                  final descCurta = g.bitolaDescricao.split(' - ').length > 1
                      ? g.bitolaDescricao.split(' - ').last.trim()
                      : g.bitolaDescricao;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            descCurta,
                            style: AppCss.minimumBold.setSize(11).setColor(Colors.grey[700]!),
                          ),
                          const W(6),
                          Text(
                            '${g.totalPeso.toStringAsFixed(1)} kg',
                            style: AppCss.minimumBold.setSize(11).setColor(Colors.teal[700]!),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _consumoBitolaWidget() {
    final consumoMap = dashCtrl.getConsumoEstimado();
    final produtos = FirestoreClient.produtos.data
        .where((p) => consumoMap.containsKey(p.id))
        .toList();

    produtos.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return Container(
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.analytics, color: AppColors.primaryMain),
                    const W(12),
                    Text('CONSUMO ESTIMADO',
                        style: AppCss.mediumBold.setSize(18)),
                  ],
                ),
                const H(8),
                Text('Peso pendente por bitola (Corte e Dobra)',
                    style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
              ],
            ),
          ),
          Expanded(
            child: produtos.isEmpty
                ? Center(
                    child: Text('Nenhum consumo pendente.',
                        style:
                            AppCss.mediumRegular.setColor(Colors.grey[400]!)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: produtos.length,
                    itemBuilder: (_, i) {
                      final p = produtos[i];
                      final peso = consumoMap[p.id] ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.descricao,
                                    style: AppCss.mediumBold.setSize(13)),
                                Text(peso.toKg(),
                                    style: AppCss.mediumBold
                                        .setSize(13)
                                        .setColor(AppColors.primaryMain)),
                              ],
                            ),
                            const H(5),
                            LinearProgressIndicator(
                              value: 1.0,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primaryMain.withAlpha(25)),
                              minHeight: 3,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
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
            height: 450,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[400]!, width: 1.0),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
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
                      Text('ESTEIRA DE PRODUÇÃO',
                          style: AppCss.mediumBold.setSize(18)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryMain.withAlpha(25),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${ordensFiltradas.length} ORDENS ATIVAS',
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(AppColors.primaryMain)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ordensFiltradas.isEmpty
                      ? Center(
                          child: Text('Nenhuma ordem em produção agora.',
                              style: AppCss.mediumRegular
                                  .setColor(Colors.grey[400]!)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: ordensFiltradas.length,
                          itemBuilder: (_, i) => _ordemProducaoItemWidget(
                              context, ordensFiltradas[i], i),
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
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.grey[100], shape: BoxShape.circle),
                child: Center(
                    child: Text('${index + 1}º',
                        style: AppCss.minimumBold.setSize(12))),
              ),
              const W(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ordem.localizator,
                      style: AppCss.mediumBold.setSize(14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const H(4),
                    Text(
                      ordem.produto.nome,
                      style: AppCss.mediumBold
                          .setSize(12)
                          .setColor(AppColors.primaryMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const H(2),
                    Text(
                      ordem.produtos.fold(0.0, (sum, p) => sum + p.qtde).toKg(),
                      style: AppCss.mediumBold
                          .setSize(12)
                          .setColor(AppColors.primaryMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              LayoutBuilder(builder: (context, c) {
                // Se o espaço for muito curto (menos de 280px para o item), esconde os gráficos
                if (c.maxWidth < 180) return const SizedBox();

                return Row(
                  children: [
                    const W(16),
                    _progressChartWidget(PedidoProdutoStatus.aguardandoProducao,
                        ordem.getPrcntgAguardando(), ordem.freezed.isFreezed),
                    const W(8),
                    _progressChartWidget(PedidoProdutoStatus.produzindo,
                        ordem.getPrcntgProduzindo(), ordem.freezed.isFreezed),
                    const W(8),
                    _progressChartWidget(PedidoProdutoStatus.pronto,
                        ordem.getPrcntgPronto(), ordem.freezed.isFreezed),
                  ],
                );
              }),
            ],
          ),
        ),
      );

  Widget _progressChartWidget(
    PedidoProdutoStatus status,
    double porcentagem,
    bool isFreezed,
  ) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: porcentagem,
              backgroundColor:
                  (isFreezed ? Colors.grey[600]! : status.color).withAlpha(50),
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(
                isFreezed ? Colors.grey[600]! : status.color,
              ),
            ),
          ),
          Text(
            '${(porcentagem * 100).percent}%',
            style: AppCss.mediumBold.setSize(13).setColor(Colors.black),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ARMAÇÃO
  // ═══════════════════════════════════════════════════
  Widget _armacaoWidget(List<PedidoModel> allPedidos) {
    final pedidosArmacao =
        allPedidos.where((p) => p.step.isExibirArmacao).toList();

    pedidosArmacao.sort((a, b) =>
        (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));

    return Container(
      height: 450,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(Symbols.construction, color: Colors.orange[800]),
                const W(12),
                Text('ARMAÇÃO', style: AppCss.mediumBold.setSize(18)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pedidosArmacao.length} PEDIDOS',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(Colors.orange[800]!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidosArmacao.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum pedido em armação no momento.',
                      style: AppCss.mediumRegular.setColor(Colors.grey[400]!),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: pedidosArmacao.length,
                    itemBuilder: (_, i) =>
                        _armacaoItemWidget(context, pedidosArmacao[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _armacaoItemWidget(
    BuildContext context,
    PedidoModel pedido,
    int index,
  ) {
    final resumo = pedido.armacaoResumo['details'] as Map? ?? {};
    final totalQtd = pedido.armacaoResumo['total_qtd'] ?? 0;
    final totalPeso = (pedido.armacaoResumo['total_peso'] ?? 0.0).toDouble();

    final aguardando = resumo['aguardando'] ?? {};
    final armando = resumo['armando'] ?? {};
    final pronto = resumo['pronto'] ?? {};

    final prcAguardando = (aguardando['prcnt_qtd'] ?? 0.0).toDouble();
    final prcArmando = (armando['prcnt_qtd'] ?? 0.0).toDouble();
    final prcPronto = (pronto['prcnt_qtd'] ?? 0.0).toDouble();

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.0),
        ),
        child: Row(
          children: [
            // Índice
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(Colors.orange[800]!),
                ),
              ),
            ),
            const W(16),
            // Info do pedido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: pedido.cliente.nome,
                    child: Text(
                      pedido.localizador,
                      style: AppCss.mediumBold.setSize(14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const H(4),
                  Text(
                    '$totalQtd elementos',
                    style: AppCss.minimumRegular
                        .setSize(12)
                        .setColor(Colors.grey[600]!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const H(2),
                  Text(
                    '${totalPeso.toStringAsFixed(1)} kg',
                    style: AppCss.mediumBold
                        .setSize(12)
                        .setColor(AppColors.primaryMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            LayoutBuilder(builder: (context, c) {
              // Se o espaço for muito curto, esconde os gráficos circulares
              if (c.maxWidth < 220) return const SizedBox();

              return Row(
                children: [
                  const W(8),
                  _armacaoCircle(
                      prcAguardando,
                      Colors.blue.shade700,
                      '${((aguardando['qtd'] ?? 0.0).toDouble()).round()} pc',
                      '${((aguardando['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
                  const W(6),
                  _armacaoCircle(
                      prcArmando,
                      Colors.orange.shade800,
                      '${((armando['qtd'] ?? 0.0).toDouble()).round()} pc',
                      '${((armando['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
                  const W(6),
                  _armacaoCircle(
                      prcPronto,
                      Colors.green.shade700,
                      '${((pronto['qtd'] ?? 0.0).toDouble()).round()} pc',
                      '${((pronto['peso'] ?? 0.0).toDouble()).toStringAsFixed(0)} kg'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _armacaoCircle(
      double porcentagem, Color color, String qtdLabel, String kgLabel) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: porcentagem,
                    backgroundColor: color.withAlpha(40),
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '${(porcentagem * 100).round()}%',
                  style: AppCss.mediumBold.setSize(13).setColor(Colors.black),
                ),
              ],
            ),
          ),
          const H(3),
          Text(
            qtdLabel,
            style: AppCss.minimumBold.setSize(11).setColor(Colors.grey[700]!),
          ),
          Text(
            kgLabel,
            style:
                AppCss.minimumRegular.setSize(10).setColor(Colors.grey[500]!),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  APP BAR COM TOGGLE
  // ═══════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _modoDash == 0 ? 'Gest\u00e3o a Vista' : 'Mapa de Pedidos',
                  style: AppCss.mediumBold.setSize(20).setColor(Colors.white),
                ),
                Text(
                  _modoDash == 0
                      ? 'Monitoramento em tempo real de produ\u00e7\u00e3o e consumo'
                      : 'Vis\u00e3o geral do parque log\u00edstico',
                  style: AppCss.minimumRegular.setSize(12).setColor(Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleBtn(0, Icons.dashboard_outlined, 'Gest\u00e3o'),
                _toggleBtn(1, Icons.map_outlined, 'Mapa'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(int modo, IconData icon, String label) {
    final sel = _modoDash == modo;
    return GestureDetector(
      onTap: () => setState(() => _modoDash = modo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? Colors.white : Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  MAPA DE PEDIDOS (PARQUE COMPLETO)
  // ═══════════════════════════════════════════════════

  static const _coresPatios = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFEC4899),
  ];

  Widget _mapaParqueWidget() {
    final comp = PreferencesService.parqueComprimento.value;
    final larg = PreferencesService.parqueLargura.value;

    if (comp <= 0 || larg <= 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
            const H(16),
            Text('Parque log\u00edstico n\u00e3o configurado.', style: AppCss.mediumRegular.setColor(Colors.grey[400]!)),
          ],
        ),
      );
    }

    final patios = FirestoreClient.patios.data
        .where((p) => p.parqueX != null && p.parqueY != null)
        .toList();

    final pedidosAtivos = FirestoreClient.pedidos.data
        .where((p) => !p.isArchived)
        .toList();

    return Container(
      color: const Color(0xFFCBD5E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final cellW = maxW / comp;
            final cellH = maxH / larg;
            final cellSize = cellW < cellH ? cellW : cellH;
            final totalW = cellSize * comp;
            final totalH = cellSize * larg;

            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: Center(
              child: Container(
                width: totalW,
                height: totalH,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(
                    size: Size(totalW, totalH),
                    painter: _DashParqueGridPainter(comprimento: comp, largura: larg, cellSize: cellSize),
                    child: Stack(
                      children: patios.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final patio = entry.value;
                        final cor = _coresPatios[idx % _coresPatios.length];

                        final boxes = FirestoreClient.boxes.data
                            .where((b) => b.patioId == patio.id)
                            .toList();

                        return Positioned(
                          left: patio.parqueX! * cellSize,
                          top: patio.parqueY! * cellSize,
                          width: patio.comprimento * cellSize,
                          height: patio.largura * cellSize,
                          child: _patioComBoxes(patio, boxes, cor, cellSize, pedidosAtivos),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _patioComBoxes(PatioModel patio, List<BoxModel> boxes, Color cor, double parqueCellSize, List pedidosAtivos) {
    // Cell size relativo ao p\u00e1tio (pixels por metro dentro do p\u00e1tio)
    final patioCellSize = parqueCellSize; // 1 metro = 1 cellSize

    return Stack(
      children: [
        // Fundo do pátio
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // Nome do pátio no topo
          Positioned(
            left: 4, top: 2,
            child: Text(
              patio.nome,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cor.withValues(alpha: 0.5)),
            ),
          ),
          // Boxes
          ...boxes.map((box) {
            final alocacoes = FirestoreClient.pedidoBoxes.data
                .where((pb) => pb.boxId == box.id)
                .toList();
            final localizadores = alocacoes
                .map((pb) => pedidosAtivos.where((p) => p.id == pb.pedidoId).firstOrNull?.localizador)
                .where((l) => l != null)
                .cast<String>()
                .toList();
            final temPedido = localizadores.isNotEmpty;

            return Positioned(
              left: box.x * patioCellSize,
              top: box.y * patioCellSize,
              width: box.comprimento * patioCellSize,
              height: box.largura * patioCellSize,
              child: Tooltip(
                message: 'Box ${box.nome}${localizadores.isNotEmpty ? '\n${localizadores.join(', ')}' : ''}',
                child: Container(
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: temPedido ? box.color.withValues(alpha: 0.25) : box.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: temPedido ? box.color.withValues(alpha: 0.5) : box.color.withValues(alpha: 0.15),
                      width: temPedido ? 0.8 : 0.3,
                    ),
                  ),
                  child: ClipRect(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                box.nome,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: box.color.withValues(alpha: temPedido ? 0.9 : 0.5)),
                              ),
                              if (localizadores.isNotEmpty)
                                ...localizadores.map((loc) => Text(
                                  loc,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cor),
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        // Borda do pátio (por cima de tudo)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: cor.withValues(alpha: 0.35), width: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashParqueGridPainter extends CustomPainter {
  final int comprimento, largura;
  final double cellSize;
  _DashParqueGridPainter({required this.comprimento, required this.largura, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 0.3;
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
