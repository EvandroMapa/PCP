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
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
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
  bool _isLoading = true;

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
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      log('Erro ao buscar elementos do pedido: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onElementoTap(ElementoModel elemento) async {
    // Abre picker de status
    final newStatus = await _showStatusPicker(elemento);
    if (newStatus == null || newStatus == elemento.status) return;

    final pedido = FirestoreClient.pedidos.getById(widget.produto.pedidoId);
    await armacaoCtrl.updateElementoStatus(pedido, elemento, newStatus);
    await _fetchElementos();
    await _checkAutoUpdatePedidoStatus();
  }

  Future<ElementoStatus?> _showStatusPicker(ElementoModel elemento) async {
    return showDialog<ElementoStatus>(
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
                elemento.nome,
                style: AppCss.largeBold.setSize(20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...ElementoStatus.values.map((status) {
                final isActive = status == elemento.status;
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

  Future<void> _checkAutoUpdatePedidoStatus() async {
    final todosElementos = AppSupabaseClient.elementos.data
        .where((e) => e.pedidoId == widget.produto.pedidoId)
        .toList();

    if (todosElementos.isEmpty) return;

    final todosProntos = todosElementos
        .every((e) => e.status == ElementoStatus.pronto && e.qtdePronto >= e.qtde);
    final algumArmando =
        todosElementos.any((e) => e.status == ElementoStatus.armando);

    PedidoProdutoStatus? novoStatus;

    if (todosProntos &&
        widget.produto.status.status != PedidoProdutoStatus.pronto) {
      novoStatus = PedidoProdutoStatus.pronto;
    } else if (algumArmando &&
        widget.produto.status.status ==
            PedidoProdutoStatus.aguardandoProducao) {
      novoStatus = PedidoProdutoStatus.produzindo;
    } else if (!algumArmando &&
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
              ),
              child: Text(
                '${_elementos.length} OS',
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
          : _elementos.isEmpty
              ? const EmptyData(
                  message: 'Nenhum elemento/OS encontrado para este pedido.')
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _elementos.length,
                  itemBuilder: (context, index) {
                    final elemento = _elementos[index];
                    return _ElementoOSCard(
                      key: ValueKey(elemento.id),
                      elemento: elemento,
                      onTap: () => _onElementoTap(elemento),
                    );
                  },
                ),
    );
  }
}

// ─── CARD ESTILO INDUSTRIAL (CONFORME REFERÊNCIA) ────────────────────────────

class _ElementoOSCard extends StatelessWidget {
  final ElementoModel elemento;
  final VoidCallback onTap;

  const _ElementoOSCard({
    super.key,
    required this.elemento,
    required this.onTap,
  });

  String _statusLabel(ElementoStatus status) {
    switch (status) {
      case ElementoStatus.aguardando:
        return 'AGUARDANDO';
      case ElementoStatus.armando:
        return 'PRODUZINDO';
      case ElementoStatus.pronto:
        return 'PRONTO';
    }
  }

  Color _statusTextColor(ElementoStatus status) {
    switch (status) {
      case ElementoStatus.aguardando:
        return Colors.black87;
      case ElementoStatus.armando:
        return Colors.orange[800]!;
      case ElementoStatus.pronto:
        return Colors.green[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = elemento.status;
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
            width: status == ElementoStatus.armando ? 2.5 : 1.5,
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
                elemento.posicoes.isNotEmpty
                    ? elemento.posicoes.first.numeroOs
                    : elemento.nome,
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

            // ─── STATUS ───
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _statusTextColor(status),
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (elemento.qtde > 1 && elemento.isProntoParcial) ...[
                      const SizedBox(height: 6),
                      // Barra de progresso para parcial
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: elemento.progressoPronto,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(Colors.green[400]!),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${elemento.qtdePronto}/${elemento.qtde} pç',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── RODAPÉ: QTDE / PESO / OS ───
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _footerItem('QTDE', '${elemento.qtde} pç'),
                  _footerItem('PESO', elemento.pesoUnitario.toKg()),
                  _footerItem('OS', '${elemento.posicoes.length} os'),
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
