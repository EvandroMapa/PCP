import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';

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
    final produtos = BackendClient.produtos.data.toList()
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
    ProdutoModel produto,
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

    return Container(
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
}