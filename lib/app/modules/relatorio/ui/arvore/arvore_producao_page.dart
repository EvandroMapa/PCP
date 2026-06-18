import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_status_history_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ArvoreProducaoPage extends StatefulWidget {
  const ArvoreProducaoPage({super.key});

  @override
  State<ArvoreProducaoPage> createState() => _ArvoreProducaoPageState();
}

class _ArvoreProducaoPageState extends State<ArvoreProducaoPage> {
  PedidoModel? _pedidoSelecionado;
  List<ElementoModel> _elementos = [];
  Map<String, List<ElementoStatusHistoryModel>> _historicoElementos = {};
  bool _carregando = false;
  final TextEditingController _buscaCtrl = TextEditingController();
  List<PedidoModel> _sugestoes = [];
  bool _mostrarSugestoes = false;
  final FocusNode _buscaFocus = FocusNode();

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _buscaFocus.dispose();
    super.dispose();
  }

  void _filtrarSugestoes(String texto) {
    if (texto.isEmpty) {
      setState(() {
        _sugestoes = [];
        _mostrarSugestoes = false;
      });
      return;
    }
    final lower = texto.toLowerCase();
    final pedidos = [
      ...FirestoreClient.pedidos.data,
    ];
    final filtrados = pedidos
        .where((p) =>
            p.localizador.toLowerCase().contains(lower) ||
            p.cliente.nome.toLowerCase().contains(lower))
        .take(10)
        .toList();
    setState(() {
      _sugestoes = filtrados;
      _mostrarSugestoes = filtrados.isNotEmpty;
    });
  }

  Future<void> _selecionarPedido(PedidoModel pedido) async {
    setState(() {
      _pedidoSelecionado = pedido;
      _carregando = true;
      _mostrarSugestoes = false;
      _buscaCtrl.text = pedido.localizador;
    });
    _buscaFocus.unfocus();

    // Buscar elementos do pedido
    final elementosData = AppSupabaseClient.elementos.data
        .where((e) => e.pedidoId == pedido.id)
        .toList();

    // Buscar histórico de status dos elementos (tabela pode não existir ainda)
    final Map<String, List<ElementoStatusHistoryModel>> historico = {};
    try {
      final raw = await SupabaseService.client
          .from('elemento_status_history')
          .select()
          .eq('pedido_id', pedido.id)
          .order('created_at', ascending: true);
      for (final r in raw) {
        final h = ElementoStatusHistoryModel.fromSupabaseMap(r);
        historico.putIfAbsent(h.elementoId, () => []).add(h);
      }
    } catch (e) {
      debugPrint('Histórico de elementos indisponível: $e');
    }

    if (!mounted) return;
    setState(() {
      _elementos = elementosData
        ..sort((a, b) =>
            a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      _historicoElementos = historico;
      _carregando = false;
    });
  }

  // ─── Helpers de datas para Bitolas ─────────────────────────────────

  DateTime? _bitolaInicio(List<PedidoBitolaStatusModel> statusess) {
    final produzindo = statusess
        .where((s) => s.status == PedidoBitolaStatus.produzindo)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (produzindo.isNotEmpty) return produzindo.first.createdAt;
    final pronto = statusess
        .where((s) => s.status == PedidoBitolaStatus.pronto)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pronto.isEmpty ? null : pronto.first.createdAt;
  }

  DateTime? _bitolaFim(List<PedidoBitolaStatusModel> statusess) {
    final pronto = statusess
        .where((s) => s.status == PedidoBitolaStatus.pronto)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pronto.isEmpty ? null : pronto.last.createdAt;
  }

  // ─── Helpers de datas para Elementos ───────────────────────────────

  DateTime? _elementoInicio(String elementoId) {
    final lista = _historicoElementos[elementoId];
    if (lista == null || lista.isEmpty) return null;
    final armando =
        lista.where((h) => h.status == ElementoStatus.armando).toList();
    return armando.isEmpty ? null : armando.first.createdAt;
  }

  DateTime? _elementoFim(String elementoId) {
    final lista = _historicoElementos[elementoId];
    if (lista == null || lista.isEmpty) return null;
    final pronto =
        lista.where((h) => h.status == ElementoStatus.pronto).toList();
    return pronto.isEmpty ? null : pronto.last.createdAt;
  }

  String _fmt(DateTime? d) =>
      d != null ? DateFormat("dd/MM/yy HH:mm").format(d) : '—';

  String _duracao(DateTime? inicio, DateTime? fim) {
    if (inicio == null || fim == null) return '—';
    final d = fim.difference(inicio);
    if (d.inDays >= 1) {
      return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}min';
    }
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Árvore de Produção',
                style: AppCss.largeBold.setSize(20)),
          ),
        ),
        // Busca
        _campoBusca(),
        const Divider(height: 1),
        // Conteúdo
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _pedidoSelecionado == null
                  ? _vazio()
                  : _arvore(),
        ),
      ],
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscaCtrl,
            focusNode: _buscaFocus,
            decoration: InputDecoration(
              hintText: 'Buscar pedido por localizador ou cliente...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _buscaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _buscaCtrl.clear();
                        setState(() {
                          _pedidoSelecionado = null;
                          _sugestoes = [];
                          _mostrarSugestoes = false;
                          _elementos = [];
                          _historicoElementos = {};
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: _filtrarSugestoes,
          ),
          if (_mostrarSugestoes)
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _sugestoes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _sugestoes[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.localizador,
                        style: AppCss.mediumBold.setSize(13)),
                    subtitle: Text(
                        '${p.cliente.nome} · ${p.obra.descricao}',
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[600]!)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        p.status.label,
                        style: AppCss.minimumBold
                            .setSize(10)
                            .setColor(p.status.color),
                      ),
                    ),
                    onTap: () => _selecionarPedido(p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _vazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Selecione um pedido para ver a árvore de produção',
            style:
                AppCss.mediumRegular.setColor(Colors.grey[500]!),
          ),
        ],
      ),
    );
  }

  Widget _arvore() {
    final pedido = _pedidoSelecionado!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header do pedido
        _headerPedido(pedido),
        const SizedBox(height: 16),

        // Seção Bitolas (CD)
        if (pedido.produtos.isNotEmpty) ...[
          _secaoTitulo('Bitolas (Produção CD)',
              Icons.straighten, pedido.produtos.length),
          const SizedBox(height: 8),
          ...pedido.produtos.map(_cardBitola),
          const SizedBox(height: 20),
        ],

        // Seção Elementos (Armação)
        if (_elementos.isNotEmpty) ...[
          _secaoTitulo('Elementos (Armação)',
              Icons.construction, _elementos.length),
          const SizedBox(height: 8),
          ..._elementos.map(_cardElemento),
        ],

        if (pedido.produtos.isEmpty && _elementos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Nenhum produto ou elemento neste pedido.',
                style: AppCss.mediumRegular
                    .setColor(Colors.grey[500]!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerPedido(PedidoModel pedido) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primaryMain.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_outlined,
                color: AppColors.primaryMain, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.localizador,
                    style: AppCss.largeBold.setSize(16)),
                const SizedBox(height: 2),
                Text(
                  '${pedido.cliente.nome} · ${pedido.obra.descricao}',
                  style: AppCss.minimumRegular
                      .setSize(12)
                      .setColor(Colors.grey[600]!),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pedido.pesoTotal.toKg(),
              style: AppCss.mediumBold
                  .setSize(13)
                  .setColor(AppColors.primaryMain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoTitulo(String titulo, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(titulo, style: AppCss.mediumBold.setSize(14)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: AppCss.minimumBold
                  .setSize(11)
                  .setColor(Colors.grey[700]!)),
        ),
      ],
    );
  }

  Widget _cardBitola(PedidoBitolaModel produto) {
    final inicio = _bitolaInicio(produto.statusess);
    final fim = _bitolaFim(produto.statusess);
    final PedidoBitolaStatus status = produto.status.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: status.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          // Barra lateral colorida
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(produto.produto.descricao,
                        style: AppCss.mediumBold.setSize(13)),
                    const SizedBox(width: 8),
                    _statusBadge(status.label, status.color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(produto.qtde.toKg(),
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[600]!)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.play_arrow, size: 12,
                        color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(_fmt(inicio),
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[700]!)),
                    const SizedBox(width: 12),
                    Icon(Icons.stop, size: 12,
                        color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(_fmt(fim),
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[700]!)),
                    if (inicio != null && fim != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined, size: 12,
                          color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(_duracao(inicio, fim),
                          style: AppCss.minimumBold
                              .setSize(11)
                              .setColor(Colors.blue[600]!)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardElemento(ElementoModel elemento) {
    final inicio = _elementoInicio(elemento.id);
    final fim = _elementoFim(elemento.id);
    final historico = _historicoElementos[elemento.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: elemento.status.color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: elemento.status.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(elemento.nome,
                            style: AppCss.mediumBold.setSize(13)),
                        if (elemento.qtde > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('x${elemento.qtde}',
                                style: AppCss.minimumBold
                                    .setSize(10)
                                    .setColor(Colors.grey[700]!)),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _statusBadge(
                            elemento.status.label, elemento.status.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(elemento.pesoTotal.toKg(),
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[600]!)),
                  ],
                ),
              ),
              if (elemento.qtde > 1 && elemento.qtdePronto > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                      '${elemento.qtdePronto}/${elemento.qtde}',
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(Colors.green[700]!)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Datas
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Icon(Icons.play_arrow, size: 12,
                    color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(_fmt(inicio),
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[700]!)),
                const SizedBox(width: 12),
                Icon(Icons.stop, size: 12,
                    color: Colors.red[400]),
                const SizedBox(width: 4),
                Text(_fmt(fim),
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[700]!)),
                if (inicio != null && fim != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.timer_outlined, size: 12,
                      color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text(_duracao(inicio, fim),
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(Colors.blue[600]!)),
                ],
              ],
            ),
          ),

          // Posições
          if (elemento.posicoes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: elemento.posicoes.map((pos) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: pos.status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${pos.nome} · ${pos.produto?.descricao ?? "—"} · ${pos.pesoKg.toKg()}',
                            style: AppCss.minimumRegular
                                .setSize(11)
                                .setColor(Colors.grey[600]!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Histórico timeline
          if (historico.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Histórico de Status',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(Colors.grey[600]!)),
                children: historico.map((h) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: h.status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${h.status.label} — ${_fmt(h.createdAt)}',
                          style: AppCss.minimumRegular
                              .setSize(11)
                              .setColor(Colors.grey[700]!),
                        ),
                        if (h.qtdePronto > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${h.qtdePronto} pç)',
                            style: AppCss.minimumRegular
                                .setSize(10)
                                .setColor(Colors.grey[500]!),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppCss.minimumBold.setSize(9).setColor(color),
      ),
    );
  }
}
