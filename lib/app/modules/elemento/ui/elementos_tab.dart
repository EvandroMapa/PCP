import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/ui/elemento_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ElementosTab extends StatefulWidget {
  final PedidoModel pedido;
  const ElementosTab({required this.pedido, super.key});

  @override
  State<ElementosTab> createState() => _ElementosTabState();
}

class _ElementosTabState extends State<ElementosTab> {
  @override
  void initState() {
    super.initState();
    elementoCtrl.onInit(widget.pedido.id);
  }

  String _fmt(double v) => NumberFormat('#,##0.000', 'pt_BR').format(v);

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<ElementoModel>>(
      stream: elementoCtrl.elementosStream.listen,
      builder: (_, elementos) {
        final validacao = elementoCtrl.getValidacaoBitola(widget.pedido);
        return Column(
          children: [
            // ── Cabeçalho de totais + status ──────────────────────────────
            _HeaderWidget(validacao: validacao, fmt: _fmt),
            const Divisor(),

            // ── Botão adicionar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Elementos (${elementos.length})',
                    style: AppCss.mediumBold,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo Elemento'),
                    onPressed: () => showElementoFormDialog(
                      context,
                      pedido: widget.pedido,
                    ),
                  ),
                ],
              ),
            ),

            // ── Lista de elementos ────────────────────────────────────────
            if (elementos.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Nenhum elemento cadastrado',
                          style: AppCss.mediumRegular
                              .copyWith(color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text('Clique em "Novo Elemento" para começar',
                          style: AppCss.smallRegular
                              .copyWith(color: Colors.grey[400])),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: elementos.length,
                  separatorBuilder: (_, __) => const Divisor(),
                  itemBuilder: (_, i) => _ElementoTile(
                    elemento: elementos[i],
                    pedido: widget.pedido,
                    fmt: _fmt,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── HEADER COM TOTAIS ────────────────────────────────────────────────────────
class _HeaderWidget extends StatelessWidget {
  final ElementoValidacaoResult validacao;
  final String Function(double) fmt;
  const _HeaderWidget({required this.validacao, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final ok = validacao.isOk;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ok ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: ok ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                ok
                    ? 'Elementos conferem com o pedido ✓'
                    : 'Divergência encontrada nos pesos',
                style: AppCss.mediumBold.copyWith(
                    color: ok ? Colors.green.shade800 : Colors.red.shade800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TotalChip(
                  label: 'Total do pedido',
                  value: '${fmt(validacao.totalPedidoKg)} kg',
                  color: Colors.blueGrey),
              const SizedBox(width: 8),
              _TotalChip(
                  label: 'Total dos elementos',
                  value: '${fmt(validacao.totalElementosKg)} kg',
                  color: ok ? Colors.green : Colors.red),
            ],
          ),
          if (validacao.divergencias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Divergências por bitola:',
                style: AppCss.smallBold.copyWith(color: Colors.red.shade700)),
            ...validacao.divergencias.map((d) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${d.produto.produto.labelMinified}: esperado ${fmt(d.esperadoKg)} kg — calculado ${fmt(d.calculadoKg)} kg (Δ ${fmt(d.diferencaKg)} kg)',
                    style: AppCss.smallRegular
                        .copyWith(color: Colors.red.shade700),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppCss.smallRegular.copyWith(color: color, fontSize: 10)),
          Text(value,
              style: AppCss.mediumBold.copyWith(color: color, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── TILE DE ELEMENTO ─────────────────────────────────────────────────────────
class _ElementoTile extends StatefulWidget {
  final ElementoModel elemento;
  final PedidoModel pedido;
  final String Function(double) fmt;
  const _ElementoTile(
      {required this.elemento, required this.pedido, required this.fmt});

  @override
  State<_ElementoTile> createState() => _ElementoTileState();
}

class _ElementoTileState extends State<_ElementoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final el = widget.elemento;
    return Column(
      children: [
        // ── Linha do elemento ─────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.neutralDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(el.nome, style: AppCss.mediumBold),
                      Text(
                        '${el.posicoes.length} posição(ões) · ${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.smallRegular
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Peso total em destaque
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.fmt(el.pesoTotal)} kg',
                    style: AppCss.mediumBold
                        .setColor(AppColors.primaryMain),
                  ),
                ),
                const SizedBox(width: 8),
                // Ações
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await showElementoFormDialog(context,
                          pedido: widget.pedido, elemento: el);
                    } else if (action == 'delete') {
                      await elementoCtrl.onDeleteElemento(el);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Editar')
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir',
                              style: TextStyle(color: Colors.red))
                        ])),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Posições expandidas ───────────────────────────────────────────
        if (_expanded)
          Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Cabeçalho das colunas
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('Posição',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 2,
                          child: Text('OS',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 2,
                          child: Text('Bitola',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 1,
                          child: Text('Peso (kg)',
                              style: AppCss.smallBold
                                  .copyWith(color: Colors.grey[500]),
                              textAlign: TextAlign.end)),
                    ],
                  ),
                ),
                const Divisor(),
                ...el.posicoes.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(p.nome,
                                  style: AppCss.smallRegular)),
                          Expanded(
                              flex: 2,
                              child: Text(p.numeroOs,
                                  style: AppCss.smallRegular)),
                          Expanded(
                            flex: 2,
                            child: Text(
                              p.produto?.labelMinified ?? p.produtoId,
                              style: AppCss.smallRegular,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              widget.fmt(p.pesoKg),
                              style: AppCss.smallBold
                                  .setColor(AppColors.primaryMain),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
                // Subtotal
                const Divisor(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Subtotal: ',
                          style: AppCss.smallBold
                              .copyWith(color: Colors.grey[600])),
                      Text(
                        '${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.mediumBold
                            .setColor(AppColors.primaryMain),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
