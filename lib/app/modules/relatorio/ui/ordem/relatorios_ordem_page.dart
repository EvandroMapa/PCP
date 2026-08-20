import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_ordem_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Helpers de tempo ────────────────────────────────────────────────────────

DateTime? _inicioProducao(PedidoBitolaModel p) {
  final produzindo = p.statusess
      .where((s) => s.status == PedidoBitolaStatus.produzindo)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (produzindo.isNotEmpty) return produzindo.first.createdAt;

  final pronto = p.statusess
      .where((s) => s.status == PedidoBitolaStatus.pronto)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return pronto.isEmpty ? null : pronto.first.createdAt;
}

DateTime? _fimProducao(PedidoBitolaModel p) {
  final s = p.statusess
      .where((s) => s.status == PedidoBitolaStatus.pronto)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return s.isEmpty ? null : s.last.createdAt;
}

DateTime? _ordemInicio(OrdemModel o) {
  final datas = o.produtos
      .map(_inicioProducao)
      .whereType<DateTime>()
      .toList()
    ..sort();
  return datas.isEmpty ? null : datas.first;
}

DateTime? _ordemFim(OrdemModel o) {
  if (o.endAt != null) return o.endAt;
  final datas = o.produtos
      .map(_fimProducao)
      .whereType<DateTime>()
      .toList()
    ..sort();
  if (datas.isNotEmpty) return datas.last;
  return o.updatedAt;
}

String _duracao(DateTime? inicio, DateTime? fim) {
  if (inicio == null || fim == null) return '—';
  final d = fim.difference(inicio);
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}min';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}min';
  return '${d.inMinutes}min';
}

String _fmt(DateTime? d) =>
    d != null ? DateFormat("dd/MM/yy HH:mm").format(d) : '—';

// ─── Enums de Filtro ─────────────────────────────────────────────────────────

enum RelatorioOrdemFiltroStatus {
  todas('Todas'),
  concluidas('Concluídas'),
  produzindo('Em Produção'),
  aguardando('Aguardando');

  final String label;
  const RelatorioOrdemFiltroStatus(this.label);
}

// ─── Page ────────────────────────────────────────────────────────────────────

class RelatoriosOrdemPage extends StatefulWidget {
  const RelatoriosOrdemPage({super.key});

  @override
  State<RelatoriosOrdemPage> createState() => _RelatoriosOrdemPageState();
}

class _RelatoriosOrdemPageState extends State<RelatoriosOrdemPage> {
  RelatorioOrdemFiltroStatus _filtroStatus = RelatorioOrdemFiltroStatus.todas;
  DateTimeRange? _periodo = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  BitolaModel? _bitola;
  String? _expandidoId;

  List<OrdemModel> _filtrarOrdens(List<OrdemModel> todas) {
    var lista = todas.toList();

    // Filtro por Status
    switch (_filtroStatus) {
      case RelatorioOrdemFiltroStatus.todas:
        break;
      case RelatorioOrdemFiltroStatus.concluidas:
        lista = lista.where((o) {
          if (o.isArchived) return true;
          final prods = o.produtos;
          return prods.isNotEmpty &&
              prods.every((p) => p.status.status == PedidoBitolaStatus.pronto);
        }).toList();
        break;
      case RelatorioOrdemFiltroStatus.produzindo:
        lista = lista
            .where((o) => !o.isArchived && o.status == PedidoBitolaStatus.produzindo)
            .toList();
        break;
      case RelatorioOrdemFiltroStatus.aguardando:
        lista = lista
            .where((o) =>
                !o.isArchived &&
                o.status == PedidoBitolaStatus.aguardandoProducao)
            .toList();
        break;
    }

    // Filtro bitola
    if (_bitola != null) {
      lista = lista.where((o) => o.produto.id == _bitola!.id).toList();
    }

    // Filtro período
    if (_periodo != null) {
      final inicio = DateTime(
          _periodo!.start.year, _periodo!.start.month, _periodo!.start.day);
      final fim = DateTime(_periodo!.end.year, _periodo!.end.month,
          _periodo!.end.day, 23, 59, 59);
      lista = lista.where((o) {
        final data = _ordemFim(o) ?? o.createdAt;
        return !data.isBefore(inicio) && !data.isAfter(fim);
      }).toList();
    }

    lista.sort((a, b) {
      final ia = _ordemInicio(a) ?? a.createdAt;
      final ib = _ordemInicio(b) ?? b.createdAt;
      return ib.compareTo(ia); // mais recentes primeiro
    });

    return lista;
  }

  // KPIs por lista
  double _totalKgDe(List<OrdemModel> ordens) =>
      ordens.fold(0.0, (s, o) => s + o.qtdeTotal);

  Duration _tempoMedioDe(List<OrdemModel> ordens) {
    final duracoes = ordens
        .map((o) {
          final i = _ordemInicio(o);
          final f = _ordemFim(o);
          if (i == null || f == null) return null;
          return f.difference(i);
        })
        .whereType<Duration>()
        .toList();
    if (duracoes.isEmpty) return Duration.zero;
    final total = duracoes.fold(Duration.zero, (a, b) => a + b);
    return Duration(microseconds: total.inMicroseconds ~/ duracoes.length);
  }

  @override
  void initState() {
    FirestoreClient.ordens.startOnlyArquivadas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        PopupMenuButton<RelatorioOrdensPdfExportarTipo>(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          tooltip: 'Exportar PDF',
          onSelected: (tipo) {
            final todas = [
              ...FirestoreClient.ordens.data,
              ...FirestoreClient.ordens.ordensArquivadas,
            ];
            relatorioCtrl.exportarRelatorioOrdensProduzidas(
              _filtrarOrdens(todas),
              tipo,
              periodo: _periodo,
              bitola: _bitola,
            );
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: RelatorioOrdensPdfExportarTipo.resumido,
              child: Row(children: [
                Icon(Icons.description_outlined, size: 18),
                SizedBox(width: 8),
                Text('PDF Resumido'),
              ]),
            ),
            const PopupMenuItem(
              value: RelatorioOrdensPdfExportarTipo.completo,
              child: Row(children: [
                Icon(Icons.description, size: 18),
                SizedBox(width: 8),
                Text('PDF Detalhado'),
              ]),
            ),
          ],
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<OrdemModel>>(
      stream: FirestoreClient.ordens.dataStream.listen,
      builder: (_, __) => StreamOut<List<OrdemModel>>(
        stream: FirestoreClient.ordens.ordensArquivadasStream.listen,
        builder: (_, ___) {
          final todas = [
            ...FirestoreClient.ordens.data,
            ...FirestoreClient.ordens.ordensArquivadas,
          ];
          final ordens = _filtrarOrdens(todas);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ordens de Produção',
                      style: AppCss.largeBold.setSize(22).setColor(const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text('Acompanhamento operacional, tempos de ciclo e status de corte e dobra',
                      style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de Filtros
              _filtros(context),
              const SizedBox(height: 14),

              // KPIs
              _kpisHeaderWith(ordens),
              const SizedBox(height: 16),

              // Lista de Ordens
              if (ordens.isEmpty)
                _empty()
              else
                ...ordens.map((ordem) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ordemCard(ordem),
                    )),
            ],
          );
        },
      ),
    );
  }

  // ─── Filtros ───────────────────────────────────────────────────────────────

  Widget _filtros(BuildContext context) {
    final bitolas = FirestoreClient.bitolas.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return Flex(
          direction: isNarrow ? Axis.vertical : Axis.horizontal,
          children: [
            // Status
            Expanded(
              flex: isNarrow ? 0 : 3,
              child: AppDropDown<RelatorioOrdemFiltroStatus>(
                label: 'Status da OP',
                itens: RelatorioOrdemFiltroStatus.values,
                item: _filtroStatus,
                itemLabel: (e) => e.label,
                onSelect: (e) => setState(
                    () => _filtroStatus = e ?? RelatorioOrdemFiltroStatus.todas),
              ),
            ),
            SizedBox(width: isNarrow ? 0 : 10, height: isNarrow ? 10 : 0),
            // Bitola
            Expanded(
              flex: isNarrow ? 0 : 3,
              child: AppDropDown<BitolaModel?>(
                label: 'Bitola',
                itens: [null, ...bitolas],
                item: _bitola,
                itemLabel: (e) => e?.descricao ?? 'Todas as Bitolas',
                onSelect: (e) => setState(() => _bitola = e),
              ),
            ),
            SizedBox(width: isNarrow ? 0 : 10, height: isNarrow ? 10 : 0),
            // Período
            Expanded(
              flex: isNarrow ? 0 : 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selecionarPeriodo(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Row(children: [
                    Icon(Icons.date_range_outlined,
                        size: 16, color: AppColors.primaryMain),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _periodo != null
                            ? '${_periodo!.start.ddMMyyyy()} → ${_periodo!.end.ddMMyyyy()}'
                            : 'Período: Todos',
                        style: AppCss.minimumRegular.setColor(
                          _periodo != null
                              ? const Color(0xFF1E293B)
                              : Colors.grey[500]!,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_periodo != null)
                      GestureDetector(
                        onTap: () => setState(() => _periodo = null),
                        child:
                            Icon(Icons.close, size: 14, color: Colors.grey[400]),
                      ),
                  ]),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _selecionarPeriodo(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _periodo,
    );
    if (range != null) setState(() => _periodo = range);
  }

  Widget _kpisHeaderWith(List<OrdemModel> ordens) {
    final tm = _tempoMedioDe(ordens);
    final tmStr = tm == Duration.zero
        ? '—'
        : _duracao(DateTime.now(), DateTime.now().add(tm));

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 650;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _kpiCard(
            Icons.check_circle_outline,
            '${ordens.length}',
            'Ordens Listadas',
            const Color(0xFF10B981),
            isNarrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
          ),
          _kpiCard(
            Icons.scale_outlined,
            _totalKgDe(ordens).toKg(),
            'Volume Filtrado',
            AppColors.primaryMain,
            isNarrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
          ),
          _kpiCard(
            Icons.timer_outlined,
            tmStr,
            'Tempo Médio / OP',
            const Color(0xFFD97706),
            isNarrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3,
          ),
        ],
      );
    });
  }

  Widget _kpiCard(IconData icon, String valor, String label, Color cor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: cor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppCss.minimumRegular
                      .setSize(10)
                      .setColor(const Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(valor,
                  style: AppCss.mediumBold
                      .setSize(15)
                      .setColor(const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────────────────

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Nenhuma ordem de produção encontrada',
              style: AppCss.mediumBold
                  .setSize(15)
                  .setColor(const Color(0xFF334155))),
          const SizedBox(height: 4),
          Text('Verifique os filtros de status, bitola ou intervalo de datas.',
              style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
          if (_periodo != null || _bitola != null || _filtroStatus != RelatorioOrdemFiltroStatus.todas)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                  elevation: 0,
                ),
                onPressed: () => setState(() {
                  _periodo = null;
                  _bitola = null;
                  _filtroStatus = RelatorioOrdemFiltroStatus.todas;
                }),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Limpar todos os filtros'),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Card de Ordem ────────────────────────────────────────────────────────

  Widget _ordemCard(OrdemModel ordem) {
    final inicio = _ordemInicio(ordem);
    final fim = _ordemFim(ordem);
    final dur = _duracao(inicio, fim);
    final expandido = _expandidoId == ordem.id;
    final totalKg = ordem.qtdeTotal;

    // Frações de progresso para a mini-barra
    final prontoKg = ordem.qtdePronto();
    final produzindoKg = ordem.qtdeProduzindo();
    final aguardandoKg = (totalKg - prontoKg - produzindoKg).clamp(0.0, totalKg);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expandido
              ? AppColors.primaryMain.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho clicável
          InkWell(
            borderRadius: expandido
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: () => setState(() {
              _expandidoId = _expandidoId == ordem.id ? null : ordem.id;
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Ícone bitola
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          ordem.produto.descricaoReplaced,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryMain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(ordem.localizator,
                                style: AppCss.mediumBold
                                    .setSize(14)
                                    .setColor(const Color(0xFF0F172A))),
                            const SizedBox(width: 8),
                            if (ordem.isArchived)
                              _statusBadge('Arquivada', Colors.grey[700]!,
                                  Colors.grey[100]!, Colors.grey[300]!)
                            else if (ordem.status == PedidoBitolaStatus.pronto)
                              _statusBadge('Concluída', const Color(0xFF059669),
                                  const Color(0xFFECFDF5), const Color(0xFFA7F3D0))
                            else if (ordem.status == PedidoBitolaStatus.produzindo)
                              _statusBadge('Em Produção', const Color(0xFFD97706),
                                  const Color(0xFFFFFBEB), const Color(0xFFFDE68A))
                            else
                              _statusBadge('Aguardando', const Color(0xFF475569),
                                  const Color(0xFFF8FAFC), const Color(0xFFCBD5E1)),
                          ]),
                          const SizedBox(height: 2),
                          Text(
                            'Bitola ${ordem.produto.descricaoReplaced} mm · ${totalKg.toKg()} · ${ordem.produtos.length} pedidos',
                            style: AppCss.minimumRegular
                                .setSize(12)
                                .setColor(const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expandido
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Mini barra de progresso
                  if (totalKg > 0)
                    Container(
                      height: 5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Row(
                          children: [
                            if (prontoKg > 0)
                              Expanded(
                                flex: (prontoKg * 100).toInt(),
                                child: Container(color: const Color(0xFF10B981)),
                              ),
                            if (produzindoKg > 0)
                              Expanded(
                                flex: (produzindoKg * 100).toInt(),
                                child: Container(color: const Color(0xFFF59E0B)),
                              ),
                            if (aguardandoKg > 0)
                              Expanded(
                                flex: (aguardandoKg * 100).toInt(),
                                child: Container(color: const Color(0xFFE2E8F0)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Linha de tempo
                  _linhaTempoOrdem(ordem, inicio, fim, dur),
                ],
              ),
            ),
          ),
          // Detalhe dos pedidos (expansível)
          if (expandido) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...ordem.produtos.map((p) => _itemPedido(p, ordem)),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(
      String texto, Color corTexto, Color corFundo, Color corBorda) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: corBorda),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: corTexto,
        ),
      ),
    );
  }

  Widget _linhaTempoOrdem(
      OrdemModel ordem, DateTime? inicio, DateTime? fim, String dur) {
    final emProducao = ordem.status == PedidoBitolaStatus.produzindo;
    final aguardando = ordem.status == PedidoBitolaStatus.aguardandoProducao;

    final fimTexto = emProducao
        ? 'Em andamento'
        : aguardando
            ? 'Na fila'
            : _fmt(fim);
    final fimCor = emProducao
        ? const Color(0xFFD97706)
        : aguardando
            ? const Color(0xFF64748B)
            : const Color(0xFF059669);

    final duracaoTexto = emProducao && inicio != null
        ? _duracao(inicio, DateTime.now())
        : aguardando
            ? '—'
            : dur;

    return Row(children: [
      _tempoChip(
        Icons.play_arrow_rounded,
        _fmt(inicio),
        inicio != null ? const Color(0xFF2563EB) : Colors.grey[400]!,
        'Início',
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child:
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFCBD5E1)),
      ),
      _tempoChip(
        emProducao
            ? Icons.sync_rounded
            : aguardando
                ? Icons.schedule_rounded
                : Icons.stop_rounded,
        fimTexto,
        fimCor,
        'Fim',
      ),
      const SizedBox(width: 8),
      _tempoChip(
        Icons.timer_outlined,
        duracaoTexto,
        emProducao ? const Color(0xFFD97706) : const Color(0xFF475569),
        emProducao ? 'Decorrido' : 'Duração',
      ),
    ]);
  }

  Widget _tempoChip(IconData icon, String valor, Color cor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: cor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 12, color: cor),
              const SizedBox(width: 3),
              Text(label,
                  style: AppCss.minimumRegular
                      .setSize(10)
                      .setColor(Colors.grey[500]!)),
            ]),
            const SizedBox(height: 2),
            Text(valor,
                style: AppCss.minimumBold.setSize(11).setColor(cor),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ─── Item de Pedido ───────────────────────────────────────────────────────

  Widget _itemPedido(PedidoBitolaModel produto, OrdemModel ordem) {
    final inicio = _inicioProducao(produto);
    final fim = _fimProducao(produto);
    final dur = _duracao(inicio, fim);
    final status = produto.status.status;

    final emAndamento = status == PedidoBitolaStatus.produzindo;

    Color statusCor() {
      switch (status) {
        case PedidoBitolaStatus.pronto:
          return const Color(0xFF059669);
        case PedidoBitolaStatus.produzindo:
          return const Color(0xFFD97706);
        default:
          return const Color(0xFF94A3B8);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Tag do Localizador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              produto.pedido.localizador,
              style: AppCss.minimumBold
                  .setSize(11)
                  .setColor(const Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 10),

          // Nome do Cliente
          Expanded(
            flex: 3,
            child: Text(
              produto.pedido.cliente.nome,
              style: AppCss.minimumRegular
                  .setSize(12)
                  .setColor(const Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // Datas de Início e Fim
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Início
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      size: 13,
                      color: inicio != null
                          ? const Color(0xFF2563EB)
                          : Colors.grey[400]),
                  const SizedBox(width: 2),
                  Text(
                    inicio != null ? DateFormat('dd/MM HH:mm').format(inicio) : '—',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: inicio != null
                          ? const Color(0xFF334155)
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Fim
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    emAndamento ? Icons.sync_rounded : Icons.stop_rounded,
                    size: 13,
                    color: emAndamento
                        ? const Color(0xFFD97706)
                        : fim != null
                            ? const Color(0xFF059669)
                            : Colors.grey[400],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    emAndamento
                        ? 'Em andamento'
                        : fim != null
                            ? DateFormat('dd/MM HH:mm').format(fim)
                            : '—',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: emAndamento
                          ? const Color(0xFFD97706)
                          : fim != null
                              ? const Color(0xFF334155)
                              : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Peso
          Text(
            produto.qtde.toKg(),
            style: AppCss.minimumBold
                .setSize(12)
                .setColor(const Color(0xFF0F172A)),
          ),
          const SizedBox(width: 10),

          // Badge de Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusCor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusCor(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Duração
          SizedBox(
            width: 50,
            child: Text(
              emAndamento && inicio != null
                  ? _duracao(inicio, DateTime.now())
                  : dur,
              textAlign: TextAlign.right,
              style: AppCss.minimumRegular
                  .setSize(11)
                  .setColor(const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}
