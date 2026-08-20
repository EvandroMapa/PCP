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

    // Buscar histórico de status dos elementos
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
        // Header e Campo de Busca
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Árvore de Produção',
                  style: AppCss.largeBold.setSize(22).setColor(const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text('Rastreabilidade completa do pedido: insumos de Corte & Dobra e Armação',
                  style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
              const SizedBox(height: 12),
              _campoBusca(),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _buscaCtrl,
            focusNode: _buscaFocus,
            style: AppCss.minimumBold.setSize(13).setColor(const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'Digite o localizador do pedido ou nome do cliente...',
              hintStyle: AppCss.minimumRegular.setColor(Colors.grey[400]!),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: AppColors.primaryMain),
              suffixIcon: _buscaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
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
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onChanged: _filtrarSugestoes,
          ),
        ),
        if (_mostrarSugestoes)
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _sugestoes.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (_, i) {
                  final p = _sugestoes[i];
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.localizador,
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(AppColors.primaryMain),
                      ),
                    ),
                    title: Text(p.cliente.nome,
                        style: AppCss.mediumBold
                            .setSize(13)
                            .setColor(const Color(0xFF1E293B))),
                    subtitle: Text(
                        '${p.obra.descricao} · ${p.pesoTotal.toKg()}',
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[500]!)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.status.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: p.status.color,
                        ),
                      ),
                    ),
                    onTap: () => _selecionarPedido(p),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _vazio() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.account_tree_outlined,
                  size: 32, color: AppColors.primaryMain),
            ),
            const SizedBox(height: 16),
            Text(
              'Rastreie um Pedido na Árvore de Produção',
              style: AppCss.mediumBold
                  .setSize(16)
                  .setColor(const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Utilize a barra de pesquisa acima para encontrar um pedido por localizador ou cliente.',
              textAlign: TextAlign.center,
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[500]!),
            ),
          ],
        ),
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
        const SizedBox(height: 20),

        // Seção Bitolas (CD)
        if (pedido.produtos.isNotEmpty) ...[
          _secaoTitulo('Corte & Dobra (Bitolas)',
              Icons.straighten_rounded, pedido.produtos.length, AppColors.primaryMain),
          const SizedBox(height: 10),
          ...pedido.produtos.map(_cardBitola),
          const SizedBox(height: 24),
        ],

        // Seção Elementos (Armação)
        if (_elementos.isNotEmpty) ...[
          _secaoTitulo('Armação (Elementos Estruturais)',
              Icons.construction_rounded, _elementos.length, const Color(0xFF0D9488)),
          const SizedBox(height: 10),
          ..._elementos.map(_cardElemento),
        ],

        if (pedido.produtos.isEmpty && _elementos.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'Nenhum produto de corte e dobra ou elemento de armação encontrado para este pedido.',
                style: AppCss.mediumRegular.setColor(Colors.grey[500]!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerPedido(PedidoModel pedido) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_outlined,
                color: AppColors.primaryMain, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pedido.localizador,
                        style: AppCss.minimumBold
                            .setSize(12)
                            .setColor(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pedido.status.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pedido.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pedido.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pedido.cliente.nome} · ${pedido.obra.descricao}',
                  style: AppCss.minimumRegular
                      .setSize(12)
                      .setColor(const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Volume Total',
                    style: AppCss.minimumRegular
                        .setSize(9)
                        .setColor(Colors.grey[500]!)),
                Text(
                  pedido.pesoTotal.toKg(),
                  style: AppCss.mediumBold
                      .setSize(14)
                      .setColor(AppColors.primaryMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoTitulo(String titulo, IconData icon, int count, Color cor) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: cor),
        ),
        const SizedBox(width: 8),
        Text(titulo,
            style: AppCss.mediumBold.setSize(14).setColor(const Color(0xFF0F172A))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: AppCss.minimumBold
                  .setSize(10)
                  .setColor(const Color(0xFF64748B))),
        ),
      ],
    );
  }

  Widget _cardBitola(PedidoBitolaModel produto) {
    final inicio = _bitolaInicio(produto.statusess);
    final fim = _bitolaFim(produto.statusess);
    final dur = _duracao(inicio, fim);
    final PedidoBitolaStatus status = produto.status.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone bitola
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                produto.produto.descricaoReplaced,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: status.color,
                ),
              ),
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
                    Text('Bitola ${produto.produto.descricaoReplaced} mm',
                        style: AppCss.mediumBold
                            .setSize(13)
                            .setColor(const Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    _statusBadge(status.label, status.color),
                    const Spacer(),
                    Text(produto.qtde.toKg(),
                        style: AppCss.mediumBold
                            .setSize(13)
                            .setColor(const Color(0xFF1E293B))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _timelineChip(Icons.play_arrow_rounded, _fmt(inicio),
                        const Color(0xFF2563EB), 'Início'),
                    const SizedBox(width: 12),
                    _timelineChip(Icons.stop_rounded, _fmt(fim),
                        const Color(0xFF059669), 'Fim'),
                    if (inicio != null && fim != null) ...[
                      const SizedBox(width: 12),
                      _timelineChip(Icons.timer_outlined, dur,
                          const Color(0xFFD97706), 'Duração'),
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
    final dur = _duracao(inicio, fim);
    final historico = _historicoElementos[elemento.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Elemento
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: elemento.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.hub_outlined,
                    size: 18, color: elemento.status.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(elemento.nome,
                            style: AppCss.mediumBold
                                .setSize(13)
                                .setColor(const Color(0xFF0F172A))),
                        if (elemento.qtde > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('x${elemento.qtde}',
                                style: AppCss.minimumBold
                                    .setSize(10)
                                    .setColor(const Color(0xFF475569))),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _statusBadge(
                            elemento.status.label, elemento.status.color),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(elemento.pesoTotal.toKg(),
                        style: AppCss.minimumRegular
                            .setSize(11)
                            .setColor(Colors.grey[600]!)),
                  ],
                ),
              ),
              if (elemento.qtde > 1 && elemento.qtdePronto > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text('${elemento.qtdePronto}/${elemento.qtde} prontas',
                      style: AppCss.minimumBold
                          .setSize(10)
                          .setColor(const Color(0xFF059669))),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Datas
          Row(
            children: [
              _timelineChip(Icons.play_arrow_rounded, _fmt(inicio),
                  const Color(0xFF2563EB), 'Início'),
              const SizedBox(width: 12),
              _timelineChip(Icons.stop_rounded, _fmt(fim),
                  const Color(0xFF059669), 'Fim'),
              if (inicio != null && fim != null) ...[
                const SizedBox(width: 12),
                _timelineChip(Icons.timer_outlined, dur,
                    const Color(0xFFD97706), 'Duração'),
              ],
            ],
          ),

          // Posições
          if (elemento.posicoes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: elemento.posicoes.map((pos) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: pos.status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${pos.nome} · ${pos.produto?.descricao ?? "—"} · ${pos.pesoKg.toKg()}',
                            style: AppCss.minimumRegular
                                .setSize(11)
                                .setColor(const Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: pos.status.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pos.status.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: pos.status.color,
                            ),
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
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.symmetric(vertical: 4),
                dense: true,
                title: Text('Ver Histórico de Status',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(const Color(0xFF64748B))),
                children: historico.map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
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
                              .setColor(const Color(0xFF334155)),
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

  Widget _timelineChip(IconData icon, String valor, Color cor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cor),
        const SizedBox(width: 3),
        Text(
          '$label: ',
          style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[500]!),
        ),
        Text(
          valor,
          style: AppCss.minimumBold.setSize(11).setColor(cor),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
