import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:flutter/material.dart';

/// Dialog para o operador controlar produção no nível da OS/Elemento.
/// Aberto a partir do card do pedido quando config = 'por_os'.
class OrdemPedidoElementosDialog extends StatefulWidget {
  final PedidoProdutoModel produto;
  final OrdemModel ordem;

  const OrdemPedidoElementosDialog({
    super.key,
    required this.produto,
    required this.ordem,
  });

  @override
  State<OrdemPedidoElementosDialog> createState() =>
      _OrdemPedidoElementosDialogState();
}

class _OrdemPedidoElementosDialogState
    extends State<OrdemPedidoElementosDialog> {
  List<ElementoModel> _elementos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchElementos();
  }

  Future<void> _fetchElementos() async {
    try {
      // Busca elementos do pedido via AppSupabaseClient (que já tem cache)
      final all = AppSupabaseClient.elementos.data
          .where((e) => e.pedidoId == widget.produto.pedidoId)
          .toList();

      if (all.isNotEmpty) {
        all.sort((a, b) =>
            a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
        setState(() {
          _elementos = all;
          _isLoading = false;
        });
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
        setState(() {
          _elementos = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Erro ao buscar elementos do pedido: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onStatusChanged(
      ElementoModel elemento, ElementoStatus newStatus) async {
    final pedido = FirestoreClient.pedidos.getById(widget.produto.pedidoId);
    await armacaoCtrl.updateElementoStatus(pedido, elemento, newStatus);
    await _fetchElementos();

    // Auto-update: se todos os elementos ficaram "pronto", atualiza o pedido pai
    await _checkAutoUpdatePedidoStatus();
  }

  Future<void> _checkAutoUpdatePedidoStatus() async {
    final todosElementos = AppSupabaseClient.elementos.data
        .where((e) => e.pedidoId == widget.produto.pedidoId)
        .toList();

    if (todosElementos.isEmpty) return;

    final todosProntos =
        todosElementos.every((e) => e.status == ElementoStatus.pronto && e.qtdePronto >= e.qtde);
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

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: OS + tipo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.construction_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APONTAMENTO POR OS',
                          style: AppCss.minimumBold
                              .setSize(10)
                              .setColor(Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pedido.localizador} · ${widget.produto.cliente.nome}',
                          style: AppCss.mediumBold
                              .setSize(16)
                              .setColor(Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Badge CD/CDA
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: pedido.tipo.foregroundColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: pedido.tipo.foregroundColor
                              .withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      tipoLabel,
                      style: AppCss.minimumBold
                          .setSize(12)
                          .setColor(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Body: lista de elementos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _elementos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhum elemento/OS encontrado para este pedido.',
                                  style: AppCss.mediumRegular
                                      .setColor(Colors.grey[500]!),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _elementos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final elemento = _elementos[index];
                            return _ElementoCard(
                              elemento: elemento,
                              onStatusChanged: (status) =>
                                  _onStatusChanged(elemento, status),
                            );
                          },
                        ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Resumo
                  Text(
                    '${_elementos.length} elemento(s) · ${_elementos.fold(0.0, (sum, e) => sum + e.pesoTotal).toKg()}',
                    style:
                        AppCss.minimumRegular.setSize(12).setColor(Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('FECHAR',
                        style: AppCss.mediumBold.setColor(AppColors.secondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CARD DO ELEMENTO ──────────────────────────────────────────────────────────

class _ElementoCard extends StatelessWidget {
  final ElementoModel elemento;
  final ValueChanged<ElementoStatus> onStatusChanged;

  const _ElementoCard({
    required this.elemento,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = elemento.status.color;
    final bitolaLabel = elemento.posicoes.isNotEmpty
        ? elemento.posicoes.first.produto?.descricao ?? '—'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Borda lateral
            Container(width: 4, color: statusColor),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do elemento (OS)
                    Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            elemento.nome,
                            style: AppCss.mediumBold.setSize(14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (elemento.qtde > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryMain.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${elemento.qtdePronto}/${elemento.qtde}',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(AppColors.primaryMain),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Posições resumo
                    Row(
                      children: [
                        _infoChip(
                            Icons.straighten_outlined, bitolaLabel, Colors.blue),
                        const SizedBox(width: 8),
                        _infoChip(Icons.scale_outlined,
                            elemento.pesoUnitario.toKg(), Colors.orange),
                        if (elemento.posicoes.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _infoChip(
                            Icons.format_list_numbered,
                            '${elemento.posicoes.length} pos.',
                            Colors.purple,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Botões de status (coluna vertical)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ElementoStatus.values.map((status) {
                  final isActive = status == elemento.status;
                  final color = status.color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      onTap: isActive
                          ? null
                          : () => onStatusChanged(status),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 120,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: isActive ? 8 : 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              color.withValues(alpha: isActive ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(
                                alpha: isActive ? 1.0 : 0.4),
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            status.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: isActive ? 11 : 10,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: Colors.black.withValues(
                                  alpha: isActive ? 0.85 : 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppCss.minimumBold.setSize(10).setColor(color),
          ),
        ],
      ),
    );
  }
}
