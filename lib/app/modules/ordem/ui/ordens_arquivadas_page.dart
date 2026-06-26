import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrdensArquivadasPage extends StatefulWidget {
  const OrdensArquivadasPage({super.key});

  @override
  State<OrdensArquivadasPage> createState() => _OrdensArquivadasPageState();
}

class _OrdensArquivadasPageState extends State<OrdensArquivadasPage> {
  // Mês selecionado — começa no mês atual
  late DateTime _mesSelecionado;
  bool _carregando = true; // já começa carregando

  @override
  void initState() {
    super.initState();
    ordemCtrl.onInit();
    final agora = DateTime.now();
    _mesSelecionado = DateTime(agora.year, agora.month, 1);
    // Aguarda o primeiro frame antes de chamar setState interno
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _carregarMes(_mesSelecionado),
    );
  }

  /// Dispara o fetch filtrado por período e atualiza o estado de loading
  Future<void> _carregarMes(DateTime mes) async {
    if (mounted) setState(() => _carregando = true);
    final inicio = DateTime(mes.year, mes.month, 1);
    final fim = DateTime(mes.year, mes.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    await FirestoreClient.ordens
        .startOnlyArquivadas(de: inicio, ate: fim);
    if (mounted) setState(() => _carregando = false);
  }

  void _irParaMesAnterior() {
    final novo = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1, 1);
    setState(() => _mesSelecionado = novo);
    _carregarMes(novo);
  }

  void _irParaProximoMes() {
    final agora = DateTime.now();
    final proximoMes =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 1);
    // Não avança além do mês atual
    if (proximoMes.isAfter(DateTime(agora.year, agora.month, 1))) return;
    setState(() => _mesSelecionado = proximoMes);
    _carregarMes(proximoMes);
  }

  bool get _estaNaMesAtual {
    final agora = DateTime.now();
    return _mesSelecionado.year == agora.year &&
        _mesSelecionado.month == agora.month;
  }

  String get _labelMes {
    final agora = DateTime.now();
    if (_estaNaMesAtual) return 'Este mês';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${meses[_mesSelecionado.month - 1]} de ${_mesSelecionado.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        title: Text(
          'Ordens Arquivadas',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          Tooltip(
            message: 'Filtro',
            child: IconButton(
              onPressed: () {
                setState(() {
                  ordemCtrl.utilsArquivadas.showFilter =
                      !ordemCtrl.utilsArquivadas.showFilter;
                  ordemCtrl.utilsArquivadasStream.update();
                });
              },
              icon: Icon(Icons.sort, color: AppColors.white),
            ),
          ),
          const W(8),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: Column(
        children: [
          // ── Seletor de mês ──
          _buildSeletorMes(),

          // ── Conteúdo ──
          Expanded(
            child: _carregando
                ? _buildSpinner()
                : StreamOut<List<OrdemModel>>(
                    stream:
                        FirestoreClient.ordens.ordensArquivadasStream.listen,
                    builder: (_, __) =>
                        StreamOut<OrdemArquivadasUtils>(
                          stream:
                              ordemCtrl.utilsArquivadasStream.listen,
                          builder: (_, utilsArquivadas) {
                            List<OrdemModel> ordens = ordemCtrl
                                .getOrdensFiltered(
                                  utilsArquivadas.search.text,
                                  __.where((e) => e.produtos.isNotEmpty).toList(),
                                )
                                .toList();

                            if (utilsArquivadas.produto != null) {
                              ordens = ordens
                                  .where((e) =>
                                      e.produto.id ==
                                      utilsArquivadas.produto!.id)
                                  .toList();
                            }

                            ordens.sort(
                                (a, b) => b.archivedAt.compareTo(a.archivedAt));

                            return RefreshIndicator(
                              onRefresh: () => _carregarMes(_mesSelecionado),
                              child: ListView(
                                children: [
                                  if (utilsArquivadas.showFilter)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          AppField(
                                            label: 'Pesquisar',
                                            controller: utilsArquivadas.search,
                                            suffixIcon: Icons.search,
                                            onChanged: (_) => ordemCtrl
                                                .utilsArquivadasStream
                                                .update(),
                                          ),
                                          const H(16),
                                          AppDropDown<BitolaModel?>(
                                            label: 'Bitola',
                                            item: utilsArquivadas.produto,
                                            itens: FirestoreClient.bitolas.data
                                                .toList(),
                                            itemLabel: (e) => e != null
                                                ? e.descricao
                                                : 'Selecione um produto',
                                            onSelect: (e) {
                                              utilsArquivadas.produto = e;
                                              ordemCtrl.utilsArquivadasStream
                                                  .update();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Resumo do período
                                  if (ordens.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 8, 16, 0),
                                      child: Text(
                                        '${ordens.length} ordem${ordens.length > 1 ? 's' : ''} arquivada${ordens.length > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),

                                  ordens.isEmpty
                                      ? _buildVazio()
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          cacheExtent: 200,
                                          itemCount: ordens.length,
                                          itemBuilder: (_, i) =>
                                              _itemOrdemWidget(ordens[i]),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Seletor de mês ──────────────────────────────────────────────────────────

  Widget _buildSeletorMes() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Botão mês anterior
          IconButton(
            onPressed: _irParaMesAnterior,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primaryMain,
            iconSize: 22,
            tooltip: 'Mês anterior',
            style: IconButton.styleFrom(
              backgroundColor:
                  AppColors.primaryMain.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
            ),
          ),
          const SizedBox(width: 8),

          // Label do mês selecionado
          Expanded(
            child: GestureDetector(
              onTap: _abrirSeletorMes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primaryMain.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 15, color: AppColors.primaryMain),
                    const SizedBox(width: 6),
                    Text(
                      _labelMes,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMain,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 18, color: AppColors.primaryMain),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Botão próximo mês (desabilitado se for mês atual)
          IconButton(
            onPressed: _estaNaMesAtual ? null : _irParaProximoMes,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _estaNaMesAtual
                ? Colors.grey[300]
                : AppColors.primaryMain,
            iconSize: 22,
            tooltip: 'Próximo mês',
            style: IconButton.styleFrom(
              backgroundColor: _estaNaMesAtual
                  ? Colors.grey[100]
                  : AppColors.primaryMain.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre um seletor de ano/mês com scroll
  Future<void> _abrirSeletorMes() async {
    final agora = DateTime.now();
    DateTime? escolhido = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _DialogSeletorMes(
        inicial: _mesSelecionado,
        maximo: DateTime(agora.year, agora.month, 1),
      ),
    );
    if (escolhido != null && mounted) {
      setState(() => _mesSelecionado = escolhido);
      _carregarMes(escolhido);
    }
  }

  // ── Spinner ─────────────────────────────────────────────────────────────────

  Widget _buildSpinner() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryMain,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Carregando ordens de $_labelMes...',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Vazio ────────────────────────────────────────────────────────────────────

  Widget _buildVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Nenhuma ordem arquivada',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              'em $_labelMes',
              style: TextStyle(fontSize: 13, color: Colors.grey[350]),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _irParaMesAnterior,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Ver mês anterior'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item da ordem ────────────────────────────────────────────────────────────

  Widget _itemOrdemWidget(OrdemModel ordem) {
    return InkWell(
      key: ValueKey(ordem.id),
      onTap: () => push(context, OrdemPage(ordem.id, ordem: ordem)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconLoadingButton(
                () async =>
                    await ordemCtrl.onUnarchive(context, ordem, 1),
                icon: Icons.unarchive,
              ),
              const W(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ordem.localizator, style: AppCss.mediumBold),
                    Text(
                      '${ordem.produto.nome} ${ordem.produto.descricao} - ${ordem.produtos.fold(0.0, (previousValue, element) => previousValue + element.qtde).toKg()}',
                      style: AppCss.minimumRegular
                          .setSize(11)
                          .setColor(AppColors.black),
                    ),
                    Text(
                      'Arquivada ${ordem.archivedAt.textHour()}',
                      style: AppCss.minimumRegular
                          .setSize(11)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ],
                ),
              ),
              const W(8),
              if (ordem.produtos.isNotEmpty)
                Row(
                  children: [
                    _progressChartWidget(
                      PedidoBitolaStatus.aguardandoProducao,
                      ordem.getPrcntgAguardando(),
                      ordem.freezed.isFreezed,
                    ),
                    const W(16),
                    _progressChartWidget(
                      PedidoBitolaStatus.produzindo,
                      ordem.getPrcntgProduzindo(),
                      ordem.freezed.isFreezed,
                    ),
                    const W(16),
                    _progressChartWidget(
                      PedidoBitolaStatus.pronto,
                      ordem.getPrcntgPronto(),
                      ordem.freezed.isFreezed,
                    ),
                  ],
                ),
              if (ordem.produtos.isEmpty)
                const Row(
                  children: [
                    Text('Ordem Vazia'),
                    W(8),
                    Icon(Symbols.brightness_empty),
                  ],
                ),
              const W(16),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.neutralMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressChartWidget(
    PedidoBitolaStatus status,
    double porcentagem,
    bool isFreezed,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: porcentagem,
          backgroundColor: (isFreezed ? Colors.grey[600]! : status.color)
              .withValues(alpha: 0.2),
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            isFreezed ? Colors.grey[600]! : status.color,
          ),
        ),
        Text(
          '${(porcentagem * 100).percent}%',
          style: AppCss.minimumBold.setSize(10),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Dialog seletor de mês/ano
// ═════════════════════════════════════════════════════════════════════════════

class _DialogSeletorMes extends StatefulWidget {
  final DateTime inicial;
  final DateTime maximo;

  const _DialogSeletorMes({required this.inicial, required this.maximo});

  @override
  State<_DialogSeletorMes> createState() => _DialogSeletorMesState();
}

class _DialogSeletorMesState extends State<_DialogSeletorMes> {
  late int _anoSelecionado;
  late int _mesSelecionado;

  static const _nomeMeses = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  void initState() {
    super.initState();
    _anoSelecionado = widget.inicial.year;
    _mesSelecionado = widget.inicial.month;
  }

  bool _isBloqueado(int ano, int mes) {
    final data = DateTime(ano, mes, 1);
    final max = DateTime(widget.maximo.year, widget.maximo.month, 1);
    return data.isAfter(max);
  }

  @override
  Widget build(BuildContext context) {
    // Anos disponíveis: 3 anos atrás até o ano atual
    final anoAtual = widget.maximo.year;
    final anosDisponiveis =
        List.generate(4, (i) => anoAtual - 3 + i).reversed.toList();

    return AlertDialog(
      title: const Text('Selecionar período'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seletor de ano
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _anoSelecionado > anosDisponiveis.last
                      ? () => setState(() => _anoSelecionado--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 20,
                  color: AppColors.primaryMain,
                ),
                Text(
                  '$_anoSelecionado',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: _anoSelecionado < anoAtual
                      ? () => setState(() => _anoSelecionado++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 20,
                  color: _anoSelecionado < anoAtual
                      ? AppColors.primaryMain
                      : Colors.grey[300],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grade de meses
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(12, (i) {
                final mes = i + 1;
                final bloqueado = _isBloqueado(_anoSelecionado, mes);
                final selecionado = mes == _mesSelecionado &&
                    _anoSelecionado == widget.inicial.year;
                final ativo = !bloqueado;

                return GestureDetector(
                  onTap: ativo
                      ? () {
                          setState(() => _mesSelecionado = mes);
                          Navigator.pop(
                            context,
                            DateTime(_anoSelecionado, mes, 1),
                          );
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: bloqueado
                          ? Colors.grey[100]
                          : selecionado
                              ? AppColors.primaryMain
                              : AppColors.primaryMain.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selecionado
                            ? AppColors.primaryMain
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _nomeMeses[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: bloqueado
                            ? Colors.grey[350]
                            : selecionado
                                ? Colors.white
                                : AppColors.primaryMain,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
