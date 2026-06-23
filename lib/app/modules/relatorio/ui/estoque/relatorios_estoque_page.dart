import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RelatoriosEstoquePage extends StatefulWidget {
  const RelatoriosEstoquePage({super.key});

  @override
  State<RelatoriosEstoquePage> createState() => _RelatoriosEstoquePageState();
}

class _RelatoriosEstoquePageState extends State<RelatoriosEstoquePage> {
  // Controla quais produtos estão expandidos
  final Map<String, bool> _expandedPedidos = {};

  @override
  void initState() {
    setWebTitle('Relatório de Estoque');
    baseCtrl.appBarActionsStream.add(<Widget>[]);
    relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    relatorioCtrl.onCreateRelatorioPedido();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: BackendClient.estoques.dataStream.listen,
      builder: (_, __) => StreamOut(
        stream: BackendClient.pedidosCompra.dataStream.listen,
        builder: (_, ___) => StreamOut(
          stream: FirestoreClient.pedidos.dataStream.listen,
          builder: (_, __) => StreamOut<RelatorioPedidoViewModel>(
            stream: relatorioCtrl.pedidoViewModelStream.listen,
            builder: (_, model) => _body(model),
          ),
        ),
      ),
    );
  }

  Widget _body(RelatorioPedidoViewModel model) {
    final produtos = BackendClient.bitolas.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    if (produtos.isEmpty) {
      return const Center(child: Text('Nenhum produto cadastrado'));
    }

    // Consumo previsto por produto
    final Map<String, double> consumoMap = {};
    for (final produto in produtos) {
      final total = relatorioCtrl.getPedidosTotalPorBitola(produto);
      if (total > 0) consumoMap[produto.id] = total;
    }

    // Totais globais
    double totalSaldo = 0, totalConsumo = 0, totalEmPedido = 0;
    for (final p in produtos) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      totalSaldo += estoque?.quantidade ?? 0.0;
      totalConsumo += consumoMap[p.id] ?? 0.0;
      totalEmPedido +=
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(p.id);
    }
    final totalSaldoFinal = totalSaldo - totalConsumo + totalEmPedido;

    return Column(
      children: [
        _totaisHeader(totalSaldo, totalConsumo, totalEmPedido, totalSaldoFinal),
        const Divider(height: 1),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFEEF2F7),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: produtos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final produto = produtos[i];
                final estoque =
                    BackendClient.estoques.getByProdutoId(produto.id);
                final saldoAtual = estoque?.quantidade ?? 0.0;
                final consumoPrevisto = consumoMap[produto.id] ?? 0.0;
                final itensPedido = BackendClient.pedidosCompra
                    .getPendentesByProdutoId(produto.id);
                final totalEmPedidoProduto =
                    BackendClient.pedidosCompra
                        .getTotalPendenteByProdutoId(produto.id);
                final saldoFinal =
                    saldoAtual - consumoPrevisto + totalEmPedidoProduto;

                return _produtoCard(
                  produto,
                  saldoAtual,
                  consumoPrevisto,
                  itensPedido,
                  totalEmPedidoProduto,
                  saldoFinal,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Cabeçalho com KPIs totais ──────────────────────────────────────────────

  Widget _totaisHeader(
      double saldo, double consumo, double emPedido, double saldoFinal) {
    final negativo = saldoFinal < 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined,
                size: 16, color: AppColors.primaryMain),
            const SizedBox(width: 6),
            Text('Previsão de Consumo vs. Estoque',
                style: AppCss.minimumBold.setColor(AppColors.primaryMain)),

          ]),
          const SizedBox(height: 4),
          Text(
            'Saldo físico, abatido do consumo previsto nas ordens, '
            'acrescido dos pedidos de compra em aberto.',
            style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
          ),
          const SizedBox(height: 10),
          // 4 KPIs em uma única linha
          Row(children: [
            _kpi('Saldo Físico', saldo.toKg(), Colors.blue[700]!,
                Icons.account_balance_outlined),
            const SizedBox(width: 6),
            _kpi('Consumo Previsto', '-${consumo.toKg()}',
                Colors.orange[700]!, Icons.arrow_downward_rounded),
            const SizedBox(width: 6),
            _kpi(
              'Em Pedido',
              emPedido > 0 ? '+${emPedido.toKg()}' : '—',
              Colors.blue[600]!,
              Icons.shopping_cart_outlined,
            ),
            const SizedBox(width: 6),
            _kpi(
              'Projetado',
              saldoFinal.toKg(),
              negativo ? Colors.red[700]! : Colors.green[700]!,
              negativo
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
            ),
          ]),
        ],
      ),
    );
  }


  Widget _kpi(String label, String valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: cor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppCss.minimumRegular
                          .setSize(9)
                          .setColor(Colors.grey[500]!)),
                  Text(valor, style: AppCss.minimumBold.setColor(cor)),
                ]),
          ),
        ]),
      ),
    );
  }

  // ── Card por produto ───────────────────────────────────────────────────────

  Widget _produtoCard(
    BitolaModel produto,
    double saldoAtual,
    double consumoPrevisto,
    List<PedidoCompraModel> itensPedido,
    double totalEmPedido,
    double saldoFinal,
  ) {
    final negativo = saldoFinal < 0;
    final semConsumo = consumoPrevisto == 0;
    final temPedidos = itensPedido.isNotEmpty;
    final isExpanded = _expandedPedidos[produto.id] ?? false;

    // Agrupa por grupoId para mostrar 1 linha por pedido
    final Map<String, List<PedidoCompraModel>> grupos = {};
    for (final item in itensPedido) {
      grupos.putIfAbsent(item.grupoId, () => []).add(item);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showConsumoPrevisto(produto, saldoAtual, consumoPrevisto),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: negativo
              ? Colors.red.withValues(alpha: 0.60)
              : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Linha principal ──────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              // Ícone
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: negativo
                      ? Colors.red.withValues(alpha: 0.08)
                      : AppColors.primaryMain.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: negativo ? Colors.red[700]! : AppColors.primaryMain,
                ),
              ),
              const SizedBox(width: 10),
              // Nome
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produto.nome, style: AppCss.minimumBold),
                      Text(produto.descricao,
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[500]!)),
                    ]),
              ),
              const SizedBox(width: 8),
              // Colunas de valores — sempre 4 colunas para alinhar
              _valorCol('Saldo', saldoAtual.toKg(), Colors.blue[700]!),
              _seta(),
              _valorCol(
                'Consumo',
                semConsumo ? '—' : '-${consumoPrevisto.toKg()}',
                semConsumo ? Colors.grey[400]! : Colors.orange[700]!,
              ),
              _seta(),
              _valorCol(
                '+Pedido',
                temPedidos ? '+${totalEmPedido.toKg()}' : '—',
                temPedidos ? Colors.blue[600]! : Colors.grey[350]!,
              ),
              _seta(),
              _valorCol(
                'Projetado',
                saldoFinal.toKg(),
                negativo ? Colors.red[700]! : Colors.green[700]!,
                bold: true,
              ),
            ]),
          ),

          // ── Linha "Em pedido" expansível ─────────────────────────────
          if (temPedidos)
            InkWell(
              onTap: () => setState(
                  () => _expandedPedidos[produto.id] = !isExpanded),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 7, 16, 7),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.04),
                  border: Border(
                    top: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.15)),
                    bottom: isExpanded
                        ? BorderSide.none
                        : BorderSide(
                            color: Colors.blue.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 13, color: Colors.blue[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${grupos.length} pedido${grupos.length > 1 ? 's' : ''} em aberto · +${totalEmPedido.toKg()}',
                    style: AppCss.minimumRegular
                        .setColor(Colors.blue[700]!)
                        .setSize(12),
                  ),
                  const Spacer(),
                  Text(
                    isExpanded ? 'Ocultar' : 'Ver detalhes',
                    style: AppCss.minimumRegular
                        .setColor(Colors.blue[400]!)
                        .setSize(11),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 15,
                    color: Colors.blue[400],
                  ),
                ]),
              ),
            ),

          // ── Detalhe por pedido (grupoId) ─────────────────────────────
          if (temPedidos && isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.025),
                border: Border(
                  bottom: BorderSide(
                      color: Colors.blue.withValues(alpha: 0.15)),
                ),
              ),
              child: Column(
                children: grupos.entries.map((entry) {
                  final itensGrupo = entry.value;
                  final qtdeGrupo = itensGrupo
                      .fold<double>(0, (s, i) => s + i.quantidade);
                  final first = itensGrupo.first;
                  final isConfirmado =
                      first.status == PedidoCompraStatus.confirmado;

                  return Container(
                    padding:
                        const EdgeInsets.fromLTRB(24, 6, 16, 6),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color:
                                Colors.blue.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        isConfirmado
                            ? Icons.thumb_up_outlined
                            : Icons.pending_outlined,
                        size: 12,
                        color: isConfirmado
                            ? Colors.blue[500]
                            : Colors.orange[500],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(first.fabricante.nome,
                                style: AppCss.minimumBold
                                    .setColor(Colors.grey[700]!)
                                    .setSize(12)),
                            Text(first.createdAt.ddMMyyyy(),
                                style: AppCss.minimumRegular
                                    .setColor(Colors.grey[400]!)
                                    .setSize(10)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isConfirmado
                              ? Colors.blue.withValues(alpha: 0.10)
                              : Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isConfirmado ? 'Confirmado' : 'Pendente',
                          style: AppCss.minimumBold
                              .setColor(isConfirmado
                                  ? Colors.blue[700]!
                                  : Colors.orange[700]!)
                              .setSize(9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${qtdeGrupo.toKg()}',
                        style: AppCss.minimumBold
                            .setColor(Colors.blue[600]!)
                            .setSize(12),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _valorCol(String label, String valor, Color cor,
      {bool bold = false}) {
    return SizedBox(
      width: 72,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label,
            style: AppCss.minimumRegular
                .setSize(9)
                .setColor(Colors.grey[400]!)),
        Text(
          valor,
          style: bold
              ? AppCss.minimumBold.setColor(cor)
              : AppCss.minimumRegular.setColor(cor),
          textAlign: TextAlign.right,
        ),
      ]),
    );
  }

  Widget _seta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios_rounded,
          size: 10, color: Colors.grey[300]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG 📊 — CONSUMO PREVISTO POR BITOLA
  // ═══════════════════════════════════════════════════════════════════════════

  static const _vermelho = Color(0xFFDC2626);
  static const _verde = Color(0xFF16A34A);

  Future<void> _showConsumoPrevisto(
    BitolaModel produto,
    double saldoAtual,
    double consumoPrevistoTotal,
  ) async {
    // Coleta os pedidos individuais que consomem esta bitola
    final consumos = <_ConsumoPrevisto>[];
    if (relatorioCtrl.pedidoViewModelStream.hasValue &&
        relatorioCtrl.pedidoViewModel.relatorio != null) {
      for (final pedido in relatorioCtrl.pedidoViewModel.relatorio!.pedidos) {
        for (final prod in pedido.produtos) {
          if (prod.produto.id != produto.id) continue;
          if (prod.qtde <= 0) continue;
          consumos.add(_ConsumoPrevisto(
            localizador: pedido.localizador,
            clienteNome: pedido.cliente.nome,
            obraNome: pedido.obra.descricao,
            quantidade: prod.qtde,
            status: prod.statusView.status,
          ));
        }
      }
    }
    consumos.sort((a, b) => a.localizador.compareTo(b.localizador));

    final totalConsumo = consumos.fold(0.0, (s, e) => s + e.quantidade);
    final saldoFinal = saldoAtual - totalConsumo;

    // Pré-calcula saldo acumulado para cada linha
    final saldosAcumulados = <double>[];
    double saldoCorrente = saldoAtual;
    for (final c in consumos) {
      saldoCorrente -= c.quantidade;
      saldosAcumulados.add(saldoCorrente);
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.analytics_outlined,
                size: 18, color: AppColors.primaryMain),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consumo Previsto', style: AppCss.mediumBold),
                Text(produto.nome,
                    style: AppCss.minimumRegular
                        .setColor(Colors.grey[500]!)
                        .setSize(12)),
              ],
            ),
          ),
        ]),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
            maxWidth: 520,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Saldo Atual ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryMain.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 16, color: AppColors.primaryMain),
                    const SizedBox(width: 8),
                    Text('Saldo Atual',
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[600]!)),
                    const Spacer(),
                    Text(saldoAtual.toKg(),
                        style: AppCss.mediumBold
                            .setColor(AppColors.primaryMain)),
                  ]),
                ),
                const SizedBox(height: 12),

                if (consumos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(children: [
                      Icon(Icons.check_circle_outline,
                          size: 40, color: Colors.green[300]),
                      const SizedBox(height: 8),
                      Text('Nenhum pedido pendente',
                          style: AppCss.minimumBold
                              .setColor(Colors.grey[500]!)),
                      Text('para esta bitola',
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[400]!)),
                    ]),
                  )
                else ...[
                  // ── Header da lista ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(children: [
                      Icon(Icons.format_list_bulleted,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        '${consumos.length} pedido${consumos.length > 1 ? 's' : ''} pendente${consumos.length > 1 ? 's' : ''}',
                        style: AppCss.minimumBold
                            .setColor(Colors.grey[600]!)
                            .setSize(12),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${totalConsumo.toKg()}',
                          style: AppCss.minimumBold
                              .setColor(Colors.orange[700]!)
                              .setSize(11),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),

                  // ── Lista de consumos ────────────────────────
                  ...consumos.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final saldoAcum = saldosAcumulados[i];
                    final isNegativo = saldoAcum < 0;

                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.12),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _corStatus(item.status)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  _iconeStatus(item.status),
                                  size: 14,
                                  color: _corStatus(item.status),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.localizador,
                                      style: AppCss.minimumBold.setSize(12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.clienteNome} · ${item.obraNome}',
                                      style: AppCss.minimumRegular
                                          .setColor(Colors.grey[400]!)
                                          .setSize(10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '-${item.quantidade.toKg()}',
                                    style: AppCss.minimumBold
                                        .setColor(Colors.orange[700]!)
                                        .setSize(12),
                                  ),
                                  Text(
                                    'Saldo: ${saldoAcum.toKg()}',
                                    style: AppCss.minimumRegular
                                        .setColor(isNegativo
                                            ? _vermelho
                                            : Colors.grey[400]!)
                                        .setSize(10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),

                  // ── Saldo Final Projetado ────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: saldoFinal < 0
                          ? _vermelho.withValues(alpha: 0.06)
                          : _verde.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: saldoFinal < 0
                            ? _vermelho.withValues(alpha: 0.20)
                            : _verde.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        saldoFinal < 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 16,
                        color: saldoFinal < 0 ? _vermelho : _verde,
                      ),
                      const SizedBox(width: 8),
                      Text('Saldo Final Projetado',
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[600]!)),
                      const Spacer(),
                      Text(
                        saldoFinal.toKg(),
                        style: AppCss.mediumBold.setColor(
                            saldoFinal < 0 ? _vermelho : _verde),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _exportarConsumoPrevistoPdf(
              produto, saldoAtual, consumos, saldosAcumulados, totalConsumo, saldoFinal,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Exportar PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — EXPORTAR CONSUMO PREVISTO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _exportarConsumoPrevistoPdf(
    BitolaModel produto,
    double saldoAtual,
    List<_ConsumoPrevisto> consumos,
    List<double> saldosAcumulados,
    double totalConsumo,
    double saldoFinal,
  ) async {
    final logoBytes = await LogoHelper.logoBytesForPdf();
    final pdf = pw.Document();
    final agora = DateTime.now();
    final fmtData = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      header: (_) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              pw.Image(pw.MemoryImage(logoBytes), width: 45, height: 45),
              pw.SizedBox(width: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CONSUMO PREVISTO — ${produto.nome}',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800)),
                  pw.Text('Projeção de consumo por pedido pendente',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ]),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Gerado em: ${fmtData.format(agora)}',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Relatório Administrativo',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                        fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ],
        ),
      ),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Documento para análise de estoque',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      build: (pw.Context context) => [
        // ── KPIs ──────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.blue100),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfKpi('SALDO ATUAL', saldoAtual.toKg()),
              _pdfKpi('CONSUMO PREVISTO', '-${totalConsumo.toKg()}'),
              _pdfKpi(
                'SALDO PROJETADO',
                saldoFinal.toKg(),
                cor: saldoFinal < 0 ? PdfColors.red700 : PdfColors.green700,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ── Tabela ────────────────────────────────────
        if (consumos.isEmpty)
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 30),
              child: pw.Text('Nenhum pedido pendente para esta bitola.',
                  style: pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey600)),
            ),
          )
        else ...[
          pw.Text('DETALHAMENTO POR PEDIDO',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['LOCALIZADOR', 'CLIENTE', 'OBRA', 'STATUS', 'CONSUMO', 'SALDO'],
            data: [
              ...consumos.asMap().entries.map((entry) {
                final item = entry.value;
                final saldoAcum = saldosAcumulados[entry.key];
                return [
                  item.localizador,
                  item.clienteNome,
                  item.obraNome,
                  _statusLabel(item.status),
                  '-${item.quantidade.toKg()}',
                  saldoAcum.toKg(),
                ];
              }),
              // Linha de totais
              ['', '', '', 'TOTAL', '-${totalConsumo.toKg()}', saldoFinal.toKg()],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColors.grey50),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
            },
          ),
        ],
      ],
    ));

    final nome =
        'consumo_previsto_${produto.nome.toLowerCase().replaceAll(' ', '_')}${DateTime.now().toFileName()}.pdf';
    await downloadPDF(nome, '/relatorio/estoque/', await pdf.save());
  }

  pw.Widget _pdfKpi(String titulo, String valor, {PdfColor? cor}) {
    return pw.Column(children: [
      pw.Text(titulo,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey600)),
      pw.SizedBox(height: 4),
      pw.Text(valor,
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: cor ?? PdfColors.blueGrey900)),
    ]);
  }

  String _statusLabel(PedidoBitolaStatus status) {
    switch (status) {
      case PedidoBitolaStatus.separado:
        return 'Separado';
      case PedidoBitolaStatus.aguardandoProducao:
        return 'Aguardando';
      case PedidoBitolaStatus.produzindo:
        return 'Produzindo';
      case PedidoBitolaStatus.pronto:
        return 'Pronto';
    }
  }

  // ── Helpers de status ─────────────────────────────────────────────────────

  Color _corStatus(PedidoBitolaStatus status) {
    switch (status) {
      case PedidoBitolaStatus.separado:
        return Colors.amber[700]!;
      case PedidoBitolaStatus.aguardandoProducao:
        return Colors.blueGrey;
      case PedidoBitolaStatus.produzindo:
        return Colors.blue[600]!;
      case PedidoBitolaStatus.pronto:
        return _verde;
    }
  }

  IconData _iconeStatus(PedidoBitolaStatus status) {
    switch (status) {
      case PedidoBitolaStatus.separado:
        return Icons.content_cut;
      case PedidoBitolaStatus.aguardandoProducao:
        return Icons.access_time;
      case PedidoBitolaStatus.produzindo:
        return Icons.build_outlined;
      case PedidoBitolaStatus.pronto:
        return Icons.check;
    }
  }
}

// ── Modelo auxiliar de consumo previsto ───────────────────────────────────────
class _ConsumoPrevisto {
  final String localizador;
  final String clienteNome;
  final String obraNome;
  final double quantidade;
  final PedidoBitolaStatus status;

  const _ConsumoPrevisto({
    required this.localizador,
    required this.clienteNome,
    required this.obraNome,
    required this.quantidade,
    required this.status,
  });
}