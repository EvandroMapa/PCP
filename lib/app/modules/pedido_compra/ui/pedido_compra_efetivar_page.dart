import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PedidoCompraEfetivarPage extends StatefulWidget {
  final List<PedidoCompraModel> itens;
  const PedidoCompraEfetivarPage({super.key, required this.itens});

  @override
  State<PedidoCompraEfetivarPage> createState() =>
      _PedidoCompraEfetivarPageState();
}

class _PedidoCompraEfetivarPageState
    extends State<PedidoCompraEfetivarPage> {
  late final PedidoCompraConverterGrupoModel _model;
  // Ordena por sortIndex do produto (mesma ordem do cadastro)
  late final List<PedidoCompraModel> _itensOrdenados;

  @override
  void initState() {
    _itensOrdenados = [...widget.itens]
      ..sort((a, b) => a.produto.sortIndex.compareTo(b.produto.sortIndex));
    _model = PedidoCompraConverterGrupoModel(_itensOrdenados);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fabricante = widget.itens.first.fabricante.nome;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Efetivar Compra — $fabricante',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryMain,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Instrução ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.green.withValues(alpha: 0.08),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confira as quantidades recebidas e ajuste se necessário. '
                  'Ao confirmar, o estoque será creditado.',
                  style: AppCss.minimumRegular
                      .setColor(Colors.green[800]!)
                      .setSize(12),
                ),
              ),
            ]),
          ),

          // ── Lista de itens ─────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _itensOrdenados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _itemCard(i),
            ),
          ),

          // ── Botão fixo ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resumo total
                ValueListenableBuilder(
                  valueListenable: _totalNotifier,
                  builder: (_, __, ___) {
                    final totalPedido = _itensOrdenados.fold<double>(
                        0, (s, i) => s + i.quantidade);
                    final totalRecebido = _model.quantidadesRecebidas.fold<
                        double>(
                      0,
                      (s, q) =>
                          s +
                          (double.tryParse(
                                  q.text.replaceAll(',', '.')) ??
                              0.0),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total pedido: ${totalPedido.toKg()}',
                            style: AppCss.minimumRegular
                                .setColor(Colors.grey[500]!)
                                .setSize(12),
                          ),
                          Text(
                            'Total a receber: ${totalRecebido.toKg()}',
                            style: AppCss.minimumBold
                                .setColor(Colors.green[700]!)
                                .setSize(13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () =>
                        pedidoCompraCtrl.onEfetivarComModel(context, _model),
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Confirmar Recebimento (${_itensOrdenados.length} item${_itensOrdenados.length > 1 ? 's' : ''})',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notifier simples para atualizar o total ao digitar
  final _totalNotifier = ValueNotifier(0);

  Widget _itemCard(int i) {
    final item = _itensOrdenados[i];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome e bitola
            Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppCss.minimumBold
                        .setColor(AppColors.primaryMain)
                        .setSize(11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.produto.nome,
                        style: AppCss.minimumBold.setSize(14)),
                    Text(
                      item.produto.descricao,
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[500]!)
                          .setSize(12),
                    ),
                  ],
                ),
              ),
              // Qtde pedida
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Pedido',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[400]!)
                          .setSize(10)),
                  Text(
                    item.quantidade.toKg(),
                    style: AppCss.minimumBold
                        .setColor(Colors.grey[600]!)
                        .setSize(13),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 12),

            // Campo de quantidade recebida
            TextFormField(
              controller: _model.quantidadesRecebidas[i].controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Quantidade recebida (kg)',
                hintText: item.quantidade.toKg(),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryMain),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.scale_outlined,
                      size: 18, color: Colors.grey[400]),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
              onChanged: (_) {
                setState(() {});
                _totalNotifier.value++;
              },
            ),

            // Indicador de diferença
            Builder(builder: (_) {
              final recebido = double.tryParse(
                      _model.quantidadesRecebidas[i].text
                          .replaceAll(',', '.')) ??
                  0.0;
              final diff = recebido - item.quantidade;
              if (recebido <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(
                    diff == 0
                        ? Icons.check_circle_outline
                        : diff > 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                    size: 13,
                    color: diff == 0
                        ? Colors.green[600]
                        : diff > 0
                            ? Colors.orange[600]
                            : Colors.red[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    diff == 0
                        ? 'Quantidade conferida ✓'
                        : diff > 0
                            ? 'Recebeu ${diff.abs().toKg()} a mais'
                            : 'Faltou ${diff.abs().toKg()}',
                    style: AppCss.minimumRegular
                        .setColor(diff == 0
                            ? Colors.green[600]!
                            : diff > 0
                                ? Colors.orange[600]!
                                : Colors.red[400]!)
                        .setSize(11),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}
