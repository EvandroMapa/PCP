import 'dart:html' as html;
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_page.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/core/enums/app_module.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_arquivadas_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrdensPage extends StatefulWidget {
  final bool standalone;
  const OrdensPage({this.standalone = false, super.key});

  @override
  State<OrdensPage> createState() => _OrdensPageState();
}

class _OrdensPageState extends State<OrdensPage> {
  bool _emFullscreen = false;
  int _standaloneTabIndex = 0;

  @override
  void initState() {
    setWebTitle(widget.standalone
        ? 'AçoPlus - Ordens de Produção'
        : 'AçoPlus - Planejamento e controle de Produção');
    ordemCtrl.onInit();
    if (widget.standalone) ordemCtrl.modoOperadorAtivo = true;
    if (widget.standalone && kIsWeb) {
      // Fullscreen automático para rotas standalone
      html.document.onFullscreenChange.listen((_) {
        final estaFullscreen = html.document.fullscreenElement != null;
        if (mounted) setState(() => _emFullscreen = estaFullscreen);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entrarFullscreen();
      });
    }
    if (!widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        baseCtrl.appBarActionsStream.add(ordemCtrl.isEmModoOperador
            ? []
            : [
                Tooltip(
                  message: 'Ordens Arquivadas',
                  child: IconButton(
                    onPressed: () =>
                        push(context, const OrdensArquivadasPage()),
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
                if (usuario.permission.ordem
                    .contains(UserPermissionType.create))
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
  void dispose() {
    if (widget.standalone) {
      ordemCtrl.modoOperadorAtivo = false;
      if (kIsWeb) _sairFullscreen();
    }
    super.dispose();
  }

  void _entrarFullscreen() {
    try {
      final el = html.document.documentElement ?? html.document.body;
      el?.requestFullscreen();
      if (mounted) setState(() => _emFullscreen = true);
    } catch (e) {
      debugPrint('Fullscreen error: $e');
    }
  }

  void _sairFullscreen() {
    try {
      html.document.exitFullscreen();
      if (mounted) setState(() => _emFullscreen = false);
    } catch (e) {
      debugPrint('Exit fullscreen error: $e');
    }
  }

  void _toggleFullscreen() {
    _emFullscreen ? _sairFullscreen() : _entrarFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: _emFullscreen
                ? 'Sair do modo tela cheia'
                : 'Entrar em tela cheia',
            onPressed: _toggleFullscreen,
            icon: Icon(
              _emFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Text(
                _standaloneTabIndex == 0 ? 'Ordens de Produção' : 'Matéria Prima',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                usuario.nome,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryMain,
          actions: [
            if (_standaloneTabIndex == 1)
              IconButton(
                onPressed: () => push(context, const MateriaPrimaCreatePage()),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                tooltip: 'Adicionar Matéria Prima',
              ),
            IconButton(
              onPressed: () => usuarioCtrl.clearCurrentUser(),
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              tooltip: 'Sair',
            ),
          ],
        ),
        body: _standaloneTabIndex == 0
            ? body()
            : const MateriasPrimasPage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _standaloneTabIndex,
          onTap: (index) => setState(() => _standaloneTabIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              label: 'Ordens',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Matéria Prima',
            ),
          ],
        ),
      );
    }
    return body();
  }

  Widget body() {
    return StreamOut<List<ElementoModel>>(
      stream: AppSupabaseClient.elementos.dataStream.listen,
      builder: (_, ___) => StreamOut<List<OrdemModel>>(
        stream: FirestoreClient.ordens.ordensNaoArquivadasStream.listen,
        builder: (_, __) => StreamOut<OrdemUtils>(
          stream: ordemCtrl.utilsStream.listen,
          builder: (_, utils) {
            List<OrdemModel> ordens =
                ordemCtrl.getOrdensFiltered(utils.search.text, __).toList();
            if (utils.status.isNotEmpty) {
              ordens =
                  ordens.where((e) => utils.status.contains(e.status)).toList();
            }
            if (utils.produto != null) {
              ordens = ordens
                  .where((e) => e.produto.id == utils.produto!.id)
                  .toList();
            }
            if (utils.equipamento != null) {
              ordens = ordens
                  .where((e) => e.equipamento?.id == utils.equipamento!.id)
                  .toList();
            }
            if (ordemCtrl.isEmModoOperador) {
              ordens = ordens
                  .where(
                    (e) => [
                      PedidoBitolaStatus.aguardandoProducao,
                      PedidoBitolaStatus.produzindo,
                      PedidoBitolaStatus.pronto,
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
                          AppDropDown<BitolaModel?>(
                            label: 'Bitola',
                            item: utils.produto,
                            itens: FirestoreClient.bitolas.data.toList()
                              ..sort((a, b) {
                                final cmp = a.sortIndex.compareTo(b.sortIndex);
                                if (cmp != 0) return cmp;
                                return a.number.compareTo(b.number);
                              }),
                            itemLabel: (e) => e != null
                                ? e.descricao
                                : 'Selecione um produto',
                            onSelect: (e) {
                              utils.produto = e;
                              ordemCtrl.utilsStream.update();
                            },
                          ),
                          const H(16),
                          AppDropDownList<PedidoBitolaStatus>(
                            label: 'Ordernar por',
                            addeds: utils.status,
                            itens: const [
                              PedidoBitolaStatus.aguardandoProducao,
                              PedidoBitolaStatus.produzindo,
                              PedidoBitolaStatus.pronto,
                            ],
                            itemLabel: (e) => e.label,
                            itemColor: (e) => e.color,
                            onChanged: () {
                              ordemCtrl.utilsStream.update();
                            },
                          ),
                          const H(16),
                          AppDropDown<EquipamentoModel?>(
                            label: 'Equipamento',
                            item: utils.equipamento,
                            itens: FirestoreClient.equipamentos.data.toList(),
                            itemLabel: (e) => e != null
                                ? e.label
                                : 'Todos os equipamentos',
                            onSelect: (e) {
                              utils.equipamento = e;
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
                        if (ordemCtrl.isEmModoOperador) {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ordensNaoConcluidas.length,
                            itemBuilder: (_, i) =>
                                _itemOrdemWidget(ordensNaoConcluidas[i], i),
                          );
                        }
                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          cacheExtent: 200,
                          itemCount: ordensNaoConcluidas.length,
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) {
                              newIndex = newIndex - 1;
                            }
                            final step = ordensNaoConcluidas.removeAt(oldIndex);
                            ordensNaoConcluidas.insert(newIndex, step);
                            ordemCtrl.onReorder(ordensNaoConcluidas);
                          },
                          itemBuilder: (_, i) =>
                              _itemOrdemWidget(ordensNaoConcluidas[i], i),
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
                              _itemOrdemWidget(ordensCongeladas[i], i),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _itemOrdemWidget(OrdemModel ordem, int index) {
    final isFreezed = ordem.freezed.isFreezed;
    final statusColor = isFreezed ? Colors.grey[500]! : ordem.status.color;

    return Padding(
      key: ValueKey(ordem.id),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              if (!ordemCtrl.isEmModoOperador && !isFreezed)
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    width: 40,
                    color: AppColors.black.withValues(alpha: 0.02),
                    child: Center(
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey[400],
                        size: 26,
                      ),
                    ),
                  ),
                ),
              // Conteúdo principal (tocável)
              Expanded(
                child: InkWell(
                  onTap: () =>
                      push(context, OrdemPage(ordem.id, ordem: ordem)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: número + posição + badge status
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ordem.localizator,
                              style: AppCss.largeBold.setSize(17),
                            ),
                            if (!isFreezed &&
                                ordem.beltIndex != null &&
                                !ordemCtrl.isEmModoOperador)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMain
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${ordem.beltIndex! + 1}ª na fila',
                                  style: AppCss.minimumBold
                                      .setSize(10)
                                      .setColor(AppColors.primaryMain),
                                ),
                              ),
                            // Badge status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                isFreezed
                                    ? 'CONGELADA'
                                    : ordem.status.label.toUpperCase(),
                                style: AppCss.minimumBold
                                    .setSize(10)
                                    .setColor(statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Produto + bitola
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 6, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${ordem.produto.nome} · ${ordem.produto.descricao}',
                                style: AppCss.minimumRegular
                                    .setSize(12)
                                    .setColor(Colors.grey[700]!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (ordem.materiaPrima != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ordem.materiaPrima!.label,
                                  style: AppCss.minimumRegular
                                      .setSize(11)
                                      .setColor(Colors.grey[500]!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Footer: peso total + estoque antes/depois + gráficos
                        Builder(builder: (context) {
                          final pesoOrdem = ordem.produtos
                              .fold(0.0, (prev, e) => prev + e.qtde);
                          final estoque = BackendClient.estoques
                              .getByProdutoId(ordem.produto.id);
                          final estoqueAntes = estoque?.quantidade ?? 0.0;
                          final estoqueDepois = estoqueAntes - pesoOrdem;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryMain
                                          .withValues(alpha: 0.06),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      pesoOrdem.toKg(),
                                      style: AppCss.mediumBold
                                          .setSize(13)
                                          .setColor(AppColors.primaryMain),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      'Est: ${estoqueAntes.toKg()} → ${estoqueDepois.toKg()}',
                                      style: AppCss.minimumRegular
                                          .setSize(10)
                                          .setColor(estoqueDepois < 0
                                              ? Colors.red[400]!
                                              : Colors.grey[600]!),
                                    ),
                                  ),
                                  if (ordem.produtos.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _progressChartWidget(
                                            PedidoBitolaStatus
                                                .aguardandoProducao,
                                            ordem.getPrcntgAguardando(),
                                            isFreezed),
                                        const SizedBox(width: 12),
                                        _progressChartWidget(
                                            PedidoBitolaStatus.produzindo,
                                            ordem.getPrcntgProduzindo(),
                                            isFreezed),
                                        const SizedBox(width: 12),
                                        _progressChartWidget(
                                            PedidoBitolaStatus.pronto,
                                            ordem.getPrcntgPronto(),
                                            isFreezed),
                                      ],
                                    ),
                                  if (ordem.produtos.isEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Symbols.brightness_empty,
                                            size: 18,
                                            color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Text('Vazia',
                                            style: AppCss.minimumRegular
                                                .setColor(
                                                    Colors.grey[400]!)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Data de criação da ordem
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Criada em ${ordem.createdAt.textHour()}',
                                    style: AppCss.minimumRegular
                                        .setSize(11)
                                        .setColor(Colors.grey[400]!),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              // Tarja de ações (somente não-operadores)
              if (usuario.isNotOperador)
                _tarjaAcoes(context, ordem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjaAcoes(BuildContext context, OrdemModel ordem) {
    return Container(
      width: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        border: Border(
          left: BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tarjaBtn(
            icon: Icons.delete_outline,
            color: Colors.red[400]!,
            tooltip: 'Excluir ordem',
            onTap: () => ordemCtrl.onDelete(context, ordem),
          ),
          const SizedBox(height: 6),
          _tarjaBtn(
            icon: Icons.analytics_outlined,
            color: Colors.blueGrey[400]!,
            tooltip: 'Relatórios de Produção',
            onTap: () =>
                baseCtrl.moduleStream.add(AppModule.relatoriosProducao),
          ),
        ],
      ),
    );
  }

  Widget _tarjaBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _progressChartWidget(
    PedidoBitolaStatus status,
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
          status == PedidoBitolaStatus.aguardandoProducao
              ? 'Ag.'
              : status == PedidoBitolaStatus.produzindo
                  ? 'Prod.'
                  : 'Pronto',
          style: AppCss.minimumRegular.setSize(9).setColor(Colors.grey[500]!),
        ),
      ],
    );
  }
}
