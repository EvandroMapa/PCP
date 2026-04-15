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

    // Atualização instantânea na UI
    setState(() {
      item.posicao.status = newStatus;
    });

    // Atualiza também o cache global de elementos para os gráficos
    _updateGlobalElementosCache(item);

    try {
      // Persiste no Supabase
      await SupabaseService.client
          .from('elemento_posicoes')
          .update({'status': newStatus.name})
          .eq('id', item.posicao.id);

      // Sincroniza status do pedido/ordem
      await _checkAutoUpdatePedidoStatus();

      // Força re-emit do stream de ordens para atualizar gráficos na lista
      _notifyOrdensStream();
    } catch (e) {
      log('Erro ao atualizar status da posição: $e');
    }
  }

  /// Atualiza o cache global de AppSupabaseClient.elementos com o novo status da posição
  void _updateGlobalElementosCache(_PosicaoItem item) {
    final globalElementos = AppSupabaseClient.elementos.data;
    final idx = globalElementos.indexWhere((e) => e.id == item.elemento.id);
    if (idx != -1) {
      final posIdx = globalElementos[idx].posicoes.indexWhere((p) => p.id == item.posicao.id);
      if (posIdx != -1) {
        globalElementos[idx].posicoes[posIdx].status = item.posicao.status;
        // Re-emite o stream de elementos para que outros modules percebam
        AppSupabaseClient.elementos.dataStream.add(globalElementos);
      }
    }
  }

  /// Força re-emit dos streams de ordens para que gráficos recalculem
  void _notifyOrdensStream() {
    // Re-emite a mesma lista para forçar rebuild dos widgets que escutam
    FirestoreClient.ordens.ordensNaoArquivadasStream
        .add(FirestoreClient.ordens.ordensNaoArquivadas);
    // Força rebuild da lista de ordens (StreamOut<OrdemUtils> aninhado)
    ordemCtrl.utilsStream.update();
    // Também notifica o stream da ordem aberta
    if (ordemCtrl.ordemStream.controller.hasValue) {
      ordemCtrl.ordemStream.add(ordemCtrl.ordemStream.value);
    }
  }

  /// Verifica se uma transição de status é permitida
  bool _canTransition(PosicaoStatus target, PosicaoStatus current) {
    if (target == current) return false;

    // Se houver qualquer item PRONTO, ninguém mais pode voltar/ficar em AGUARDANDO
    final existeAlgumPronto =
        _posicoes.any((p) => p.posicao.status == PosicaoStatus.pronto);

    switch (target) {
      case PosicaoStatus.aguardando:
        // Bloqueia retorno a aguardando se houver algum item já pronto
        if (existeAlgumPronto) return false;
        // Pode voltar 1 etapa: apenas de produzindo
        return current == PosicaoStatus.produzindo;

      case PosicaoStatus.produzindo:
        // Pode avançar de aguardando OU voltar de pronto
        return current == PosicaoStatus.aguardando ||
            current == PosicaoStatus.pronto;

      case PosicaoStatus.pronto:
        // Só pode avançar de produzindo
        if (current != PosicaoStatus.produzindo) return false;
        // Só permite ficar Pronto se TODOS os outros já saíram do 'Aguardando'
        return _posicoes.every((p) => p.posicao.status != PosicaoStatus.aguardando);
    }
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
                final canSelect = isActive || _canTransition(status, item.posicao.status);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Opacity(
                    opacity: canSelect ? 1.0 : 0.3,
                    child: IgnorePointer(
                      ignoring: !canSelect,
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
                                    : !canSelect
                                        ? Icon(Icons.lock,
                                            size: 12, color: Colors.grey[400])
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
                                      : canSelect
                                          ? Colors.grey[600]
                                          : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
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
  /// Auto-update: sincroniza status da ordem/pedido com as posições
  Future<void> _checkAutoUpdatePedidoStatus() async {
    if (_posicoes.isEmpty) return;

    final todosAguardando =
        _posicoes.every((p) => p.posicao.status == PosicaoStatus.aguardando);
    final todosProntos =
        _posicoes.every((p) => p.posicao.status == PosicaoStatus.pronto);

    PedidoProdutoStatus novoStatus;

    if (todosAguardando) {
      novoStatus = PedidoProdutoStatus.aguardandoProducao;
    } else if (todosProntos) {
      novoStatus = PedidoProdutoStatus.pronto;
    } else {
      novoStatus = PedidoProdutoStatus.produzindo;
    }

    // Busca o status atual no Firestore para comparar corretamente
    final currentPedido =
        FirestoreClient.pedidos.getById(widget.produto.pedidoId);
    final currentProduto = currentPedido?.produtos
        .firstWhere((p) => p.id == widget.produto.id, orElse: () => widget.produto);

    if (currentProduto != null && novoStatus == currentProduto.status.status) {
      return;
    }

    // Atualiza no Firestore o status do item do pedido
    await FirestoreClient.pedidos
        .updateProdutoStatus(widget.produto, novoStatus);

    // Força atualização da lista de ordens para refletir nos indicadores laterais
    await FirestoreClient.ordens.fetch();
    final updatedOrdem = ordemCtrl.getOrdemById(widget.ordem.id);
    if (updatedOrdem != null) {
      ordemCtrl.setOrdem(updatedOrdem);
    }
  }

  /// Barra fixa de resumo de produção por status das posições
  Widget _buildResumoBar() {
    int qtdAg = 0, qtdProd = 0, qtdPronto = 0;
    double pesoAg = 0, pesoProd = 0, pesoPronto = 0;

    for (final item in _posicoes) {
      final peso = item.posicao.pesoKg * item.elemento.qtde;
      switch (item.posicao.status) {
        case PosicaoStatus.aguardando:
          qtdAg++;
          pesoAg += peso;
          break;
        case PosicaoStatus.produzindo:
          qtdProd++;
          pesoProd += peso;
          break;
        case PosicaoStatus.pronto:
          qtdPronto++;
          pesoPronto += peso;
          break;
      }
    }

    final total = _posicoes.length;
    final pesoTotal = pesoAg + pesoProd + pesoPronto;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _resumoItem(
            'AGUARDANDO',
            PosicaoStatus.aguardando,
            qtdAg,
            pesoAg,
            total,
            pesoTotal,
          ),
          const SizedBox(width: 10),
          _resumoItem(
            'PRODUZINDO',
            PosicaoStatus.produzindo,
            qtdProd,
            pesoProd,
            total,
            pesoTotal,
          ),
          const SizedBox(width: 10),
          _resumoItem(
            'PRONTO',
            PosicaoStatus.pronto,
            qtdPronto,
            pesoPronto,
            total,
            pesoTotal,
          ),
        ],
      ),
    );
  }

  Widget _resumoItem(
    String label,
    PosicaoStatus status,
    int qtd,
    double peso,
    int totalQtd,
    double totalPeso,
  ) {
    final prcntQtd = totalQtd == 0 ? 0.0 : (qtd / totalQtd * 100);
    final prcntPeso = totalPeso == 0 ? 0.0 : (peso / totalPeso * 100);

    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: status.color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              color: Colors.grey[800],
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppCss.largeBold.setSize(13).setColor(Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OS', style: AppCss.largeBold.setSize(10).setColor(Colors.grey[500]!)),
                      Text(
                        '$qtd (${prcntQtd.toStringAsFixed(0)}%)',
                        style: AppCss.largeBold.setSize(16).setColor(Colors.black),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('PESO', style: AppCss.largeBold.setSize(10).setColor(Colors.grey[500]!)),
                      Text(
                        '${peso.toStringAsFixed(1)} kg (${prcntPeso.toStringAsFixed(0)}%)',
                        style: AppCss.largeBold.setSize(14).setColor(Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            // Badge resumo
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${_posicoes.length} OS',
                style: AppCss.minimumBold
                    .setSize(12)
                    .setColor(Colors.white),
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
              : Column(
                  children: [
                    _buildResumoBar(),
                    Expanded(
                      child: GridView.builder(
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
                    ),
                  ],
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
