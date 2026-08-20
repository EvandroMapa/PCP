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
  // Primeiro: busca o status 'produzindo'
  final produzindo = p.statusess
      .where((s) => s.status == PedidoBitolaStatus.produzindo)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (produzindo.isNotEmpty) return produzindo.first.createdAt;

  // Fallback: produto foi marcado direto como 'pronto' — usa essa data como início
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
  // fallback: último "pronto" dentre todos os produtos
  final datas = o.produtos
      .map(_fimProducao)
      .whereType<DateTime>()
      .toList()
    ..sort();
  if (datas.isNotEmpty) return datas.last;
  // fallback final: updatedAt da ordem (para arquivadas sem status de pronto)
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
    // Carrega ordens arquivadas (ficam em stream separado)
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
            PopupMenuItem(
              value: RelatorioOrdensPdfExportarTipo.resumido,
              child: Row(children: [
                const Icon(Icons.description_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('PDF Resumido'),
              ]),
            ),
            PopupMenuItem(
              value: RelatorioOrdensPdfExportarTipo.completo,
              child: Row(children: [
                const Icon(Icons.description, size: 18),
                const SizedBox(width: 8),
                const Text('PDF Detalhado'),
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
          // Combina não-arquivadas + arquivadas
          final todas = [
            ...FirestoreClient.ordens.data,
            ...FirestoreClient.ordens.ordensArquivadas,
          ];
          final ordens = _filtrarOrdens(todas);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ordens de Produção',
                      style: AppCss.largeBold.setSize(20)),
                ),
              ),
              _filtros(context),
              const Divider(height: 1),
              _kpisHeaderWith(ordens),
              const Divider(height: 1),
              Expanded(
                child: ordens.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: ordens.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ordemCard(ordens[i]),
                      ),
              ),
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // Status
          Expanded(
            child: AppDropDown<RelatorioOrdemFiltroStatus>(
              label: 'Status',
              itens: RelatorioOrdemFiltroStatus.values,
              item: _filtroStatus,
              itemLabel: (e) => e.label,
              onSelect: (e) => setState(
                  () => _filtroStatus = e ?? RelatorioOrdemFiltroStatus.todas),
            ),
          ),
          const SizedBox(width: 10),
          // Bitola
          Expanded(
            child: AppDropDown<BitolaModel?>(
              label: 'Bitola',
              itens: [null, ...bitolas],
              item: _bitola,
              itemLabel: (e) => e?.descricao ?? 'Todas',
              onSelect: (e) => setState(() => _bitola = e),
            ),
          ),
          const SizedBox(width: 10),
          // Período
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _selecionarPeriodo(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Row(children: [
                  Icon(Icons.date_range_outlined,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _periodo != null
                          ? '${_periodo!.start.ddMMyyyy()} → ${_periodo!.end.ddMMyyyy()}'
                          : 'Período: todos',
                      style: AppCss.minimumRegular.setColor(
                        _periodo != null
                            ? AppColors.primaryMain
                            : Colors.grey[500]!,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_periodo != null)
                    GestureDetector(
                      onTap: () => setState(() => _periodo = null),
                      child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(children: [
        _kpi(
          Icons.check_circle_outline,
          '${ordens.length}',
          'Ordens',
          Colors.green[700]!,
        ),
        const SizedBox(width: 8),
        _kpi(
          Icons.scale_outlined,
          _totalKgDe(ordens).toKg(),
          'Total Produzido',
          Colors.blue[700]!,
        ),
        const SizedBox(width: 8),
        _kpi(
          Icons.timer_outlined,
          tmStr,
          'Tempo Médio/Ordem',
          Colors.orange[700]!,
        ),
      ]),
    );
  }

  Widget _kpi(IconData icon, String valor, String label, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: cor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(valor,
                      style: AppCss.minimumBold.setColor(cor),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: AppCss.minimumRegular
                          .setSize(9)
                          .setColor(Colors.grey[400]!)),
                ]),
          ),
        ]),
      ),
    );
  }

  // ─── Empty ────────────────────────────────────────────────────────────────

  Widget _empty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('Nenhuma ordem produzida encontrada',
            style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
        if (_periodo != null || _bitola != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              onPressed: () => setState(() {
                _periodo = null;
                _bitola = null;
              }),
              child: const Text('Limpar filtros'),
            ),
          ),
      ]),
    );
  }

  // ─── Card de Ordem ────────────────────────────────────────────────────────

  Widget _ordemCard(OrdemModel ordem) {
    final inicio = _ordemInicio(ordem);
    final fim = _ordemFim(ordem);
    final dur = _duracao(inicio, fim);
    final expandido = _expandidoId == ordem.id;
    final totalKg = ordem.qtdeTotal;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho clicável
          InkWell(
            borderRadius: expandido
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(Icons.settings_outlined,
                            size: 17, color: AppColors.primaryMain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(ordem.localizator,
                                  style: AppCss.mediumBold),
                              const SizedBox(width: 8),
                              if (ordem.isArchived)
                                _statusBadge('Arquivada', Colors.grey[700]!,
                                    Colors.grey[100]!, Colors.grey[300]!)
                              else if (ordem.status == PedidoBitolaStatus.pronto)
                                _statusBadge('Concluída', Colors.green[700]!,
                                    Colors.green[50]!, Colors.green[200]!)
                              else if (ordem.status == PedidoBitolaStatus.produzindo)
                                _statusBadge('Em Produção', Colors.orange[800]!,
                                    Colors.orange[50]!, Colors.orange[300]!)
                              else
                                _statusBadge('Aguardando', Colors.blueGrey[700]!,
                                    Colors.blueGrey[50]!, Colors.blueGrey[200]!),
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              'Bitola ${ordem.produto.descricaoReplaced}mm · ${totalKg.toKg()}',
                              style: AppCss.minimumRegular
                                  .setSize(13)
                                  .setColor(Colors.grey[600]!),
                            ),
                          ]),
                    ),
                    Icon(
                      expandido
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Linha de tempo
                  _linhaTempoOrdem(ordem, inicio, fim, dur),
                ],
              ),
            ),
          ),
          // Detalhe dos pedidos (expansível)
          if (expandido) ...[
            Divider(height: 1, color: Colors.grey[100]),
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
          fontSize: 11,
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
        ? Colors.orange[800]!
        : aguardando
            ? Colors.blueGrey[600]!
            : Colors.green[700]!;

    final duracaoTexto = emProducao && inicio != null
        ? _duracao(inicio, DateTime.now())
        : aguardando
            ? '—'
            : dur;

    return Row(children: [
      _tempoChip(
        Icons.play_arrow_rounded,
        _fmt(inicio),
        inicio != null ? Colors.blue[700]! : Colors.grey[400]!,
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
        emProducao ? Colors.orange[800]! : Colors.orange[700]!,
        emProducao ? 'Decorrido' : 'Duração',
      ),
    ]);
  }

  Widget _tempoChip(IconData icon, String valor, Color cor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
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
                style: AppCss.minimumBold.setSize(12).setColor(cor),
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

    Color statusCor() {
      switch (status) {
        case PedidoBitolaStatus.pronto:
          return Colors.green[700]!;
        case PedidoBitolaStatus.produzindo:
          return Colors.orange[700]!;
        default:
          return Colors.grey[400]!;
      }
    }

    bool mostrarNomePedido = true;
    try {
      mostrarNomePedido = !produto.pedido.localizador.contains('NOTFOUND');
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
        color: Colors.grey[50],
      ),
      child: Row(children: [
        // Status dot
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 10, top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusCor(),
          ),
        ),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mostrarNomePedido)
                  Text(
                    '${produto.pedido.localizador} · ${produto.cliente.nome}',
                    style: AppCss.minimumRegular
                        .setSize(13)
                        .copyWith(fontWeight: FontWeight.w600)
                        .setColor(Colors.grey[800]!),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Bitola ${produto.produto.descricaoReplaced}mm · ${produto.qtde.toKg()}',
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[600]!)
                      .setSize(12),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  _minichip(_fmt(inicio), Icons.play_arrow_rounded,
                      Colors.blue[600]!),
                  const SizedBox(width: 6),
                  _minichip(
                      _fmt(fim), Icons.stop_rounded, Colors.green[600]!),
                  const SizedBox(width: 6),
                  _minichip(
                      dur, Icons.timer_outlined, Colors.orange[700]!),
                ]),
              ]),
        ),
      ]),
    );
  }

  Widget _minichip(String valor, IconData icon, Color cor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: cor),
      const SizedBox(width: 3),
      Text(valor,
          style: AppCss.minimumRegular.setSize(12).setColor(Colors.grey[700]!)),
    ]);
  }
}
