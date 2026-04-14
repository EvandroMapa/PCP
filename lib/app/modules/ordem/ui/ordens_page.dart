import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/fullscreen_button.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_arquivadas_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrdensPage extends StatefulWidget {
  final bool standalone;
  const OrdensPage({this.standalone = false, super.key});

  @override
  State<OrdensPage> createState() => _OrdensPageState();
}

class _OrdensPageState extends State<OrdensPage> {
  @override
  void initState() {
    setWebTitle(widget.standalone ? 'AçoPlus - Ordens de Produção' : 'AçoPlus - Planejamento e controle de Produção');
    ordemCtrl.onInit();
    if (!widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        baseCtrl.appBarActionsStream.add(usuario.isOperador
            ? [FullscreenButton()]
            : [
                FullscreenButton(),
                IconButton(
                  onPressed: () => openInNewTab('/ordens'),
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  tooltip: 'Abrir em nova aba',
                ),
                Tooltip(
                  message: 'Ordens Arquivadas',
                  child: IconButton(
                    onPressed: () => push(context, const OrdensArquivadasPage()),
                    icon: const Icon(
                      Icons.document_scanner,
                      color: Colors.white,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Filtro',
                  child: IconButton(
                    onPressed: () {
                      ordemCtrl.utils.showFilter = !ordemCtrl.utils.showFilter;
                      ordemCtrl.utilsStream.update();
                    },
                    icon: const Icon(Icons.sort, color: Colors.white),
                  ),
                ),
                if (usuario.permission.ordem.contains(UserPermissionType.create))
                  Tooltip(
                    message: 'Nova ordem',
                    child: IconButton(
                      onPressed: () => push(context, const OrdemCreatePage()),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
              ]);
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ordens de Produção', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primaryMain,
          actions: [
            if (usuario.isOperador) FullscreenButton(),
            if (!usuario.isOperador) ...[
              IconButton(
                onPressed: () => push(context, const OrdensArquivadasPage()),
                icon: const Icon(
                  Icons.domain_verification,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  ordemCtrl.utils.showFilter = !ordemCtrl.utils.showFilter;
                  ordemCtrl.utilsStream.update();
                },
                icon: const Icon(Icons.sort, color: Colors.white),
              ),
              if (usuario.permission.ordem.contains(UserPermissionType.create))
                IconButton(
                  onPressed: () => push(context, const OrdemCreatePage()),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
            ],
          ],
        ),
        body: body(),
      );
    }
    return body();
  }

  Widget body() {
    return StreamOut<List<OrdemModel>>(
      stream: FirestoreClient.ordens.ordensNaoArquivadasStream.listen,
      builder: (_, __) => StreamOut<OrdemUtils>(
        stream: ordemCtrl.utilsStream.listen,
        builder: (_, utils) {
          List<OrdemModel> ordens =
              ordemCtrl.getOrdensFiltered(utils.search.text, __).toList();
          if (utils.status.isNotEmpty) {
            ordens = ordens.where((e) => utils.status.contains(e.status)).toList();
          }
          if (utils.produto != null) {
            ordens = ordens.where((e) => e.produto.id == utils.produto!.id).toList();
          }
          if (usuario.isOperador) {
            ordens = ordens
                .where(
                  (e) => [
                    PedidoProdutoStatus.aguardandoProducao,
                    PedidoProdutoStatus.produzindo,
                    PedidoProdutoStatus.pronto,
                  ].contains(e.status),
                )
                .toList();
          }

          return RefreshIndicator(
            onRefresh: () async => FirestoreClient.ordens.fetch(),
            child: ListView(
              children: [
                if (utils.showFilter)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        AppField(
                          label: 'Pesquisar',
                          controller: utils.search,
                          suffixIcon: Icons.search,
                          onChanged: (_) => ordemCtrl.utilsStream.update(),
                        ),
                        const H(16),
                        AppDropDown<ProdutoModel?>(
                          label: 'Bitola',
                          item: utils.produto,
                          itens: FirestoreClient.produtos.data.toList(),
                          itemLabel: (e) =>
                              e != null ? e.descricao : 'Selecione um produto',
                          onSelect: (e) {
                            utils.produto = e;
                            ordemCtrl.utilsStream.update();
                          },
                        ),
                        const H(16),
                        AppDropDownList<PedidoProdutoStatus>(
                          label: 'Ordernar por',
                          addeds: utils.status,
                          itens: const [
                            PedidoProdutoStatus.aguardandoProducao,
                            PedidoProdutoStatus.produzindo,
                            PedidoProdutoStatus.pronto,
                          ],
                          itemLabel: (e) => e.label,
                          itemColor: (e) => e.color,
                          onChanged: () {
                            ordemCtrl.utilsStream.update();
                          },
                        ),
                      ],
                    ),
                  ),
                if (ordens.isEmpty) const EmptyData(),
                if (ordens.isNotEmpty)
                  Builder(
                    builder: (_) {
                      final ordensNaoConcluidas =
                          ordens.where((e) => !e.freezed.isFreezed).toList();
                      if (ordensNaoConcluidas.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: EmptyData(),
                        );
                      }
                      if (usuario.isOperador) {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ordensNaoConcluidas.length,
                          itemBuilder: (_, i) =>
                              _itemOrdemWidget(ordensNaoConcluidas[i]),
                        );
                      }
                      return ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 200,
                        itemCount: ordensNaoConcluidas.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex = newIndex - 1;
                          }
                          final step = ordensNaoConcluidas.removeAt(oldIndex);
                          ordensNaoConcluidas.insert(newIndex, step);
                          ordemCtrl.onReorder(ordensNaoConcluidas);
                        },
                        itemBuilder: (_, i) =>
                            _itemOrdemWidget(ordensNaoConcluidas[i]),
                      );
                    },
                  ),
                if (usuario.isNotOperador)
                  Builder(
                    builder: (_) {
                      final ordensCongeladas = ordemCtrl.getOrdensFiltered(
                        utils.search.text,
                        FirestoreClient.ordens.ordensCongeladas,
                      );
                      ordensCongeladas.sort(
                        (a, b) => b.freezed.updatedAt.compareTo(
                          a.freezed.updatedAt,
                        ),
                      );
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        cacheExtent: 200,
                        itemCount: ordensCongeladas.length,
                        itemBuilder: (_, i) =>
                            _itemOrdemWidget(ordensCongeladas[i]),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemOrdemWidget(OrdemModel ordem) {
    final isFreezed = ordem.freezed.isFreezed;
    final statusColor = isFreezed ? Colors.grey[500]! : ordem.status.color;

    return Padding(
      key: ValueKey(ordem.id),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => push(context, OrdemPage(ordem.id, ordem: ordem)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isFreezed ? Colors.grey[100] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Borda lateral colorida pelo status
                Container(width: 5, color: statusColor),
                // Conteúdo principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: número + posição + badge status
                        Row(
                          children: [
                            Text(
                              ordem.localizator,
                              style: AppCss.largeBold.setSize(17),
                            ),
                            if (!isFreezed && ordem.beltIndex != null && usuario.isNotOperador)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMain.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${ordem.beltIndex! + 1}ª na fila',
                                  style: AppCss.minimumBold.setSize(10).setColor(AppColors.primaryMain),
                                ),
                              ),
                            const Spacer(),
                            // Badge status
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                isFreezed ? 'CONGELADA' : ordem.status.label.toUpperCase(),
                                style: AppCss.minimumBold.setSize(10).setColor(statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Produto + bitola
                        Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${ordem.produto.nome} · ${ordem.produto.descricao}',
                                style: AppCss.minimumRegular.setSize(12).setColor(Colors.grey[700]!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (ordem.materiaPrima != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ordem.materiaPrima!.label,
                                  style: AppCss.minimumRegular.setSize(11).setColor(Colors.grey[500]!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Footer: peso total + data + gráficos
                        Row(
                          children: [
                            // Peso total
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ordem.produtos.fold(0.0, (prev, e) => prev + e.qtde).toKg(),
                                style: AppCss.mediumBold.setSize(13).setColor(AppColors.primaryMain),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ordem.createdAt.textHour(),
                              style: AppCss.minimumRegular.setSize(11).setColor(Colors.grey[400]!),
                            ),
                            const Spacer(),
                            // Gráficos de progresso
                            if (ordem.produtos.isNotEmpty)
                              Row(
                                children: [
                                  _progressChartWidget(PedidoProdutoStatus.aguardandoProducao, ordem.getPrcntgAguardando(), isFreezed),
                                  const SizedBox(width: 12),
                                  _progressChartWidget(PedidoProdutoStatus.produzindo, ordem.getPrcntgProduzindo(), isFreezed),
                                  const SizedBox(width: 12),
                                  _progressChartWidget(PedidoProdutoStatus.pronto, ordem.getPrcntgPronto(), isFreezed),
                                ],
                              ),
                            if (ordem.produtos.isEmpty)
                              Row(
                                children: [
                                  Icon(Symbols.brightness_empty, size: 18, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text('Vazia', style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressChartWidget(
    PedidoProdutoStatus status,
    double porcentagem,
    bool isFreezed,
  ) {
    final color = isFreezed ? Colors.grey[500]! : status.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: porcentagem,
                backgroundColor: color.withValues(alpha: 0.15),
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(porcentagem * 100).percent}%',
                style: AppCss.minimumBold.setSize(9).setColor(color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          status == PedidoProdutoStatus.aguardandoProducao ? 'Ag.' :
          status == PedidoProdutoStatus.produzindo ? 'Prod.' : 'Pronto',
          style: AppCss.minimumRegular.setSize(9).setColor(Colors.grey[500]!),
        ),
      ],
    );
  }
}
