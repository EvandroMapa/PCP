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

  // ─── Flex proportions (iguais em header, rows e footer) ──────────────────
  //           ckbox bitola min ideal saldo pedido consumo deficit sugst pedido proj
  static const _f = [1, 2, 1, 1, 2, 2, 2, 2, 2, 2, 2];

  // ───────────────────────────────────────────────────────────────────────────
  // Body
  // ───────────────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context, SimuladorCompraModel model) {
    return Column(
      children: [
        _formatarCargaBar(model),
        const Divider(height: 1),
        _acoesMassa(model),
        const Divider(height: 1),
        _tabelaHeader(),
        const Divider(height: 1, color: Color(0xFFCBD5E1)),
        Expanded(
          child: ListView.separated(
            itemCount: model.itens.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEEF2F6)),
            itemBuilder: (_, i) => _tabelaRow(model.itens[i], i),
          ),
        ),
        _rodapeTotais(model),
        _botaoGerarPedido(context, model),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Formatar Carga
  // ───────────────────────────────────────────────────────────────────────────

  Widget _formatarCargaBar(SimuladorCompraModel model) {
    final ativo = model.formatarCarga;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: ativo ? const Color(0xFFF0F9FF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.local_shipping_outlined,
                size: 16,
                color: ativo ? const Color(0xFF2563EB) : Colors.grey[400]),
            const SizedBox(width: 8),
            Text('Formatar Carga', style: AppCss.minimumBold.setSize(12)),
            const Spacer(),
            // Múltiplo (sempre visível)
            _compactField(
              label: 'Múltiplo',
              controller: model.multiploArredondamento.controller,
              hint: '0',
              width: 80,
              onEditingComplete: () => simuladorCompraCtrl.onMultiploAlterado(),
            ),
            const SizedBox(width: 8),
            if (ativo && model.totalSugerido > 0) ...[
              _badgeDelta(model),
              const SizedBox(width: 8),
            ],
            Switch(
              value: ativo,
              activeThumbColor: const Color(0xFF2563EB),
              onChanged: (v) {
                simuladorCompraCtrl.onToggleFormatarCarga(v);
                setState(() {});
              },
            ),
          ]),
          if (ativo)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                _compactField(
                  label: 'Peso-alvo',
                  controller: model.pesoAlvoCarga.controller,
                  hint: '30000',
                  width: 110,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      simuladorCompraCtrl.aplicarFormatacaoCarga();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: Text('Aplicar',
                        style: AppCss.minimumBold
                            .setColor(Colors.white)
                            .setSize(11)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _compactField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required double width,
    VoidCallback? onEditingComplete,
  }) {
    return Row(children: [
      Text('$label:',
          style: AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(11)),
      const SizedBox(width: 4),
      SizedBox(
        width: width,
        height: 30,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
          ],
          style: AppCss.minimumBold.setSize(12),
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
            suffixText: 'kg',
            suffixStyle:
                AppCss.minimumRegular.setColor(Colors.grey[400]!).setSize(9),
          ),
        ),
      ),
    ]);
  }

  Widget _badgeDelta(SimuladorCompraModel model) {
    final delta = model.deltaCarga;
    final pesoAlvo = model.pesoAlvoValue;
    final deltaPct = pesoAlvo > 0 ? (delta / pesoAlvo * 100) : 0.0;
    final bom = deltaPct.abs() <= 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bom
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(bom ? Icons.check_circle : Icons.info_outline,
            size: 12,
            color: bom ? Colors.green[700] : Colors.amber[800]),
        const SizedBox(width: 4),
        Text(
          '${(model.totalSugerido / 1000).toStringAsFixed(2)} t '
          '(${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%)',
          style: AppCss.minimumBold
              .setColor(bom ? Colors.green[700]! : Colors.amber[800]!)
              .setSize(10),
        ),
      ]),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Ações em massa
  // ───────────────────────────────────────────────────────────────────────────

  Widget _acoesMassa(SimuladorCompraModel model) {
    final sel = model.itensSelecionados.length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text('$sel de ${model.itens.length}',
            style:
                AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(11)),
        const Spacer(),
        _actionBtn(
          label: 'Selecionar déficit',
          icon: Icons.select_all,
          cor: Colors.blue[700]!,
          onTap: simuladorCompraCtrl.onSelecionarTodosComDeficit,
        ),
        const SizedBox(width: 6),
        _actionBtn(
          label: 'Limpar',
          icon: Icons.deselect,
          cor: Colors.grey[500]!,
          onTap: simuladorCompraCtrl.onDesmarcarTodos,
        ),
      ]),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: cor),
          const SizedBox(width: 3),
          Text(label, style: AppCss.minimumBold.setColor(cor).setSize(11)),
        ]),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tabela — Header (usa mesmos flex de _f)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _tabelaHeader() {
    return Container(
      color: const Color(0xFFE8EDF2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(children: [
        _hCell('', _f[0]),
        _hCell('BITOLA', _f[1], align: TextAlign.left),
        _hCell('MÍNIMO', _f[2]),
        _hCell('IDEAL', _f[3]),
        _hCell('SALDO', _f[4]),
        _hCell('EM PEDIDO', _f[5]),
        _hCell('CONSUMO', _f[6]),
        _hCell('DÉFICIT', _f[7]),
        _hCell('SUGESTÃO', _f[8]),
        _hCell('PEDIDO', _f[9]),
        _hCell('PROJETADO', _f[10]),
      ]),
    );
  }

  Widget _hCell(String label, int flex, {TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: align,
          style: AppCss.minimumBold.setColor(Colors.grey[600]!).setSize(10),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tabela — Row de dados
  // ───────────────────────────────────────────────────────────────────────────

  Widget _tabelaRow(SimuladorCompraItem item, int index) {
    final temDeficit = item.temDeficit;
    final isEven = index.isEven;

    Color bgColor;
    if (item.incluir) {
      bgColor = Colors.green.withValues(alpha: 0.04);
    } else if (temDeficit) {
      bgColor = Colors.red.withValues(alpha: 0.03);
    } else {
      bgColor = isEven ? Colors.white : const Color(0xFFFAFBFC);
    }

    return InkWell(
      onTap: () => simuladorCompraCtrl.onToggleItem(item),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(children: [
          // ☐ Checkbox
          Expanded(
            flex: _f[0],
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 28, height: 28,
                child: Checkbox(
                  value: item.incluir,
                  onChanged: (_) => simuladorCompraCtrl.onToggleItem(item),
                  activeColor: AppColors.primaryMain,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
          // Bitola
          Expanded(
            flex: _f[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Container(
                  width: 3, height: 28,
                  decoration: BoxDecoration(
                    color: temDeficit ? Colors.red[400] : Colors.green[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.produto.nome,
                    style: AppCss.minimumBold.setSize(13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          // Mínimo
          _dCell(
            item.estoqueMinimo > 0 ? item.estoqueMinimo.toKgInt() : '—',
            _f[2],
            cor: item.estoqueMinimo > 0
                ? Colors.grey[400]!
                : Colors.grey[300]!,
          ),
          // Ideal
          _dCell(
            item.estoqueIdeal > 0 ? item.estoqueIdeal.toKgInt() : '—',
            _f[3],
            cor: item.estoqueIdeal > 0
                ? Colors.grey[400]!
                : Colors.grey[300]!,
          ),
          // Saldo (+)
          _dCell(
            '+${item.saldoFisico.toKgInt()}',
            _f[4],
            cor: Colors.blueGrey[700]!,
            bold: true,
          ),
          // Em Pedido
          _dCell(
            item.emPedido > 0 ? '+${item.emPedido.toKgInt()}' : '—',
            _f[5],
            cor: item.emPedido > 0 ? Colors.teal[700]! : Colors.grey[350]!,
          ),
          // Consumo (-)
          _dCell(
            item.consumoPrevisto > 0 ? '-${item.consumoPrevisto.toKgInt()}' : '—',
            _f[6],
            cor: item.consumoPrevisto > 0
                ? Colors.orange[700]!
                : Colors.grey[350]!,
          ),
          // Déficit
          Expanded(
            flex: _f[7],
            child: Center(
              child: temDeficit
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.necessidade.toKgInt(),
                        style: AppCss.minimumBold
                            .setColor(Colors.red[700]!)
                            .setSize(12),
                      ),
                    )
                  : Text('—',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[350]!)
                          .setSize(13)),
            ),
          ),
          // Sugestão base (read-only)
          _dCell(
            item.sugestaoBase > 0 ? item.sugestaoBase.toKgInt() : '—',
            _f[8],
            cor: item.sugestaoBase > 0
                ? Colors.blue[600]!
                : Colors.grey[350]!,
          ),
          // Pedido (editável)
          Expanded(
            flex: _f[9],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 36,
                child: TextFormField(
                  controller: item.quantidadeSugerida.controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.right,
                  style: AppCss.minimumBold
                      .setColor(item.incluir
                          ? Colors.green[700]!
                          : Colors.grey[600]!)
                      .setSize(13),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppCss.minimumRegular
                        .setColor(Colors.grey[300]!)
                        .setSize(13),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: item.incluir
                        ? Colors.green.withValues(alpha: 0.06)
                        : Colors.grey.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.green[700]!),
                    ),
                    suffixText: 'kg',
                    suffixStyle: AppCss.minimumRegular
                        .setColor(Colors.grey[400]!)
                        .setSize(9),
                  ),
                  onChanged: (_) =>
                      simuladorCompraCtrl.onQuantidadeAlterada(),
                ),
              ),
            ),
          ),
          // Saldo Final
          (() {
            final sf = item.saldoProjetadoComCompra;
            final cor = sf >= item.nivelAlvo
                ? Colors.green[700]!
                : sf >= item.estoqueMinimo
                    ? Colors.amber[700]!
                    : Colors.red[700]!;
            return _dCell(sf.toKgInt(), _f[10], cor: cor, bold: true);
          })(),
        ]),
      ),
    );
  }

  Widget _dCell(String valor, int flex,
      {Color cor = Colors.black87, bool bold = false, bool small = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          valor,
          textAlign: TextAlign.center,
          style: bold
              ? AppCss.minimumBold.setColor(cor).setSize(small ? 11 : 13)
              : AppCss.minimumRegular.setColor(cor).setSize(small ? 11 : 13),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rodapé Totais (mesmos flex)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _rodapeTotais(SimuladorCompraModel model) {
    return Container(
      color: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Expanded(
          flex: _f[0] + _f[1],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Icon(Icons.functions_rounded,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('TOTAIS',
                  style: AppCss.minimumBold
                      .setColor(Colors.grey[700]!)
                      .setSize(12)),
            ]),
          ),
        ),
        Expanded(flex: _f[2], child: const SizedBox()),
        Expanded(flex: _f[3], child: const SizedBox()),
        _tCell(model.totalSaldoFisico.toKgInt(), _f[4], Colors.blueGrey[700]!),
        _tCell(model.totalEmPedido.toKgInt(), _f[5], Colors.teal[700]!),
        _tCell(model.totalConsumoPrevisto.toKgInt(), _f[6], Colors.orange[700]!),
        _tCell('${model.totalComDeficit} itens', _f[7], Colors.red[700]!),
        _tCell(model.totalSugestaoBase.toKgInt(), _f[8], Colors.blue[600]!),
        _tCell(model.totalSugerido.toKgInt(), _f[9], Colors.green[700]!),
        _tCell(model.totalProjetadoComCompra.toKgInt(), _f[10], Colors.green[800]!),
      ]),
    );
  }

  Widget _tCell(String valor, int flex, Color cor) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          valor,
          textAlign: TextAlign.center,
          style: AppCss.minimumBold.setColor(cor).setSize(12),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Botão gerar pedido
  // ───────────────────────────────────────────────────────────────────────────

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
          onPressed: habilitado
              ? () => simuladorCompraCtrl.onGerarPedido(context)
              : null,
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
