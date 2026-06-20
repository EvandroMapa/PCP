import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_elementos_page.dart';
import 'package:aco_plus/app/modules/dashboard/dashboard_controller.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PainelGerencialPage extends StatefulWidget {
  final bool standalone;
  const PainelGerencialPage({super.key, this.standalone = false});

  @override
  State<PainelGerencialPage> createState() => _PainelGerencialPageState();
}

class _PainelGerencialPageState extends State<PainelGerencialPage> {
  // Controle de seções expandidas
  final Map<String, bool> _expandido = {
    'producao': true,
    'armacao': true,
    'consumo': true,
    'estoque': true,
  };

  @override
  void initState() {
    super.initState();
    setWebTitle('AçoPlus - Painel Gerencial');
  }

  Future<void> _onRefresh() async {
    // Re-fetch dados
    BackendClient.estoques.fetch();
    BackendClient.estoquesMovimentacao.fetch();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutralLightest,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamOut(
              stream: FirestoreClient.pedidos.pedidosUnarchivedsStream.listen,
              builder: (_, pedidos) => StreamOut(
                stream: FirestoreClient.ordens.dataStream.listen,
                builder: (_, __) => RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primaryMain,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _totalProducaoCard(pedidos),
                      const H(10),
                      _secaoProducaoCD(),
                      const H(10),
                      _secaoArmacao(pedidos),
                      const H(10),
                      _secaoConsumo(),
                      const H(10),
                      _secaoEstoqueProjetado(),
                      const H(20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!widget.standalone)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 22),
              onPressed: () => Scaffold.of(context).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          if (!widget.standalone) const W(4),
          Icon(Icons.phone_android, color: Colors.white.withAlpha(200), size: 18),
          const W(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Painel Gerencial',
                  style: AppCss.mediumBold.setSize(18).setColor(Colors.white),
                ),
                Text(
                  'Visão compacta para celular',
                  style: AppCss.minimumRegular
                      .setSize(11)
                      .setColor(Colors.white.withAlpha(180)),
                ),
              ],
            ),
          ),
          // Indicador de atualização
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Atualizar dados',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  TOTAL EM PRODUÇÃO (CARD DESTAQUE)
  // ═══════════════════════════════════════════════════
  Widget _totalProducaoCard(List<PedidoModel> pedidos) {
    final totalKg = pedidos
        .where((p) => p.step.isConsiderarTotalProducao)
        .fold(0.0, (sum, p) => sum + p.getQtdeTotal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryMain,
            AppColors.primaryMain.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryMain.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.factory, color: Colors.white, size: 28),
          ),
          const W(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL EM PRODUÇÃO',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(Colors.white.withAlpha(200)),
                ),
                const H(4),
                Text(
                  totalKg.toKg(),
                  style: AppCss.largeBold.setSize(28).setColor(Colors.white),
                ),
                const H(2),
                Text(
                  'Volume total processado na planta',
                  style: AppCss.minimumRegular
                      .setSize(10)
                      .setColor(Colors.white.withAlpha(150)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  HEADER DE SEÇÃO (colapsável)
  // ═══════════════════════════════════════════════════
  Widget _secaoHeader({
    required String chave,
    required String titulo,
    required IconData icone,
    required Color cor,
    String? badge,
  }) {
    final expandido = _expandido[chave] ?? true;
    return GestureDetector(
      onTap: () => setState(() => _expandido[chave] = !expandido),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 18),
            const W(8),
            Expanded(
              child: Text(
                titulo,
                style: AppCss.mediumBold.setSize(13).setColor(cor),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: AppCss.minimumBold.setSize(10).setColor(cor),
                ),
              ),
              const W(6),
            ],
            AnimatedRotation(
              turns: expandido ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, size: 18, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoContainer({
    required String chave,
    required String titulo,
    required IconData icone,
    required Color cor,
    String? badge,
    required Widget child,
  }) {
    final expandido = _expandido[chave] ?? true;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _secaoHeader(
              chave: chave,
              titulo: titulo,
              icone: icone,
              cor: cor,
              badge: badge,
            ),
            AnimatedCrossFade(
              firstChild: child,
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState:
                  expandido ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PRODUÇÃO CD
  // ═══════════════════════════════════════════════════
  Widget _secaoProducaoCD() {
    return StreamOut<List<OrdemModel>>(
      stream: FirestoreClient.ordens.ordensNaoArquivadasStream.listen,
      builder: (_, ordens) {
        List<OrdemModel> ativas = ordens.toList();
        ativas.removeWhere((e) => e.freezed.isFreezed);
        ativas = ativas
            .where((e) => e.status != PedidoBitolaStatus.pronto)
            .toList();

        return _secaoContainer(
          chave: 'producao',
          titulo: 'PRODUÇÃO CD',
          icone: Symbols.reorder,
          cor: AppColors.primaryMain,
          badge: '${ativas.length} ordens',
          child: ativas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Nenhuma ordem em produção.',
                      style:
                          AppCss.minimumRegular.setColor(Colors.grey[400]!),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: ativas.length,
                  itemBuilder: (_, i) => _ordemItem(ativas[i], i),
                ),
        );
      },
    );
  }

  Widget _ordemItem(OrdemModel ordem, int index) {
    return InkWell(
      onTap: () => push(context, OrdemPage(ordem.id)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: AppCss.minimumBold.setSize(10),
                ),
              ),
            ),
            const W(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ordem.localizator,
                    style: AppCss.mediumBold.setSize(12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const H(2),
                  Text(
                    '${ordem.produto.nome} · ${ordem.produtos.fold(0.0, (s, p) => s + p.qtde).toKg()}',
                    style: AppCss.minimumRegular
                        .setSize(10)
                        .setColor(AppColors.primaryMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const W(6),
            // Mini progress circles
            _miniCircle(ordem.getPrcntgAguardando(), Colors.blue[700]!),
            const W(4),
            _miniCircle(ordem.getPrcntgProduzindo(), Colors.orange[800]!),
            const W(4),
            _miniCircle(ordem.getPrcntgPronto(), Colors.green[700]!),
          ],
        ),
      ),
    );
  }

  Widget _miniCircle(double valor, Color cor) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              value: valor,
              backgroundColor: cor.withAlpha(30),
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
          Text(
            '${(valor * 100).round()}',
            style: AppCss.minimumBold.setSize(8).setColor(Colors.grey[700]!),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ARMAÇÃO (CDA)
  // ═══════════════════════════════════════════════════
  Widget _secaoArmacao(List<PedidoModel> allPedidos) {
    final pedidos =
        allPedidos.where((p) => p.step.isExibirArmacao).toList();
    pedidos.sort((a, b) =>
        (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));

    return _secaoContainer(
      chave: 'armacao',
      titulo: 'ARMAÇÃO (CDA)',
      icone: Symbols.construction,
      cor: Colors.orange[800]!,
      badge: '${pedidos.length} pedidos',
      child: pedidos.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Nenhum pedido em armação.',
                  style: AppCss.minimumRegular.setColor(Colors.grey[400]!),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: pedidos.length,
              itemBuilder: (_, i) => _armacaoItem(pedidos[i], i),
            ),
    );
  }

  Widget _armacaoItem(PedidoModel pedido, int index) {
    final resumo = pedido.armacaoResumo['details'] as Map? ?? {};
    final totalQtd = pedido.armacaoResumo['total_qtd'] ?? 0;
    final totalPeso =
        (pedido.armacaoResumo['total_peso'] ?? 0.0).toDouble();

    final prcAguardando =
        ((resumo['aguardando'] ?? {})['prcnt_qtd'] ?? 0.0).toDouble();
    final prcArmando =
        ((resumo['armando'] ?? {})['prcnt_qtd'] ?? 0.0).toDouble();
    final prcPronto =
        ((resumo['pronto'] ?? {})['prcnt_qtd'] ?? 0.0).toDouble();

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppCss.minimumBold
                          .setSize(9)
                          .setColor(Colors.orange[800]!),
                    ),
                  ),
                ),
                const W(8),
                Expanded(
                  child: Text(
                    pedido.localizador,
                    style: AppCss.mediumBold.setSize(12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${totalPeso.toStringAsFixed(0)} kg',
                  style: AppCss.minimumBold
                      .setSize(10)
                      .setColor(AppColors.primaryMain),
                ),
              ],
            ),
            const H(6),
            // Barra de progresso empilhada
            Row(
              children: [
                Text(
                  '$totalQtd elem.',
                  style: AppCss.minimumRegular
                      .setSize(9)
                      .setColor(Colors.grey[500]!),
                ),
                const W(8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (prcPronto > 0)
                            Flexible(
                              flex: (prcPronto * 100).round().clamp(1, 100),
                              child: Container(color: Colors.green[700]),
                            ),
                          if (prcArmando > 0)
                            Flexible(
                              flex: (prcArmando * 100).round().clamp(1, 100),
                              child: Container(color: Colors.orange[700]),
                            ),
                          if (prcAguardando > 0)
                            Flexible(
                              flex:
                                  (prcAguardando * 100).round().clamp(1, 100),
                              child: Container(color: Colors.blue[200]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const W(6),
                Text(
                  '${(prcPronto * 100).round()}%',
                  style: AppCss.minimumBold
                      .setSize(9)
                      .setColor(Colors.green[700]!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  CONSUMO PREVISTO
  // ═══════════════════════════════════════════════════
  Widget _secaoConsumo() {
    final consumoMap = dashCtrl.getConsumoEstimado();
    final produtos = FirestoreClient.bitolas.data
        .where((p) => consumoMap.containsKey(p.id))
        .toList();
    produtos.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    double totalGeral = 0;
    for (var p in produtos) {
      totalGeral += consumoMap[p.id] ?? 0.0;
    }

    return _secaoContainer(
      chave: 'consumo',
      titulo: 'CONSUMO PREVISTO',
      icone: Symbols.analytics,
      cor: const Color(0xFFE65100),
      badge: totalGeral.toKg(),
      child: produtos.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Nenhum consumo pendente.',
                  style: AppCss.minimumRegular.setColor(Colors.grey[400]!),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: produtos.map((p) {
                  final peso = (consumoMap[p.id] ?? 0.0);
                  final prc = totalGeral > 0 ? peso / totalGeral : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.descricao,
                            style: AppCss.minimumRegular.setSize(11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const W(6),
                        SizedBox(
                          width: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: prc,
                              backgroundColor: Colors.grey[100],
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFE65100)),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const W(8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            peso.toKg(),
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(const Color(0xFFE65100)),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ESTOQUE PROJETADO
  // ═══════════════════════════════════════════════════
  Widget _secaoEstoqueProjetado() {
    final todosProdutos = BackendClient.bitolas.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    final consumoMap = dashCtrl.getConsumoEstimado();
    final List<_EstoqueProjetadoItem> itens = [];
    double tSaldo = 0, tPedido = 0, tConsumo = 0;

    for (final p in todosProdutos) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      final saldo = estoque?.quantidade ?? 0.0;
      final consumo = consumoMap[p.id] ?? 0.0;
      final emPedido =
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(p.id);
      if (saldo == 0 && consumo == 0 && emPedido == 0) continue;
      final projetado = saldo + emPedido - consumo;
      itens.add(_EstoqueProjetadoItem(
        nome: p.nome,
        saldo: saldo,
        emPedido: emPedido,
        consumo: consumo,
        projetado: projetado,
      ));
      tSaldo += saldo;
      tPedido += emPedido;
      tConsumo += consumo;
    }
    final tProjetado = tSaldo + tPedido - tConsumo;

    return _secaoContainer(
      chave: 'estoque',
      titulo: 'ESTOQUE PROJETADO',
      icone: Icons.bar_chart_rounded,
      cor: const Color(0xFF1565C0),
      badge: tProjetado.toKg(),
      child: itens.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Sem dados de estoque.',
                  style: AppCss.minimumRegular.setColor(Colors.grey[400]!),
                ),
              ),
            )
          : Column(
              children: [
                // Totais compactos
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _totalChip('Saldo', tSaldo.toKg(),
                          const Color(0xFF1565C0)),
                      const Spacer(),
                      _totalChip(
                          'Pedido',
                          tPedido > 0 ? '+${tPedido.toKg()}' : '---',
                          const Color(0xFF00897B)),
                      const Spacer(),
                      _totalChip('-Consumo', tConsumo.toKg(),
                          const Color(0xFFE65100)),
                      const Spacer(),
                      _totalChip(
                          '= Projetado',
                          tProjetado.toKg(),
                          tProjetado < 0
                              ? Colors.red[700]!
                              : const Color(0xFF1B5E20)),
                    ],
                  ),
                ),
                // Lista de itens
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: itens.map((item) {
                      final isNegativo = item.projetado < 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isNegativo
                              ? Colors.red[50]
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNegativo
                                ? Colors.red[200]!
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isNegativo)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(Icons.warning_amber,
                                        size: 12, color: Colors.red[700]),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.nome,
                                    style: AppCss.minimumBold.setSize(11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  item.projetado.toKg(),
                                  style: AppCss.minimumBold.setSize(11).setColor(
                                      isNegativo
                                          ? Colors.red[700]!
                                          : const Color(0xFF1B5E20)),
                                ),
                              ],
                            ),
                            const H(4),
                            Row(
                              children: [
                                _estoqueDetalhe(
                                    'Saldo',
                                    item.saldo.toKg(),
                                    const Color(0xFF1565C0)),
                                const W(8),
                                if (item.emPedido > 0)
                                  _estoqueDetalhe(
                                      'Ped.',
                                      '+${item.emPedido.toKg()}',
                                      const Color(0xFF00897B)),
                                if (item.emPedido > 0) const W(8),
                                _estoqueDetalhe(
                                    'Cons.',
                                    '-${item.consumo.toKg()}',
                                    const Color(0xFFE65100)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _totalChip(String label, String valor, Color cor) {
    return Column(
      children: [
        Text(label,
            style:
                AppCss.minimumRegular.setSize(8).setColor(Colors.grey[500]!)),
        Text(valor, style: AppCss.minimumBold.setSize(10).setColor(cor)),
      ],
    );
  }

  Widget _estoqueDetalhe(String label, String valor, Color cor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style:
              AppCss.minimumRegular.setSize(9).setColor(Colors.grey[400]!),
        ),
        Text(
          valor,
          style: AppCss.minimumBold.setSize(9).setColor(cor),
        ),
      ],
    );
  }
}

class _EstoqueProjetadoItem {
  final String nome;
  final double saldo;
  final double emPedido;
  final double consumo;
  final double projetado;

  _EstoqueProjetadoItem({
    required this.nome,
    required this.saldo,
    required this.emPedido,
    required this.consumo,
    required this.projetado,
  });
}
