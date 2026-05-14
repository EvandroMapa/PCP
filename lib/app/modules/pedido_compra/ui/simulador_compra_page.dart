import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

              // Formatar Carga
              _formatarCargaCard(model),
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
            'Necessidade = Consumo + Nível Alvo (Ideal ou Mínimo) − Saldo − Em Pedido',
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
  // Formatar Carga
  // ─────────────────────────────────────────────────────────────────────────

  Widget _formatarCargaCard(SimuladorCompraModel model) {
    final ativo = model.formatarCarga;
    final delta = model.deltaCarga;
    final totalSugerido = model.totalSugerido;
    final pesoAlvo = model.pesoAlvoValue;
    final deltaPct = pesoAlvo > 0 ? (delta / pesoAlvo * 100) : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ativo ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ativo
              ? const Color(0xFF93C5FD)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header com switch ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: ativo
                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: ativo ? const Color(0xFF2563EB) : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Formatar Carga',
                        style: AppCss.minimumBold.setSize(13)),
                    Text(
                      'Distribui proporcionalmente para montar a carga',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[500]!)
                          .setSize(10),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ativo,
                activeThumbColor: const Color(0xFF2563EB),
                onChanged: (v) {
                  simuladorCompraCtrl.onToggleFormatarCarga(v);
                  setState(() {});
                },
              ),
            ]),
          ),

          // ── Campos (só visíveis quando ativo) ──────────────────
          if (ativo) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                // Peso-alvo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Peso-alvo (kg)',
                          style: AppCss.minimumBold
                              .setColor(Colors.grey[600]!)
                              .setSize(11)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: model.pesoAlvoCarga.controller,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,\.]')),
                        ],
                        style: AppCss.minimumBold.setSize(13),
                        decoration: InputDecoration(
                          hintText: '30000',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.30)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.30)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          suffixText: 'kg',
                          suffixStyle: AppCss.minimumRegular
                              .setColor(Colors.grey[400]!)
                              .setSize(11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Múltiplo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Múltiplo (kg)',
                          style: AppCss.minimumBold
                              .setColor(Colors.grey[600]!)
                              .setSize(11)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller:
                            model.multiploArredondamento.controller,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,\.]')),
                        ],
                        style: AppCss.minimumBold.setSize(13),
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.30)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.30)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          suffixText: 'kg',
                          suffixStyle: AppCss.minimumRegular
                              .setColor(Colors.grey[400]!)
                              .setSize(11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Botão Aplicar
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      simuladorCompraCtrl.aplicarFormatacaoCarga();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text('Aplicar',
                        style: AppCss.minimumBold
                            .setColor(Colors.white)
                            .setSize(12)),
                  ),
                ),
              ]),
            ),

            // ── Badge de resultado ──────────────────────────────
            if (totalSugerido > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: deltaPct.abs() <= 5
                        ? Colors.green.withValues(alpha: 0.06)
                        : Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: deltaPct.abs() <= 5
                          ? Colors.green.withValues(alpha: 0.25)
                          : Colors.amber.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      deltaPct.abs() <= 5
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 15,
                      color: deltaPct.abs() <= 5
                          ? Colors.green[700]
                          : Colors.amber[800],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${(totalSugerido / 1000).toStringAsFixed(2)} t',
                      style: AppCss.minimumBold.setSize(12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      delta >= 0
                          ? '(+${(delta / 1000).toStringAsFixed(2)} t do alvo)'
                          : '(${(delta / 1000).toStringAsFixed(2)} t do alvo)',
                      style: AppCss.minimumRegular
                          .setColor(deltaPct.abs() <= 5
                              ? Colors.green[700]!
                              : Colors.amber[800]!)
                          .setSize(11),
                    ),
                    const Spacer(),
                    Text(
                      '${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%',
                      style: AppCss.minimumBold
                          .setColor(deltaPct.abs() <= 5
                              ? Colors.green[700]!
                              : Colors.amber[800]!)
                          .setSize(12),
                    ),
                  ]),
                ),
              ),
          ],
        ],
      ),
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
          // ── Estoque Mínimo e Ideal (se configurados) ─────────────────────
          if (item.estoqueMinimo > 0 || item.estoqueIdeal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
              child: Row(children: [
                if (item.estoqueMinimo > 0) ...[
                  Icon(Icons.shield_outlined,
                      size: 12, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Mínimo: ${item.estoqueMinimo.toKg()}',
                    style: AppCss.minimumRegular
                        .setColor(Colors.amber[700]!)
                        .setSize(11),
                  ),
                ],
                if (item.estoqueMinimo > 0 && item.estoqueIdeal > 0)
                  const SizedBox(width: 12),
                if (item.estoqueIdeal > 0) ...[
                  Icon(Icons.star_outline_rounded,
                      size: 12, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Ideal: ${item.estoqueIdeal.toKg()}',
                    style: AppCss.minimumBold
                        .setColor(Colors.blue[700]!)
                        .setSize(11),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ALVO',
                      style: AppCss.minimumBold
                          .setColor(Colors.blue[600]!)
                          .setSize(8),
                    ),
                  ),
                ] else if (item.estoqueMinimo > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ALVO',
                      style: AppCss.minimumBold
                          .setColor(Colors.amber[700]!)
                          .setSize(8),
                    ),
                  ),
                ],
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
