import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RelatoriosPedidoPage extends StatefulWidget {
  const RelatoriosPedidoPage({super.key});

  @override
  State<RelatoriosPedidoPage> createState() => _RelatoriosPedidoPageState();
}

class _RelatoriosPedidoPageState extends State<RelatoriosPedidoPage> {
  @override
  void initState() {
    setWebTitle('Relatórios de Pedidos');
    relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    relatorioCtrl.onCreateRelatorioPedido();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([
        StreamOut(
          stream: relatorioCtrl.pedidoViewModelStream.listen,
          builder: (_, model) => IconButton(
            onPressed: () {
              model.showFilter = !model.showFilter;
              relatorioCtrl.pedidoViewModelStream.update();
            },
            icon: const Icon(Icons.sort),
          ),
        ),
        StreamOut(
          stream: relatorioCtrl.pedidoViewModelStream.listen,
          builder: (_, model) => IconButton(
            onPressed: model.relatorio != null
                ? () => relatorioCtrl.onExportRelatorioPedidoPDF(
                      relatorioCtrl.pedidoViewModel,
                    )
                : null,
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: model.relatorio != null ? Colors.white : Colors.grey[500],
            ),
          ),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<RelatorioPedidoViewModel>(
      stream: relatorioCtrl.pedidoViewModelStream.listen,
      builder: (_, model) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (model.showFilter) ...[
            _filterWidget(model),
            const Divisor(height: 32),
          ],
          if ([RelatorioPedidoTipo.totaisPedidos, RelatorioPedidoTipo.totais]
              .contains(model.tipo)) ...[
            _totaisWidget(),
            const H(16),
          ],
          if ([RelatorioPedidoTipo.totaisPedidos, RelatorioPedidoTipo.pedidos]
              .contains(model.tipo)) ...[
            _pedidosWidget(model),
          ],
        ],
      ),
    );
  }

  Widget _pedidosWidget(RelatorioPedidoViewModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Pedidos Detalhados', style: AppCss.mediumBold),
        ),
        ...model.relatorio!.pedidos.map((e) => itemRelatorio(e)),
      ],
    );
  }

  Widget _filterWidget(RelatorioPedidoViewModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          AppDropDown<ClienteModel?>(
            label: 'Cliente',
            hasFilter: true,
            item: model.cliente,
            itens: [null, ...FirestoreClient.clientes.data],
            itemLabel: (e) => e?.nome ?? 'TODOS',
            onSelect: (e) {
              model.cliente = e;
              model.status.clear();
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const H(16),
          AppDropDownList<PedidoProdutoStatus>(
            label: 'Status',
            addeds: model.status,
            itens: PedidoProdutoStatus.values,
            itemLabel: (e) => e.label,
            itemColor: (e) => e.color.withValues(alpha: 0.1),
            onChanged: () {
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const H(16),
          AppDropDownList<ProdutoModel>(
            label: 'Bitolas',
            addeds: model.produtos,
            itens: FirestoreClient.produtos.data,
            itemLabel: (e) => e.descricao,
            onChanged: () {
              relatorioCtrl.pedidoViewModelStream.add(model);
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
          const H(16),
          Row(
            children: [
              Expanded(
                child: AppDropDown<SortType>(
                  label: 'Ordernar por',
                  item: model.sortType,
                  itens: model.sortTypes,
                  itemLabel: (e) => e.name,
                  onSelect: (e) {
                    model.sortType = e ?? SortType.alfabetic;
                    relatorioCtrl.pedidoViewModelStream.add(model);
                    relatorioCtrl.onCreateRelatorioPedido();
                  },
                ),
              ),
              const W(16),
              Expanded(
                child: AppDropDown<SortOrder>(
                  label: 'Ordernar',
                  item: model.sortOrder,
                  itens: SortOrder.values,
                  itemLabel: (e) => e.name,
                  onSelect: (e) {
                    model.sortOrder = e ?? SortOrder.asc;
                    relatorioCtrl.pedidoViewModelStream.add(model);
                    relatorioCtrl.onCreateRelatorioPedido();
                  },
                ),
              ),
            ],
          ),
          const H(16),
          AppDropDown<RelatorioPedidoTipo>(
            label: 'Tipo de Relatório',
            item: model.tipo,
            itens: RelatorioPedidoTipo.values,
            itemLabel: (e) => e.label,
            onSelect: (e) {
              model.tipo = e!;
              relatorioCtrl.pedidoViewModelStream.update();
              relatorioCtrl.onCreateRelatorioPedido();
            },
          ),
        ],
      ),
    );
  }

  Widget _totaisWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RESUMO GERAL', style: AppCss.mediumBold),
              Text(
                'Total: ${relatorioCtrl.getPedidosTotal().toKg()}',
                style: AppCss.mediumBold.setColor(AppColors.primaryMain),
              ),
            ],
          ),
          const H(12),
          _barraPercentualWidget(),
          const H(24),
          Text('Resumo por Bitola', style: AppCss.mediumBold),
          const H(8),
          for (final produto in FirestoreClient.produtos.data)
            Builder(
              builder: (context) {
                double totalBitola =
                    relatorioCtrl.getPedidosTotalPorBitola(produto);
                if (totalBitola <= 0) return const SizedBox();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bitola ${produto.descricaoReplaced}mm',
                          style: AppCss.minimumBold),
                      Text(totalBitola.toKg(), style: AppCss.minimumBold),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _barraPercentualWidget() {
    double total = relatorioCtrl.getPedidosTotal();
    if (total <= 0) return const SizedBox();

    return Column(
      children: [
        Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: PedidoProdutoStatus.values.map((status) {
                double qtde = relatorioCtrl.getPedidosTotalPorStatus(status);
                if (qtde <= 0) return const SizedBox();
                return Expanded(
                  flex: (qtde * 100).toInt(),
                  child: Container(
                    color: status.color,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const H(12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: PedidoProdutoStatus.values.map((status) {
            double qtde = relatorioCtrl.getPedidosTotalPorStatus(status);
            if (qtde <= 0) return const SizedBox();
            double percent = (qtde / total) * 100;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const W(4),
                Text(
                  '${status.label}: ${qtde.toKg()} (${percent.toStringAsFixed(1)}%)',
                  style: AppCss.minimumRegular.setSize(12).setColor(Colors.grey[700]!),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget itemRelatorio(PedidoModel pedido) {
    if (pedido.produtos.isEmpty) return const SizedBox();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pedido.localizador,
                    style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(pedido.createdAt),
                  style: AppCss.minimumRegular.setSize(11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemInfoRow('Cliente', pedido.cliente.nome),
                _itemInfoRow('Tipo', pedido.tipo.label),
                _itemInfoRow('Entrega',
                    pedido.deliveryAt?.text() ?? 'Não definida'),
                if (pedido.descricao.isNotEmpty)
                  _itemInfoRow('Obs', pedido.descricao),
                const Divisor(height: 24),
                for (final produto in pedido.produtos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${produto.produto.descricaoReplaced}mm',
                            style: AppCss.minimumRegular),
                        Text(
                          '${produto.qtde.toKg()} (${produto.status.status.label})',
                          style: AppCss.minimumBold
                              .setColor(produto.status.status.color),
                        ),
                      ],
                    ),
                  ),
                const Divisor(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL', style: AppCss.mediumBold),
                    Text(pedido.getQtdeTotal().toKg(),
                        style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:',
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
          ),
          Expanded(
            child: Text(value, style: AppCss.minimumRegular),
          ),
        ],
      ),
    );
  }
}
