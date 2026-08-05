import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:flutter/material.dart';

class EstoqueRelatorioSection extends StatefulWidget {
  const EstoqueRelatorioSection({super.key});

  @override
  State<EstoqueRelatorioSection> createState() => _EstoqueRelatorioSectionState();
}

class _EstoqueRelatorioSectionState extends State<EstoqueRelatorioSection> {
  @override
  Widget build(BuildContext context) {
    return StreamOut<EstoqueRelatorioFiltroModel>(
      stream: estoqueCtrl.relatorioFiltroStream.listen,
      builder: (_, filtro) => StreamOut(
        stream: BackendClient.estoquesMovimentacao.dataStream.listen,
        builder: (_, __) => Column(
          children: [
            _filtros(filtro),
            const Divider(height: 1),
            _resumo(),
            const Divider(height: 1),
            Expanded(child: _listaMovimentacoes()),
          ],
        ),
      ),
    );
  }

  Widget _filtros(EstoqueRelatorioFiltroModel filtro) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart_outlined, size: 18, color: AppColors.primaryMain),
            const SizedBox(width: 8),
            Text('Relatório de Estoque', style: AppCss.mediumBold),
            const Spacer(),
            if (filtro.temFiltro)
              TextButton.icon(
                onPressed: () {
                  filtro.limpar();
                  estoqueCtrl.relatorioFiltroStream.update();
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Limpar filtros', style: TextStyle(fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 10),
          AppDropDown<BitolaModel?>(
            label: 'Produto (todos)',
            item: filtro.produtoId != null
                ? BackendClient.bitolas.data.cast<BitolaModel?>().firstWhere(
                      (e) => e?.id == filtro.produtoId,
                      orElse: () => null,
                    )
                : null,
            itens: [null, ...BackendClient.bitolas.data],
            itemLabel: (e) => e == null ? 'Todos os produtos' : '${e.nome} — ${e.descricao}',
            onSelect: (e) {
              filtro.produtoId = e?.id;
              estoqueCtrl.relatorioFiltroStream.update();
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _dateButton(
                label: filtro.dataInicio != null
                    ? filtro.dataInicio!.text()
                    : 'Data início',
                icon: Icons.calendar_today_outlined,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: filtro.dataInicio ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    filtro.dataInicio = d;
                    estoqueCtrl.relatorioFiltroStream.update();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateButton(
                label: filtro.dataFim != null ? filtro.dataFim!.text() : 'Data fim',
                icon: Icons.calendar_today_outlined,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: filtro.dataFim ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    filtro.dataFim = d;
                    estoqueCtrl.relatorioFiltroStream.update();
                  }
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _dateButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        foregroundColor: Colors.grey[700],
      ),
    );
  }

  Widget _resumo() {
    final filtro = estoqueCtrl.relatorioFiltro;
    final movs = estoqueCtrl.getMovimentacoesFiltradas();
    final entradas = movs.where((e) => e.tipo.isEntrada).fold(0.0, (s, e) => s + e.quantidade);
    final saidas = movs.where((e) => !e.tipo.isEntrada).fold(0.0, (s, e) => s + e.quantidade.abs());

    // Saldo atual do bitola selecionada (ou soma total) — calculado pelas movimentações
    final saldoAtual = filtro.produtoId != null
        ? estoqueCtrl.getSaldoCalculado(filtro.produtoId!)
        : BackendClient.bitolas.data
            .fold(0.0, (s, p) => s + estoqueCtrl.getSaldoCalculado(p.id));
    final saldoNegativo = saldoAtual < 0;

    return Container(
      color: const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _kpiCard('Entradas', entradas.toKg(), Colors.green[600]!, Icons.arrow_upward_rounded),
            const SizedBox(width: 8),
            _kpiCard('Saídas (Produção)', saidas.toKg(), Colors.orange[600]!, Icons.arrow_downward_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpiCard(
              filtro.produtoId != null ? 'Saldo Atual (produto)' : 'Saldo Total',
              saldoAtual.toKg(),
              saldoNegativo ? Colors.red[700]! : AppColors.primaryMain,
              saldoNegativo ? Icons.warning_amber_rounded : Icons.account_balance_outlined,
            ),
            const SizedBox(width: 8),
            _kpiCard('Registros', '${movs.length}', Colors.grey[600]!, Icons.receipt_long_outlined),
          ]),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[500]!)),
              Text(valor, style: AppCss.minimumBold.setColor(cor)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _listaMovimentacoes() {
    final movs = estoqueCtrl.getMovimentacoesFiltradas();
    if (movs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('Nenhuma movimentação encontrada',
              style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: movs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _itemMov(movs[i]),
    );
  }

  Widget _itemMov(EstoqueMovimentacaoModel mov) {
    final isEntrada = mov.tipo.isEntrada;
    final cor = mov.tipo.cor;
    final qtdeTxt = isEntrada
        ? '+${mov.quantidade.abs().toKg()}'
        : '-${mov.quantidade.abs().toKg()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(mov.tipo.icone, size: 15, color: cor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(mov.produto.nome, style: AppCss.minimumBold),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(mov.tipo.label,
                    style: AppCss.minimumBold.setSize(9).setColor(cor)),
              ),
            ]),
            if (mov.observacao != null && mov.observacao!.isNotEmpty)
              Text(mov.observacao!,
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
            Row(children: [
              Text(mov.dataHora.text(),
                  style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[400]!)),
              if (mov.usuarioNome != null) ...[ 
                Text(' · ', style: AppCss.minimumRegular.setColor(Colors.grey[300]!)),
                Text(mov.usuarioNome!,
                    style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[400]!)),
              ],
            ]),
          ]),
        ),
        Text(qtdeTxt,
            style: AppCss.minimumBold.setColor(isEntrada ? Colors.green[600]! : Colors.orange[600]!)),
      ]),
    );
  }
}
