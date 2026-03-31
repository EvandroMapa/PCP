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
            _totaisWidget(model),
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

  Widget _totaisWidget(RelatorioPedidoViewModel model) {
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
                final isExpanded = model.expandedProdutosIds.contains(produto.id);
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        if (isExpanded) {
                          model.expandedProdutosIds.remove(produto.id);
                        } else {
                          model.expandedProdutosIds.add(produto.id);
                        }
                        relatorioCtrl.pedidoViewModelStream.update();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const W(8),
                            Expanded(
                              child: Text('Bitola ${produto.descricaoReplaced}mm',
                                  style: AppCss.minimumBold),
                            ),
                            Text(totalBitola.toKg(), style: AppCss.minimumBold),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) _bitolaDetalheWidget(model, produto, totalBitola),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _bitolaDetalheWidget(
      RelatorioPedidoViewModel model, ProdutoModel produto, double totalBitola) {
    List<PedidoModel> pedidos = model.relatorio!.pedidos
        .where((p) => p.produtos.any((pr) => pr.produto.id == produto.id))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 0, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        border: Border(left: BorderSide(color: AppColors.primaryMain, width: 3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        child: Column(
          children: pedidos.asMap().entries.map((entry) {
            int index = entry.key;
            PedidoModel pedido = entry.value;
            double qtde = pedido.produtos
                .where((p) => p.produto.id == produto.id)
                .fold(0, (prev, curr) => prev + curr.qtde);
            double percent = (qtde / totalBitola) * 100;
            bool isOdd = index % 2 != 0;

            return Container(
              color: isOdd ? Colors.grey[100] : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(pedido.localizador,
                        style: AppCss.minimumBold.setSize(12)),
                  ),
                  Text(qtde.toKg(),
                      style: AppCss.minimumBold
                          .setSize(12)
                          .setColor(AppColors.primaryMain)),
                  const W(16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${percent.toStringAsFixed(1)}%',
                        style: AppCss.minimumBold
                            .setSize(10)
                            .setColor(AppColors.primaryMain)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.primaryMain.withValues(alpha: 0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pedido.cliente.nome.toUpperCase(),
                        style: AppCss.minimumBold
                            .setSize(13)
                            .setColor(AppColors.primaryMain),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const W(8),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(pedido.createdAt),
                      style: AppCss.minimumRegular
                          .setSize(10)
                          .setColor(Colors.grey[600]!),
                    ),
                  ],
                ),
                const H(4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pedido.localizador,
                        style: AppCss.minimumBold
                            .setSize(10)
                            .setColor(Colors.white),
                      ),
                    ),
                    const W(8),
                    Text(
                      pedido.tipo.label,
                      style: AppCss.minimumRegular
                          .setSize(11)
                          .setColor(Colors.grey[700]!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Colors.grey),
                    const W(6),
                    Text(
                      'Entrega: ${pedido.deliveryAt?.text() ?? 'Não definida'}',
                      style: AppCss.minimumRegular.setSize(12),
                    ),
                  ],
                ),
                if (pedido.descricao.isNotEmpty) ...[
                  const H(8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes, size: 14, color: Colors.grey),
                      const W(6),
                      Expanded(
                        child: Text(
                          pedido.descricao,
                          style: AppCss.minimumRegular
                              .setSize(12)
                              .setColor(Colors.grey[700]!),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divisor(height: 24),
                for (final produto in pedido.produtos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: produto.status.status.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const W(8),
                            Text('${produto.produto.descricaoReplaced}mm',
                                style: AppCss.minimumRegular),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              produto.qtde.toKg(),
                              style: AppCss.minimumBold,
                            ),
                            const W(8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: produto.status.status.color
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                produto.status.status.label,
                                style: AppCss.minimumBold
                                    .setSize(9)
                                    .setColor(produto.status.status.color),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divisor(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL DO PEDIDO',
                        style: AppCss.minimumBold.setColor(Colors.grey[700]!)),
                    Text(
                      pedido.getQtdeTotal().toKg(),
                      style: AppCss.mediumBold.setColor(AppColors.primaryMain),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
