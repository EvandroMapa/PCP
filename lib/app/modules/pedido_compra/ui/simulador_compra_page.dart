import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class SimuladorCompraPage extends StatefulWidget {
  const SimuladorCompraPage({super.key});

  @override
  State<SimuladorCompraPage> createState() => _SimuladorCompraPageState();
}

class _SimuladorCompraPageState extends State<SimuladorCompraPage> {
  @override
  void initState() {
    super.initState();
    simuladorCompraCtrl.calcularNecessidades();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Simulador de Compra',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryMain,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Tooltip(
            message: 'Recalcular',
            child: IconButton(
              onPressed: () => simuladorCompraCtrl.calcularNecessidades(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamOut<SimuladorCompraModel?>(
        stream: simuladorCompraCtrl.modelStream.listen,
        builder: (_, model) {
          if (model == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, model);
        },
      ),
    );
  }

  Widget _body(BuildContext context, SimuladorCompraModel model) {
    return Column(
      children: [
        // ── KPIs resumo ──────────────────────────────────────────────
        _kpisHeader(model),
        const Divider(height: 1),
        // ── Conteúdo scrollável ──────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Gráfico
              _graficoCard(model),
              const SizedBox(height: 12),
              // Ações em massa
              _acoesMassa(model),
              const SizedBox(height: 8),
              // Lista de produtos
              ...model.itens.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _produtoCard(entry.value),
                    ),
                  ),
              const SizedBox(height: 70), // espaço para o botão
            ],
          ),
        ),
        // ── Botão fixo: gerar pedido ────────────────────────────────
        _botaoGerarPedido(context, model),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KPIs
  // ─────────────────────────────────────────────────────────────────────────

  Widget _kpisHeader(SimuladorCompraModel model) {
    final negativo = model.totalProjetado < 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.analytics_outlined,
                size: 16, color: AppColors.primaryMain),
            const SizedBox(width: 6),
            Text('Análise de Necessidade de Compra',
                style: AppCss.minimumBold.setColor(AppColors.primaryMain)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Necessidade = Consumo + Estoque Mínimo − Saldo Físico − Em Pedido',
            style: AppCss.minimumRegular
                .setColor(Colors.grey[500]!)
                .setSize(11),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _kpi('Saldo Físico', model.totalSaldoFisico.toKg(),
                Colors.blue[700]!, Icons.account_balance_outlined),
            const SizedBox(width: 6),
            _kpi(
                'Consumo Prev.',
                '-${model.totalConsumoPrevisto.toKg()}',
                Colors.orange[700]!,
                Icons.arrow_downward_rounded),
            const SizedBox(width: 6),
            _kpi(
              'Em Pedido',
              model.totalEmPedido > 0
                  ? '+${model.totalEmPedido.toKg()}'
                  : '—',
              Colors.blue[600]!,
              Icons.shopping_cart_outlined,
            ),
            const SizedBox(width: 6),
            _kpi(
              'Projetado',
              model.totalProjetado.toKg(),
              negativo ? Colors.red[700]! : Colors.green[700]!,
              negativo
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
            ),
          ]),
          if (model.totalComDeficit > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.20)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.red[700]),
                const SizedBox(width: 6),
                Text(
                  '${model.totalComDeficit} produto${model.totalComDeficit > 1 ? 's' : ''} com déficit · Sugestão: ${model.totalSugerido.toKg()}',
                  style: AppCss.minimumBold
                      .setColor(Colors.red[700]!)
                      .setSize(12),
                ),
              ]),
            ),
          ],
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

  // ─────────────────────────────────────────────────────────────────────────
  // Gráfico
  // ─────────────────────────────────────────────────────────────────────────

  Widget _graficoCard(SimuladorCompraModel model) {
    // Filtra apenas os que têm dados relevantes
    final data = model.itens
        .where(
            (i) => i.saldoFisico != 0 || i.consumoPrevisto != 0 || i.emPedido != 0)
        .toList();

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('Nenhum dado para exibir no gráfico')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Icon(Icons.bar_chart_rounded,
                  size: 16, color: AppColors.primaryMain),
              const SizedBox(width: 6),
              Text('Visão Geral por Produto',
                  style: AppCss.minimumBold.setSize(13)),
            ]),
          ),
          // Legenda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legItem('Saldo', const Color(0xFF1565C0)),
                const SizedBox(width: 10),
                _legItem('Em Pedido', const Color(0xFF00897B)),
                const SizedBox(width: 10),
                _legItem('Consumo', const Color(0xFFE65100)),
                const SizedBox(width: 10),
                _legItem('Sugestão', const Color(0xFF2E7D32)),
              ],
            ),
          ),
          // Gráfico
          SizedBox(
            height: 260,
            child: SfCartesianChart(
              margin: const EdgeInsets.fromLTRB(8, 0, 16, 8),
              plotAreaBorderWidth: 0,
              primaryXAxis: const CategoryAxis(
                labelRotation: -30,
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(width: 0.5),
                labelStyle: TextStyle(fontSize: 10),
              ),
              primaryYAxis: const NumericAxis(
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(size: 0),
                labelStyle: TextStyle(fontSize: 10),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                header: '',
                canShowMarker: true,
                format: 'series.name: point.y kg',
              ),
              series: <CartesianSeries>[
                // Disponível: Saldo Físico
                StackedColumnSeries<SimuladorCompraItem, String>(
                  dataSource: data,
                  xValueMapper: (d, __) => d.produto.nome,
                  yValueMapper: (d, __) => d.saldoFisico,
                  name: 'Saldo',
                  color: const Color(0xFF1565C0),
                  groupName: 'disponivel',
                  borderRadius: BorderRadius.zero,
                ),
                // Disponível: Em Pedido
                StackedColumnSeries<SimuladorCompraItem, String>(
                  dataSource: data,
                  xValueMapper: (d, __) => d.produto.nome,
                  yValueMapper: (d, __) => d.emPedido,
                  name: 'Em Pedido',
                  color: const Color(0xFF00897B),
                  groupName: 'disponivel',
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                // Consumo Previsto
                ColumnSeries<SimuladorCompraItem, String>(
                  dataSource: data,
                  xValueMapper: (d, __) => d.produto.nome,
                  yValueMapper: (d, __) => d.consumoPrevisto,
                  name: 'Consumo',
                  color: const Color(0xFFE65100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                // Sugestão de compra
                ColumnSeries<SimuladorCompraItem, String>(
                  dataSource: data,
                  xValueMapper: (d, __) => d.produto.nome,
                  yValueMapper: (d, __) =>
                      d.incluir ? d.quantidadeDigitada : 0,
                  name: 'Sugestão',
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.60),
                  borderColor: const Color(0xFF2E7D32),
                  borderWidth: 1.5,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legItem(String label, Color cor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 4),
      Text(label,
          style:
              AppCss.minimumRegular.setColor(Colors.grey[700]!).setSize(10)),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ações em massa
  // ─────────────────────────────────────────────────────────────────────────

  Widget _acoesMassa(SimuladorCompraModel model) {
    final selecionados = model.itensSelecionados.length;
    return Row(
      children: [
        Icon(Icons.checklist_rounded, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          '$selecionados de ${model.itens.length} selecionado${selecionados != 1 ? 's' : ''}',
          style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(12),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => simuladorCompraCtrl.onSelecionarTodosComDeficit(),
          icon: Icon(Icons.select_all, size: 14, color: Colors.blue[700]),
          label: Text('Selecionar déficit',
              style: AppCss.minimumBold
                  .setColor(Colors.blue[700]!)
                  .setSize(11)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () => simuladorCompraCtrl.onDesmarcarTodos(),
          icon: Icon(Icons.deselect, size: 14, color: Colors.grey[500]),
          label: Text('Limpar',
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[500]!)
                  .setSize(11)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card individual
  // ─────────────────────────────────────────────────────────────────────────

  Widget _produtoCard(SimuladorCompraItem item) {
    final temDeficit = item.temDeficit;
    final accentColor =
        temDeficit ? Colors.red[700]! : Colors.green[700]!;
    final bgColor = temDeficit
        ? Colors.red.withValues(alpha: 0.03)
        : Colors.white;
    final borderColor = temDeficit
        ? Colors.red.withValues(alpha: 0.40)
        : const Color(0xFFE2E8F0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header com checkbox ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 0),
            child: Row(children: [
              // Checkbox
              SizedBox(
                width: 36,
                height: 36,
                child: Checkbox(
                  value: item.incluir,
                  onChanged: (_) => simuladorCompraCtrl.onToggleItem(item),
                  activeColor: AppColors.primaryMain,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 4),
              // Ícone
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  temDeficit
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              // Nome
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.produto.nome,
                          style: AppCss.minimumBold.setSize(13)),
                      Text(item.produto.descricao,
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[500]!)
                              .setSize(11)),
                    ]),
              ),
              // Badge déficit
              if (temDeficit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'DÉFICIT',
                    style: AppCss.minimumBold
                        .setColor(Colors.red[700]!)
                        .setSize(9),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OK',
                    style: AppCss.minimumBold
                        .setColor(Colors.green[700]!)
                        .setSize(9),
                  ),
                ),
            ]),
          ),
          // ── Valores ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
            child: Row(children: [
              _valorCol('Saldo', item.saldoFisico.toKg(), Colors.blue[700]!),
              _seta(),
              _valorCol(
                'Consumo',
                item.consumoPrevisto > 0
                    ? '-${item.consumoPrevisto.toKg()}'
                    : '—',
                item.consumoPrevisto > 0
                    ? Colors.orange[700]!
                    : Colors.grey[400]!,
              ),
              _seta(),
              _valorCol(
                'Em Pedido',
                item.emPedido > 0 ? '+${item.emPedido.toKg()}' : '—',
                item.emPedido > 0 ? Colors.teal[700]! : Colors.grey[400]!,
              ),
              _seta(),
              _valorCol(
                'Projetado',
                item.saldoProjetado.toKg(),
                item.saldoProjetado < 0
                    ? Colors.red[700]!
                    : Colors.green[700]!,
                bold: true,
              ),
            ]),
          ),
          // ── Estoque Mínimo (se configurado) ─────────────────────────
          if (item.estoqueMinimo > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
              child: Row(children: [
                Icon(Icons.shield_outlined,
                    size: 12, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Text(
                  'Estoque mínimo: ${item.estoqueMinimo.toKg()}',
                  style: AppCss.minimumRegular
                      .setColor(Colors.amber[700]!)
                      .setSize(11),
                ),
              ]),
            ),
          // ── Input de sugestão ───────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: item.incluir
                  ? Colors.green.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.incluir
                    ? Colors.green.withValues(alpha: 0.30)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(children: [
              Icon(
                Icons.add_shopping_cart_outlined,
                size: 16,
                color: item.incluir ? Colors.green[700] : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text(
                'Sugestão de compra:',
                style: AppCss.minimumRegular
                    .setColor(
                        item.incluir ? Colors.green[700]! : Colors.grey[500]!)
                    .setSize(12),
              ),
              const SizedBox(width: 8),
              // Campo editável
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: item.quantidadeSugerida.controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
                  ],
                  textAlign: TextAlign.right,
                  style: AppCss.minimumBold
                      .setColor(item.incluir
                          ? Colors.green[700]!
                          : Colors.grey[600]!)
                      .setSize(13),
                  decoration: InputDecoration(
                    hintText: '0,000',
                    hintStyle: AppCss.minimumRegular
                        .setColor(Colors.grey[300]!)
                        .setSize(13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: Colors.grey.withValues(alpha: 0.30)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: Colors.grey.withValues(alpha: 0.30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.green[700]!),
                    ),
                  ),
                  onChanged: (_) =>
                      simuladorCompraCtrl.onQuantidadeAlterada(),
                ),
              ),
              const SizedBox(width: 4),
              Text('kg',
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[500]!)
                      .setSize(11)),
              // Ícone de resultado pós-compra
              if (item.incluir && item.quantidadeDigitada > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  item.saldoProjetadoComCompra.toKg(),
                  style: AppCss.minimumBold
                      .setColor(item.saldoProjetadoComCompra >= 0
                          ? Colors.green[700]!
                          : Colors.red[700]!)
                      .setSize(12),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _valorCol(String label, String valor, Color cor,
      {bool bold = false}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(label,
            style: AppCss.minimumRegular
                .setSize(9)
                .setColor(Colors.grey[400]!)),
        Text(
          valor,
          style: bold
              ? AppCss.minimumBold.setColor(cor).setSize(12)
              : AppCss.minimumRegular.setColor(cor).setSize(12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _seta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.arrow_forward_ios_rounded,
          size: 8, color: Colors.grey[300]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Botão gerar pedido
  // ─────────────────────────────────────────────────────────────────────────

  Widget _botaoGerarPedido(
      BuildContext context, SimuladorCompraModel model) {
    final selecionados = model.itensSelecionados.length;
    final habilitado = selecionados > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[400],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed:
              habilitado ? () => simuladorCompraCtrl.onGerarPedido(context) : null,
          icon: const Icon(Icons.shopping_cart_checkout_outlined),
          label: Text(
            habilitado
                ? 'Gerar Pedido ($selecionados item${selecionados > 1 ? 's' : ''} · ${model.totalSugerido.toKg()})'
                : 'Selecione itens para gerar pedido',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
