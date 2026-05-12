import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
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
  @override
  void initState() {
    setWebTitle('Relatório de Estoque');
    baseCtrl.appBarActionsStream.add(<Widget>[]);
    // Inicializa o relatorioCtrl com filtros padrão (igual ao Relatório de Consumo)
    relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    relatorioCtrl.onCreateRelatorioPedido();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: BackendClient.estoques.dataStream.listen,
      builder: (_, __) => StreamOut(
        stream: FirestoreClient.pedidos.dataStream.listen,
        builder: (_, __) => StreamOut<RelatorioPedidoViewModel>(
          stream: relatorioCtrl.pedidoViewModelStream.listen,
          builder: (_, model) => _body(model),
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

    final Map<String, double> consumoMap = {};
    for (final produto in produtos) {
      final total = relatorioCtrl.getPedidosTotalPorBitola(produto);
      if (total > 0) consumoMap[produto.id] = total;
    }

    final totalSaldo = produtos.fold(0.0, (s, p) {
      final estoque = BackendClient.estoques.getByProdutoId(p.id);
      return s + (estoque?.quantidade ?? 0.0);
    });
    final totalConsumo = consumoMap.values.fold(0.0, (s, v) => s + v);
    final totalSaldoFinal = totalSaldo - totalConsumo;

    return Column(
      children: [
        _totaisHeader(totalSaldo, totalConsumo, totalSaldoFinal),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: produtos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final produto = produtos[i];
              final estoque = BackendClient.estoques.getByProdutoId(produto.id);
              final saldoAtual = estoque?.quantidade ?? 0.0;
              final consumoPrevisto = consumoMap[produto.id] ?? 0.0;
              final saldoFinal = saldoAtual - consumoPrevisto;
              return _produtoCard(produto, saldoAtual, consumoPrevisto, saldoFinal);
            },
          ),
        ),
      ],
    );
  }

  Widget _totaisHeader(double saldo, double consumo, double saldoFinal) {
    final negativo = saldoFinal < 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primaryMain),
            const SizedBox(width: 6),
            Text('Previsão de Consumo vs. Estoque',
                style: AppCss.minimumBold.setColor(AppColors.primaryMain)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Saldo atual abatido do consumo previsto nas ordens em produção (itens não prontos).',
            style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _kpi('Saldo Atual', saldo.toKg(), Colors.blue[700]!, Icons.account_balance_outlined),
            const SizedBox(width: 8),
            _kpi('Consumo Previsto', consumo.toKg(), Colors.orange[700]!, Icons.arrow_downward_rounded),
            const SizedBox(width: 8),
            _kpi(
              'Saldo Final',
              saldoFinal.toKg(),
              negativo ? Colors.red[700]! : Colors.green[700]!,
              negativo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppCss.minimumRegular.setSize(9).setColor(Colors.grey[500]!)),
              Text(valor, style: AppCss.minimumBold.setColor(cor)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _produtoCard(ProdutoModel produto, double saldoAtual,
      double consumoPrevisto, double saldoFinal) {
    final negativo = saldoFinal < 0;
    final semConsumo = consumoPrevisto == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: negativo
              ? Colors.red.withValues(alpha: 0.40)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: negativo
                  ? Colors.red.withValues(alpha: 0.08)
                  : AppColors.primaryMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 17,
              color: negativo ? Colors.red[700]! : AppColors.primaryMain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(produto.nome, style: AppCss.minimumBold),
              Text(produto.descricao,
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
            ]),
          ),
          const SizedBox(width: 12),
          _valorCol('Saldo', saldoAtual.toKg(), Colors.blue[700]!),
          const SizedBox(width: 8),
          _seta(),
          const SizedBox(width: 8),
          _valorCol(
            'Consumo',
            semConsumo ? '—' : '-${consumoPrevisto.toKg()}',
            semConsumo ? Colors.grey[400]! : Colors.orange[700]!,
          ),
          const SizedBox(width: 8),
          _seta(),
          const SizedBox(width: 8),
          _valorCol(
            'Saldo Final',
            saldoFinal.toKg(),
            negativo ? Colors.red[700]! : Colors.green[700]!,
            bold: true,
          ),
        ]),
      ),
    );
  }

  Widget _valorCol(String label, String valor, Color cor, {bool bold = false}) {
    return SizedBox(
      width: 80,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: AppCss.minimumRegular.setSize(9).setColor(Colors.grey[400]!)),
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
    return Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey[300]);
  }
}
