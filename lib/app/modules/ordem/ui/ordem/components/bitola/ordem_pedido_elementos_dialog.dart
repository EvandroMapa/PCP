import 'dart:async';
import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';

import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:flutter/material.dart';

/// Página fullscreen para o operador controlar produção por OS/Elemento.
/// Mostra um grid de cards no estilo industrial.
class OrdemPedidoElementosPage extends StatefulWidget {
  final PedidoBitolaModel produto;
  final OrdemModel ordem;
  final bool readOnly;

  const OrdemPedidoElementosPage({
    super.key,
    required this.produto,
    required this.ordem,
    this.readOnly = false,
  });

  @override
  State<OrdemPedidoElementosPage> createState() =>
      _OrdemPedidoElementosPageState();
}

class _OrdemPedidoElementosPageState extends State<OrdemPedidoElementosPage> {
  List<ElementoModel> _elementos = [];
  List<_PosicaoItem> _posicoes = [];
  bool _isLoading = true;

  /// Lock anti-duplicata: IDs de posições que estão sendo processadas no momento.
  /// Evita que toques rápidos do operador gerem múltiplas baixas/estornos.
  final Set<String> _processandoPosicoes = {};

  /// Escuta mudanças no cache de elementos (Realtime de outro dispositivo)
  StreamSubscription? _elemsSubscription;

  String get _ordemProdutoId => widget.ordem.produto.id;

  @override
  void initState() {
    super.initState();
    _fetchElementos();
    // Quando o Realtime atualiza uma posição em outro dispositivo,
    // re-sincroniza _posicoes com o cache global.
    // IMPORTANTE: após um re-fetch completo (start()), os objetos no cache
    // são NOVOS — sem re-sincronizar, _posicoes ficam com referências velhas
    // e deixam de refletir mudanças de outros dispositivos.
    _elemsSubscription =
        AppSupabaseClient.elementos.dataStream.listen.listen((_) {
      if (!mounted) return;
      setState(() {
        _elementos = AppSupabaseClient.elementos.data
            .where((e) => e.pedidoId == widget.produto.pedidoId)
            .toList();
        _buildPosicoes();
      });
    });
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

  @override
  void dispose() {
    _elemsSubscription?.cancel();
    super.dispose();
  }

  /// Constroi lista flat de posições filtradas pela bitola da ordem
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

  bool get _isAlternarToque =>
      PreferencesService.alternarToqueCD.value;

  /// Próximo status (avançar)
  PosicaoStatus? _proximoPosicaoStatus(PosicaoStatus atual) {
    switch (atual) {
      case PosicaoStatus.aguardando:
        return PosicaoStatus.produzindo;
      case PosicaoStatus.produzindo:
        return PosicaoStatus.pronto;
      case PosicaoStatus.aguardaSegundaEtapa:
        return PosicaoStatus.produzindo; // inicia nova rodada
      case PosicaoStatus.pronto:
        return null;
    }
  }

  /// Status anterior (voltar)
  PosicaoStatus? _anteriorPosicaoStatus(PosicaoStatus atual) {
    switch (atual) {
      case PosicaoStatus.pronto:
        return PosicaoStatus.produzindo;
      case PosicaoStatus.produzindo:
        return PosicaoStatus.aguardando;
      case PosicaoStatus.aguardaSegundaEtapa:
        return PosicaoStatus.aguardando; // desfazer 2ª etapa
      case PosicaoStatus.aguardando:
        return null;
    }
  }

  Future<void> _onPosicaoAlternar(_PosicaoItem item, {required bool avancar}) async {
    final oldStatus = item.posicao.status;
    final newStatus = avancar
        ? _proximoPosicaoStatus(oldStatus)
        : _anteriorPosicaoStatus(oldStatus);
    if (newStatus == null) return;
    await _aplicarNovoStatus(item, oldStatus, newStatus);
  }

  /// Marca a OS/posicao como aguardando 2ª etapa
  Future<void> _marcarSegundaEtapaPosicao(_PosicaoItem item) async {
    final oldStatus = item.posicao.status;
    await _aplicarNovoStatus(
        item, oldStatus, PosicaoStatus.aguardaSegundaEtapa);
  }

  Future<void> _onPosicaoTap(_PosicaoItem item) async {
    final oldStatus = item.posicao.status;
    final newStatus = await _showStatusPicker(item);
    if (newStatus == null || newStatus == oldStatus) return;
    await _aplicarNovoStatus(item, oldStatus, newStatus);
  }

  Future<void> _aplicarNovoStatus(
    _PosicaoItem item,
    PosicaoStatus oldStatus,
    PosicaoStatus newStatus,
  ) async {
    // Lock anti-duplicata: ignora se esta posição já está sendo processada.
    // Evita múltiplas baixas/estornos por toques rápidos do operador.
    if (_processandoPosicoes.contains(item.posicao.id)) return;
    _processandoPosicoes.add(item.posicao.id);

    try {
      // Atualização instantânea na UI
      setState(() {
        item.posicao.status = newStatus;
      });

      // Atualiza também o cache global de elementos para os gráficos
      _updateGlobalElementosCache(item);

      // Persiste no Supabase
      await SupabaseService.client
          .from('elemento_posicoes')
          .update({'status': newStatus.name}).eq('id', item.posicao.id);

      // Baixa/estorno de estoque por posição (OS)
      final pesoPosicao = item.posicao.pesoKg * item.elemento.qtde;
      if (newStatus == PosicaoStatus.pronto && oldStatus != PosicaoStatus.pronto) {
        await estoqueCtrl.baixarEstoque(
          produtoId: _ordemProdutoId,
          quantidade: pesoPosicao,
          ordem: widget.ordem,
        );
      } else if (oldStatus == PosicaoStatus.pronto && newStatus != PosicaoStatus.pronto) {
        await estoqueCtrl.estornarBaixa(
          produtoId: _ordemProdutoId,
          quantidade: pesoPosicao,
          ordem: widget.ordem,
        );
      }

      // Sincroniza status do pedido/ordem
      await _checkAutoUpdatePedidoStatus();

      // Força re-emit do stream de ordens para atualizar gráficos na lista
      _notifyOrdensStream();
    } catch (e) {
      log('Erro ao atualizar status da posição: $e');
    } finally {
      // Libera o lock independente de sucesso ou erro
      _processandoPosicoes.remove(item.posicao.id);
    }
  }

  /// Atualiza o cache global de AppSupabaseClient.elementos com o novo status da posição
  void _updateGlobalElementosCache(_PosicaoItem item) {
    final globalElementos = AppSupabaseClient.elementos.data;
    final idx = globalElementos.indexWhere((e) => e.id == item.elemento.id);
    if (idx != -1) {
      final posIdx = globalElementos[idx]
          .posicoes
          .indexWhere((p) => p.id == item.posicao.id);
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

    switch (target) {
      case PosicaoStatus.aguardando:
        return current == PosicaoStatus.produzindo;

      case PosicaoStatus.produzindo:
        return current == PosicaoStatus.aguardando ||
            current == PosicaoStatus.pronto ||
            current == PosicaoStatus.aguardaSegundaEtapa;

      case PosicaoStatus.aguardaSegundaEtapa:
        return current == PosicaoStatus.produzindo;

      case PosicaoStatus.pronto:
        return current == PosicaoStatus.produzindo;
    }
  }

  Future<PosicaoStatus?> _showStatusPicker(_PosicaoItem item) async {
    return showGeneralDialog<PosicaoStatus>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => _PosicaoStatusDialog(
        item: item,
        canTransition: _canTransition,
      ),
    );
  }

  /// Auto-update: sincroniza status da ordem/pedido com as posições
  Future<void> _checkAutoUpdatePedidoStatus() async {
    if (_posicoes.isEmpty) return;

    final todosAguardando = _posicoes.every((p) =>
        p.posicao.status == PosicaoStatus.aguardando);
    final todosProntos =
        _posicoes.every((p) => p.posicao.status == PosicaoStatus.pronto);
    // Se alguma posicao aguarda 2ª etapa, a bitola também aguarda
    final temSegundaEtapa = _posicoes
        .any((p) => p.posicao.status == PosicaoStatus.aguardaSegundaEtapa);

    PedidoBitolaStatus novoStatus;

    if (todosAguardando) {
      novoStatus = PedidoBitolaStatus.aguardandoProducao;
    } else if (todosProntos) {
      novoStatus = PedidoBitolaStatus.pronto;
    } else {
      // Inclui casos com aguardaSegundaEtapa: bitola permanece produzindo
      novoStatus = PedidoBitolaStatus.produzindo;
    }

    // Busca o status atual no Firestore para comparar corretamente
    final currentPedido =
        FirestoreClient.pedidos.getById(widget.produto.pedidoId);
    final currentProduto = currentPedido.produtos.firstWhere(
        (p) => p.id == widget.produto.id,
        orElse: () => widget.produto);

    if (novoStatus == currentProduto.status.status) {
      return;
    }

    // Atualiza no Firestore o status do item do pedido
    await FirestoreClient.pedidos
        .updateProdutoStatus(widget.produto, novoStatus);

    // Recalcula o status do pedido pai e dispara automação de mudança de etapa
    final pedido = await FirestoreClient.pedidos
        .updatePedidoStatus(widget.produto);
    if (pedido != null) {
      await ordemCtrl.updateFeaturesByPedidoStatus(pedido);
    }

    // Força atualização da lista de ordens para refletir nos indicadores laterais
    await FirestoreClient.ordens.fetch();
    final updatedOrdem = ordemCtrl.getOrdemById(widget.ordem.id);
    ordemCtrl.setOrdem(updatedOrdem);
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
        case PosicaoStatus.aguardaSegundaEtapa:
          // Conta como produzindo no sumário (ainda está em produção)
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
          border: Border.all(
              color: status.color.withValues(alpha: 0.3), width: 1.5),
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
                      Text('OS',
                          style: AppCss.largeBold
                              .setSize(10)
                              .setColor(Colors.grey[500]!)),
                      Text(
                        '$qtd (${prcntQtd.toStringAsFixed(0)}%)',
                        style:
                            AppCss.largeBold.setSize(16).setColor(Colors.black),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('PESO',
                          style: AppCss.largeBold
                              .setSize(10)
                              .setColor(Colors.grey[500]!)),
                      Text(
                        '${peso.toStringAsFixed(1)} kg (${prcntPeso.toStringAsFixed(0)}%)',
                        style:
                            AppCss.largeBold.setSize(14).setColor(Colors.black),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${_posicoes.length} OS',
                style: AppCss.minimumBold.setSize(12).setColor(Colors.white),
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
                  Text('Carregando elementos...', style: AppCss.mediumRegular),
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
                          final isReadOnly = widget.readOnly;
                          return _ElementoOSCard(
                            key: ValueKey(
                                '${item.elemento.id}_${item.posicao.id}'),
                            item: item,
                            onTap: isReadOnly
                                ? null
                                : _isAlternarToque
                                    ? () => _onPosicaoAlternar(item, avancar: true)
                                    : () => _onPosicaoTap(item),
                            onLongPress: isReadOnly
                                ? null
                                : _isAlternarToque
                                    ? () => _onPosicaoAlternar(item, avancar: false)
                                    : null,
                            onMarcarSegundaEtapa: isReadOnly
                                ? null
                                : () => _marcarSegundaEtapaPosicao(item),
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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMarcarSegundaEtapa;

  const _ElementoOSCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.onMarcarSegundaEtapa,
  });

  ElementoModel get elemento => item.elemento;
  ElementoPosicaoModel get posicao => item.posicao;

  String _statusLabel(PosicaoStatus status) {
    switch (status) {
      case PosicaoStatus.aguardando:
        return 'AGUARDANDO';
      case PosicaoStatus.produzindo:
        return 'PRODUZINDO';
      case PosicaoStatus.aguardaSegundaEtapa:
        return 'AG. 2ª ETAPA';
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
      case PosicaoStatus.aguardaSegundaEtapa:
        return Colors.deepOrange[700]!;
      case PosicaoStatus.pronto:
        return Colors.green[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = posicao.status;
    final statusColor = status.color;

    return GestureDetector(
      onLongPress: onLongPress,
      child: InkWell(
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
            // ─── TARJA: NÚMERO DA OS + botão 2ª (quando produzindo) ───
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                  child: Text(
                    'OS - ${posicao.numeroOs}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Botão 🔄 2ª etapa — sobreposto no canto superior direito da tarja
                if (status == PosicaoStatus.produzindo &&
                    onMarcarSegundaEtapa != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Tooltip(
                      message: '2ª etapa',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: onMarcarSegundaEtapa,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.replay_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ─── NOME DO ELEMENTO (X QTDE) ───
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${elemento.nome}${elemento.qtde > 1 ? ' (X ${elemento.qtde})' : ''}',
                style: const TextStyle(
                  fontSize: 17,
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
      ),
    );
  }

  Widget _footerItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── DIALOG PREMIUM DE STATUS DA POSIÇÃO/OS ──────────────────────────────────

class _PosicaoStatusDialog extends StatelessWidget {
  final _PosicaoItem item;
  final bool Function(PosicaoStatus novo, PosicaoStatus atual) canTransition;

  const _PosicaoStatusDialog({
    required this.item,
    required this.canTransition,
  });

  IconData _iconFor(PosicaoStatus status) {
    switch (status) {
      case PosicaoStatus.aguardando:
        return Icons.hourglass_bottom_rounded;
      case PosicaoStatus.produzindo:
        return Icons.construction_rounded;
      case PosicaoStatus.aguardaSegundaEtapa:
        return Icons.replay_rounded;
      case PosicaoStatus.pronto:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAtual = item.posicao.status;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── HEADER ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'OS - ${item.posicao.numeroOs}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.posicao.nome,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.posicao.qtde} peça(s)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── BOTÕES DE STATUS ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  children: PosicaoStatus.values.map((status) {
                    final isAtivo = status == statusAtual;
                    final canSelect =
                        isAtivo || canTransition(status, statusAtual);
                    final color = status.color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Opacity(
                        opacity: canSelect ? 1.0 : 0.3,
                        child: IgnorePointer(
                          ignoring: !canSelect,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, status),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color: isAtivo
                                    ? color.withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isAtivo
                                      ? color.withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.10),
                                  width: isAtivo ? 2.5 : 1.5,
                                ),
                                boxShadow: isAtivo
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.25),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                          alpha: isAtivo ? 0.25 : 0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _iconFor(status),
                                      size: 24,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      status.label.toUpperCase(),
                                      style: TextStyle(
                                        color: isAtivo
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.75),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  if (isAtivo)
                                    Icon(Icons.check_circle_rounded,
                                        color: color, size: 26),
                                  if (!canSelect && !isAtivo)
                                    Icon(Icons.lock_rounded,
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ─── BOTÃO FECHAR ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.07),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Text(
                      'FECHAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
