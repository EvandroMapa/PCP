import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';

import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:flutter/material.dart';

/// Página fullscreen para o operador controlar produção por OS/Elemento.
/// Mostra um grid de cards no estilo industrial.
class OrdemPedidoElementosPage extends StatefulWidget {
  final PedidoProdutoModel produto;
  final OrdemModel ordem;

  const OrdemPedidoElementosPage({
    super.key,
    required this.produto,
    required this.ordem,
  });

  @override
  State<OrdemPedidoElementosPage> createState() =>
      _OrdemPedidoElementosPageState();
}

class _OrdemPedidoElementosPageState extends State<OrdemPedidoElementosPage> {
  List<ElementoModel> _elementos = [];
  List<_PosicaoItem> _posicoes = [];
  bool _isLoading = true;

  String get _ordemProdutoId => widget.ordem.produto.id;

  @override
  void initState() {
    super.initState();
    _fetchElementos();
  }

  Future<void> _fetchElementos() async {
    try {
      // Busca elementos do pedido via AppSupabaseClient (cache reativo)
      final all = AppSupabaseClient.elementos.data
          .where((e) => e.pedidoId == widget.produto.pedidoId)
          .toList();

      if (all.isNotEmpty) {
        all.sort((a, b) =>
            a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
        if (mounted) {
          setState(() {
            _elementos = all;
            _buildPosicoes();
            _isLoading = false;
          });
        }
      } else {
        // Fallback: buscar do Supabase diretamente
        final raw = await SupabaseService.client
            .from('elementos')
            .select()
            .eq('pedido_id', widget.produto.pedidoId);

        final List<ElementoModel> fetched = [];
        for (final e in raw) {
          final posRaw = await SupabaseService.client
              .from('elemento_posicoes')
              .select()
              .eq('elemento_id', e['id'].toString());
          fetched.add(ElementoModel.fromSupabaseMap(e,
              posicoesRaw: List<Map<String, dynamic>>.from(posRaw)));
        }
        fetched.sort((a, b) =>
            a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
        if (mounted) {
          setState(() {
            _elementos = fetched;
            _buildPosicoes();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      log('Erro ao buscar elementos do pedido: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Constrói lista flat de posições filtradas pela bitola da ordem
  void _buildPosicoes() {
    _posicoes = [];
    for (final elemento in _elementos) {
      for (final posicao in elemento.posicoes) {
        if (posicao.produtoId == _ordemProdutoId) {
          _posicoes.add(_PosicaoItem(elemento: elemento, posicao: posicao));
        }
      }
    }
    _posicoes.sort((a, b) {
      final numA = int.tryParse(a.posicao.numeroOs) ?? 0;
      final numB = int.tryParse(b.posicao.numeroOs) ?? 0;
      return numA.compareTo(numB);
    });
  }

  Future<void> _onPosicaoTap(_PosicaoItem item) async {
    final newStatus = await _showStatusPicker(item);
    if (newStatus == null || newStatus == item.posicao.status) return;

    // Atualiza status da posição no Supabase
    item.posicao.status = newStatus;
    await SupabaseService.client
        .from('elemento_posicoes')
        .update({'status': newStatus.name})
        .eq('id', item.posicao.id);

    await _fetchElementos();
    await _checkAutoUpdatePedidoStatus();
  }

  Future<PosicaoStatus?> _showStatusPicker(_PosicaoItem item) async {
    return showDialog<PosicaoStatus>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ALTERAR STATUS',
                style: AppCss.mediumBold.setSize(16).setColor(AppColors.primaryMain),
              ),
              const SizedBox(height: 6),
              Text(
                'OS - ${item.posicao.numeroOs}',
                style: AppCss.largeBold.setSize(20),
                textAlign: TextAlign.center,
              ),
              Text(
                item.posicao.nome,
                style: AppCss.mediumRegular.setSize(14).setColor(Colors.grey[600]!),
              ),
              const SizedBox(height: 20),
              ...PosicaoStatus.values.map((status) {
                final isActive = status == item.posicao.status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, status),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? status.color.withValues(alpha: 0.15)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? status.color
                              : Colors.grey[300]!,
                          width: isActive ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: status.color,
                            radius: 14,
                            child: isActive
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            status.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isActive
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCELAR',
                    style: AppCss.mediumBold
                        .setSize(14)
                        .setColor(Colors.grey[400]!)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Auto-update: verifica status de TODAS as posições desta bitola/pedido
  Future<void> _checkAutoUpdatePedidoStatus() async {
    if (_posicoes.isEmpty) return;

    final todosProntos = _posicoes.every((p) => p.posicao.status == PosicaoStatus.pronto);
    final algumProduzindo = _posicoes.any((p) => p.posicao.status == PosicaoStatus.produzindo);

    PedidoProdutoStatus? novoStatus;

    if (todosProntos &&
        widget.produto.status.status != PedidoProdutoStatus.pronto) {
      novoStatus = PedidoProdutoStatus.pronto;
    } else if (algumProduzindo &&
        widget.produto.status.status ==
            PedidoProdutoStatus.aguardandoProducao) {
      novoStatus = PedidoProdutoStatus.produzindo;
    } else if (!algumProduzindo &&
        !todosProntos &&
        widget.produto.status.status == PedidoProdutoStatus.produzindo) {
      novoStatus = PedidoProdutoStatus.aguardandoProducao;
    }

    if (novoStatus != null) {
      await FirestoreClient.pedidos
          .updateProdutoStatus(widget.produto, novoStatus);
      await FirestoreClient.ordens.fetch();
      ordemCtrl.setOrdem(ordemCtrl.getOrdemById(widget.ordem.id));
    }
  }

  void _showDebugDialog(BuildContext context) {
    final pedido = widget.produto.pedido;
    final produto = widget.produto;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text('DEBUG — Dados do Pedido/Elementos',
                        style: AppCss.mediumBold.setSize(14).setColor(Colors.white)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _debugSection('FILTRO: Ordem ${widget.ordem.localizator} · Bitola: ${widget.ordem.produto.descricao} (${widget.ordem.produto.id})', []),
                      const SizedBox(height: 12),
                      for (int i = 0; i < _elementos.length; i++) ...[
                        for (int j = 0; j < _elementos[i].posicoes.length; j++)
                          if (_elementos[i].posicoes[j].produtoId == widget.ordem.produto.id)
                            _debugSection('${_elementos[i].nome} · Posição [${j}]', [
                              ['elemento_posicoes', 'id', _elementos[i].posicoes[j].id],
                              ['elemento_posicoes', 'elemento_id', _elementos[i].posicoes[j].elementoId],
                              ['elemento_posicoes', 'nome', _elementos[i].posicoes[j].nome],
                              ['elemento_posicoes', 'numero_os', _elementos[i].posicoes[j].numeroOs],
                              ['elemento_posicoes', 'produto_id', _elementos[i].posicoes[j].produtoId],
                              ['elemento_posicoes', 'produto.descricao', _elementos[i].posicoes[j].produto?.descricao ?? '(null)'],
                              ['elemento_posicoes', 'peso_kg', _elementos[i].posicoes[j].pesoKg.toStringAsFixed(3)],
                              ['elemento_posicoes', 'qtde', _elementos[i].posicoes[j].qtde.toString()],
                              ['elementos', 'elemento.nome', _elementos[i].nome],
                              ['elementos', 'elemento.qtde', _elementos[i].qtde.toString()],
                              ['elementos', 'elemento.status', _elementos[i].status.name],
                            ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugSection(String title, List<List<String>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.grey[200],
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Tabela',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Campo',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Valor',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            ...rows.map((row) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(row[0],
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontFamily: 'monospace')),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(row[1],
                          style: const TextStyle(
                              fontSize: 10, fontFamily: 'monospace')),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: SelectableText(row[2],
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                              fontFamily: 'monospace')),
                    ),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.produto.pedido;
    final tipoLabel = pedido.tipo == PedidoTipo.cda ? 'CDA' : 'CD';

    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pedido.localizador} · $tipoLabel',
                    style: AppCss.largeBold.setColor(Colors.white).setSize(18),
                  ),
                  Text(
                    '${widget.produto.cliente.nome} · ${widget.ordem.localizator}',
                    style: AppCss.minimumRegular
                        .setColor(Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Badge resumo — clicável para debug
            InkWell(
              onTap: () => _showDebugDialog(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bug_report_outlined,
                        size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${_posicoes.length} OS',
                      style: AppCss.minimumBold
                          .setSize(12)
                          .setColor(Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Carregando elementos...',
                      style: AppCss.mediumRegular),
                ],
              ),
            )
          : _posicoes.isEmpty
              ? const EmptyData(
                  message: 'Nenhuma posição encontrada para esta bitola.')
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 210,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _posicoes.length,
                  itemBuilder: (context, index) {
                    final item = _posicoes[index];
                    return _ElementoOSCard(
                      key: ValueKey('${item.elemento.id}_${item.posicao.id}'),
                      item: item,
                      onTap: () => _onPosicaoTap(item),
                    );
                  },
                ),
    );
  }
}

// ─── MODELO AUXILIAR: par elemento + posição ─────────────────────────────────

class _PosicaoItem {
  final ElementoModel elemento;
  final ElementoPosicaoModel posicao;

  const _PosicaoItem({required this.elemento, required this.posicao});
}

// ─── CARD ESTILO INDUSTRIAL (POR POSIÇÃO) ────────────────────────────────────

class _ElementoOSCard extends StatelessWidget {
  final _PosicaoItem item;
  final VoidCallback onTap;

  const _ElementoOSCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  ElementoModel get elemento => item.elemento;
  ElementoPosicaoModel get posicao => item.posicao;

  String _statusLabel(PosicaoStatus status) {
    switch (status) {
      case PosicaoStatus.aguardando:
        return 'AGUARDANDO';
      case PosicaoStatus.produzindo:
        return 'PRODUZINDO';
      case PosicaoStatus.pronto:
        return 'PRONTO';
    }
  }

  Color _statusTextColor(PosicaoStatus status) {
    switch (status) {
      case PosicaoStatus.aguardando:
        return Colors.black87;
      case PosicaoStatus.produzindo:
        return Colors.orange[800]!;
      case PosicaoStatus.pronto:
        return Colors.green[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = posicao.status;
    final statusColor = status.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.4),
            width: status == PosicaoStatus.produzindo ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── TARJA: NÚMERO DA OS ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Text(
                'OS - ${posicao.numeroOs}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ─── NOME DO ELEMENTO (X QTDE) ───
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${elemento.nome}${elemento.qtde > 1 ? ' (X ${elemento.qtde})' : ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ─── STATUS ───
            Expanded(
              child: Center(
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _statusTextColor(status),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

            // ─── RODAPÉ: POSIÇÃO / QTDE / PESO ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _footerItem('POSIÇÃO', posicao.nome),
                  _footerItem('QTDE', '${posicao.qtde * elemento.qtde}'),
                  _footerItem('PESO', (posicao.pesoKg * elemento.qtde).toKg()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
