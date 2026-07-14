import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PedidoCompraPlanilhaPage extends StatefulWidget {
  const PedidoCompraPlanilhaPage({super.key});

  @override
  State<PedidoCompraPlanilhaPage> createState() =>
      _PedidoCompraPlanilhaPageState();
}

class _PedidoCompraPlanilhaPageState extends State<PedidoCompraPlanilhaPage> {
  // ─── flex das colunas fixas: [ckbox, bitola, saldo, consumo] ──────────────
  static const _fFixed = [1, 3, 2, 2];

  // flex de cada coluna dinâmica de pedido (por fornecedor)
  static const _fPedido = 2;

  // flex da coluna projetado (única, sempre ao final)
  static const _fProj = 2;

  // Cores por slot de fornecedor
  static const _cores = [
    Color(0xFF2563EB), // azul  — F1
    Color(0xFF059669), // verde — F2
    Color(0xFFD97706), // âmbar — F3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Novo Pedido de Compra',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryMain,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamOut<PedidoCompraPlanilhaModel?>(
        stream: pedidoCompraCtrl.planilhaStream.listen,
        builder: (_, model) {
          if (model == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, model);
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Body
  // ───────────────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context, PedidoCompraPlanilhaModel model) {
    return Column(
      children: [
        _barraFornecedores(model),
        const Divider(height: 1),
        _acoesMassa(model),
        const Divider(height: 1),
        _tabelaHeader(model),
        const Divider(height: 1, color: Color(0xFFCBD5E1)),
        Expanded(
          child: ListView.separated(
            itemCount: model.itens.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEEF2F6)),
            itemBuilder: (_, i) => _tabelaRow(model.itens[i], i, model),
          ),
        ),
        _rodapeTotais(model),
        _botaoSalvar(context, model),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Barra de Fornecedores
  // ───────────────────────────────────────────────────────────────────────────

  Widget _barraFornecedores(PedidoCompraPlanilhaModel model) {
    final fabricantes = [...BackendClient.fabricantes.data]
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.store_outlined, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('Fornecedores:',
              style:
                  AppCss.minimumBold.setColor(Colors.grey[600]!).setSize(11)),
          const SizedBox(width: 10),
          // Chips de fornecedor existentes
          ...List.generate(model.colunas, (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chipFornecedor(
                  idx: i,
                  fabricante: model.fornecedores[i],
                  fabricantes: fabricantes,
                  model: model,
                ),
              )),
          // Botão + adicionar coluna
          if (model.colunas < 3) _btnAdicionarFornecedor(),
          const Spacer(),
          // Recalcular
          Tooltip(
            message: 'Recalcular estoque e consumo',
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => pedidoCompraCtrl.iniciarPlanilha(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.20)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded,
                      size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text('Recalcular',
                      style: AppCss.minimumBold
                          .setColor(Colors.grey[600]!)
                          .setSize(11)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFornecedor({
    required int idx,
    required FabricanteModel? fabricante,
    required List<FabricanteModel> fabricantes,
    required PedidoCompraPlanilhaModel model,
  }) {
    final cor = _cores[idx];
    final label = 'F${idx + 1}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Badge label (F1, F2, F3)
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(label,
                style:
                    AppCss.minimumBold.setColor(Colors.white).setSize(10)),
          ),
        ),
        const SizedBox(width: 6),
        // Dropdown de fabricante
        DropdownButton<FabricanteModel?>(
          value: fabricante,
          hint: Text('Selecionar',
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[500]!)
                  .setSize(12)),
          underline: const SizedBox(),
          isDense: true,
          style: AppCss.minimumBold.setColor(cor).setSize(12),
          items: [
            DropdownMenuItem<FabricanteModel?>(
              value: null,
              child: Text('— Nenhum —',
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[500]!)
                      .setSize(12)),
            ),
            ...fabricantes.map((f) => DropdownMenuItem<FabricanteModel?>(
                  value: f,
                  child: Text(f.nome,
                      style: AppCss.minimumBold.setColor(cor).setSize(12)),
                )),
          ],
          onChanged: (fab) =>
              pedidoCompraCtrl.onSetFornecedorPlanilha(idx, fab),
        ),
        // Botão remover coluna (só se tiver mais de 1)
        if (model.colunas > 1) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => pedidoCompraCtrl.onRemoverColunaPlanilha(idx),
            child: Icon(Icons.close_rounded,
                size: 14, color: cor.withValues(alpha: 0.60)),
          ),
        ],
      ]),
    );
  }

  Widget _btnAdicionarFornecedor() {
    return InkWell(
      onTap: pedidoCompraCtrl.onAdicionarColunaPlanilha,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text('Fornecedor',
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[500]!)
                  .setSize(11)),
        ]),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Ações em massa
  // ───────────────────────────────────────────────────────────────────────────

  Widget _acoesMassa(PedidoCompraPlanilhaModel model) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          '${model.totalMarcados} de ${model.itens.length}'
          '  ·  ${model.totalComDeficit} com déficit',
          style:
              AppCss.minimumRegular.setColor(Colors.grey[600]!).setSize(11),
        ),
        const Spacer(),
        _actionBtn(
          label: 'Selecionar déficit',
          icon: Icons.select_all,
          cor: Colors.blue[700]!,
          onTap: pedidoCompraCtrl.onSelecionarDeficitPlanilha,
        ),
        const SizedBox(width: 6),
        _actionBtn(
          label: 'Limpar',
          icon: Icons.deselect,
          cor: Colors.grey[500]!,
          onTap: pedidoCompraCtrl.onDesmarcarTodosPlanilha,
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
          Text(label,
              style: AppCss.minimumBold.setColor(cor).setSize(11)),
        ]),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tabela Header
  // ───────────────────────────────────────────────────────────────────────────

  Widget _tabelaHeader(PedidoCompraPlanilhaModel model) {
    return Container(
      color: const Color(0xFFE8EDF2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(children: [
        _hCell('', _fFixed[0]),
        _hCell('BITOLA', _fFixed[1], align: TextAlign.left),
        _hCell('SALDO', _fFixed[2]),
        _hCell('CONSUMO', _fFixed[3]),
        // Cabeçalho de cada fornecedor
        ...List.generate(model.colunas, (i) {
          final fab = model.fornecedores[i];
          final cor = _cores[i];
          final nome = fab != null
              ? (fab.nome.length > 10
                  ? '${fab.nome.substring(0, 10)}…'
                  : fab.nome)
              : 'F${i + 1}';
          return Expanded(
            flex: _fPedido,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                nome,
                textAlign: TextAlign.center,
                style: AppCss.minimumBold.setColor(cor).setSize(10),
              ),
            ),
          );
        }),
        // Projetado (único)
        Expanded(
          flex: _fProj,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'PROJETADO',
              textAlign: TextAlign.center,
              style: AppCss.minimumBold
                  .setColor(Colors.grey[700]!)
                  .setSize(10),
            ),
          ),
        ),
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
          style:
              AppCss.minimumBold.setColor(Colors.grey[600]!).setSize(10),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tabela Row
  // ───────────────────────────────────────────────────────────────────────────

  Widget _tabelaRow(
    PedidoCompraPlanilhaItem item,
    int index,
    PedidoCompraPlanilhaModel model,
  ) {
    final temDeficit = item.temDeficit;
    final isEven = index.isEven;

    final Color bgColor;
    if (item.incluir) {
      bgColor = Colors.green.withValues(alpha: 0.18);
    } else if (temDeficit) {
      bgColor = Colors.red.withValues(alpha: 0.14);
    } else {
      bgColor = isEven ? Colors.white : const Color(0xFFFAFBFC);
    }

    // Cor semântica do projetado
    final proj = item.saldoProjetado(model.colunas);
    final corProj = proj < 0
        ? Colors.red[700]!
        : proj < item.consumoPrevisto
            ? Colors.orange[700]!
            : Colors.green[700]!;

    return InkWell(
      onTap: () => pedidoCompraCtrl.onToggleItemPlanilha(item),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ── Checkbox ──────────────────────────────────────────────────
          Expanded(
            flex: _fFixed[0],
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: item.incluir,
                  onChanged: (_) =>
                      pedidoCompraCtrl.onToggleItemPlanilha(item),
                  activeColor: AppColors.primaryMain,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),

          // ── Bitola (barra colorida + nome) ────────────────────────────
          Expanded(
            flex: _fFixed[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: temDeficit
                        ? Colors.red[400]
                        : Colors.green[400],
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

          // ── Saldo ─────────────────────────────────────────────────────
          _dCell(
            '+${item.saldoFisico.toKgInt()}',
            _fFixed[2],
            cor: Colors.blueGrey[700]!,
            bold: true,
          ),

          // ── Consumo ───────────────────────────────────────────────────
          _dCell(
            item.consumoPrevisto > 0
                ? '-${item.consumoPrevisto.toKgInt()}'
                : '—',
            _fFixed[3],
            cor: item.consumoPrevisto > 0
                ? Colors.orange[700]!
                : Colors.grey[400]!,
          ),

          // ── Campos de quantidade por fornecedor ───────────────────────
          ...List.generate(model.colunas, (i) {
            final cor = _cores[i];
            return Expanded(
              flex: _fPedido,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 28,
                  child: TextFormField(
                    controller: item.quantidades[i].controller,
                    enabled: item.incluir,
                    onTap: () {
                      final ctrl = item.quantidades[i].controller;
                      ctrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: ctrl.text.length,
                      );
                    },
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    style: AppCss.minimumBold
                        .setColor(
                            item.incluir ? cor : Colors.grey[400]!)
                        .setSize(12),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppCss.minimumRegular
                          .setColor(Colors.grey[300]!)
                          .setSize(12),
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      filled: true,
                      fillColor: item.incluir
                          ? cor.withValues(alpha: 0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.25)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: cor.withValues(alpha: 0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cor),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      suffixText: 'kg',
                      suffixStyle: AppCss.minimumRegular
                          .setColor(Colors.grey[400]!)
                          .setSize(9),
                    ),
                    onChanged: (_) =>
                        pedidoCompraCtrl.onQuantidadePlanilhaAlterada(),
                  ),
                ),
              ),
            );
          }),

          // ── Projetado consolidado (F1 + F2 + F3) ─────────────────────
          Expanded(
            flex: _fProj,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                proj.toKgInt(),
                textAlign: TextAlign.center,
                style:
                    AppCss.minimumBold.setColor(corProj).setSize(12),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dCell(String valor, int flex,
      {Color cor = Colors.black87, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          valor,
          textAlign: TextAlign.center,
          style: bold
              ? AppCss.minimumBold.setColor(cor).setSize(13)
              : AppCss.minimumRegular.setColor(cor).setSize(13),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rodapé Totais
  // ───────────────────────────────────────────────────────────────────────────

  Widget _rodapeTotais(PedidoCompraPlanilhaModel model) {
    final projTotal = model.totalProjetado();
    final corProjTotal = projTotal < 0
        ? Colors.red[700]!
        : projTotal < model.totalConsumo()
            ? Colors.orange[700]!
            : Colors.green[700]!;

    return Container(
      color: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        // Label TOTAIS (ocupa checkbox + bitola)
        Expanded(
          flex: _fFixed[0] + _fFixed[1],
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
        _tCell(model.totalSaldo().toKgInt(), _fFixed[2],
            Colors.blueGrey[700]!),
        _tCell(model.totalConsumo().toKgInt(), _fFixed[3],
            Colors.orange[700]!),
        // Total de pedido por fornecedor
        ...List.generate(model.colunas, (i) {
          final total = model.totalPedidoPorFornecedor(i);
          return _tCell(
              total > 0 ? total.toKgInt() : '—', _fPedido, _cores[i]);
        }),
        // Projetado total
        _tCell(projTotal.toKgInt(), _fProj, corProjTotal),
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
  // Botão Salvar
  // ───────────────────────────────────────────────────────────────────────────

  Widget _botaoSalvar(BuildContext context, PedidoCompraPlanilhaModel model) {
    final grupos = model.gruposParaSalvar;
    final habilitado = grupos.isNotEmpty;
    final nGrupos = grupos.length;
    final totalItens =
        grupos.fold<int>(0, (s, g) => s + g.itens.length);

    final label = habilitado
        ? 'Salvar $nGrupos pedido${nGrupos > 1 ? 's' : ''}'
            ' · $totalItens item${totalItens > 1 ? 's' : ''}'
        : 'Selecione bitolas e fornecedores';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
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
              ? () => pedidoCompraCtrl.onSalvarPlanilha(context)
              : null,
          icon: const Icon(Icons.shopping_cart_checkout_outlined),
          label: Text(label, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}
