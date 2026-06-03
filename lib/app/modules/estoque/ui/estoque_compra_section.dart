import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:flutter/material.dart';

class EstoqueCompraSection extends StatefulWidget {
  const EstoqueCompraSection({super.key});

  @override
  State<EstoqueCompraSection> createState() => _EstoqueCompraSectionState();
}

class _EstoqueCompraSectionState extends State<EstoqueCompraSection> {
  bool _formExpanded = true;

  @override
  Widget build(BuildContext context) {
    return StreamOut<EstoqueCompraCreateModel>(
      stream: estoqueCtrl.compraStream.listen,
      builder: (_, form) => Column(
        children: [
          _formulario(form),
          const Divider(height: 1),
          Expanded(child: _histoirico()),
        ],
      ),
    );
  }

  Widget _formulario(EstoqueCompraCreateModel form) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _formExpanded = !_formExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(Icons.add_shopping_cart_outlined, size: 18, color: AppColors.primaryMain),
                const SizedBox(width: 8),
                Text('Registrar Compra', style: AppCss.mediumBold),
                const Spacer(),
                AnimatedRotation(
                  turns: _formExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                AppDropDown<BitolaModel?>(
                  label: 'Bitola',
                  item: form.produtoId != null
                      ? BackendClient.bitolas.data.cast<BitolaModel?>().firstWhere(
                            (e) => e?.id == form.produtoId,
                            orElse: () => null,
                          )
                      : null,
                  itens: BackendClient.bitolas.data.toList()
                    ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex)),
                  itemLabel: (e) => '${e!.nome} — ${e.descricao}',
                  onSelect: (e) {
                    form.produtoId = e?.id;
                    estoqueCtrl.compraStream.update();
                  },
                ),
                const SizedBox(height: 12),
                AppField(
                  label: 'Quantidade (kg)',
                  controller: form.quantidade,
                  hint: '0,000',
                  type: TextInputType.number,
                ),
                const SizedBox(height: 12),
                AppField(
                  label: 'Observação (opcional)',
                  controller: form.observacao,
                  hint: 'Ex: NF 1234, Fornecedor X...',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Registrar Compra'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await estoqueCtrl.onRegistrarCompra();
                      setState(() => _formExpanded = false);
                    },
                  ),
                ),
              ]),
            ),
            crossFadeState: _formExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _histoirico() {
    return StreamOut(
      stream: BackendClient.estoquesMovimentacao.dataStream.listen,
      builder: (_, __) {
        final compras = BackendClient.estoquesMovimentacao.data
            .where((e) => e.tipo == EstoqueTipoMovimentacao.compra)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Icon(Icons.history_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text('Histórico de Compras',
                    style: AppCss.minimumBold.setColor(Colors.grey[600]!)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${compras.length}',
                      style: AppCss.minimumBold.setColor(Colors.grey[600]!)),
                ),
              ]),
            ),
            Expanded(
              child: compras.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Nenhuma compra registrada',
                            style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: compras.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _itemMovimentacao(compras[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _itemMovimentacao(EstoqueMovimentacaoModel mov) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8F5E9)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add_shopping_cart_outlined, size: 15, color: Colors.green[600]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mov.produto.nome, style: AppCss.minimumBold),
            if (mov.observacao != null && mov.observacao!.isNotEmpty)
              Text(mov.observacao!, style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
            Text(mov.dataHora.text(),
                style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[400]!)),
          ]),
        ),
        Text('+${mov.quantidade.toKg()}',
            style: AppCss.minimumBold.setColor(Colors.green[600]!)),
      ]),
    );
  }
}
