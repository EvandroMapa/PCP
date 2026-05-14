import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:flutter/material.dart';

class EstoqueSaldoSection extends StatefulWidget {
  const EstoqueSaldoSection({super.key});

  @override
  State<EstoqueSaldoSection> createState() => _EstoqueSaldoSectionState();
}

class _EstoqueSaldoSectionState extends State<EstoqueSaldoSection> {
  final TextController _search = TextController();
  final Map<String, bool> _expandedProdutos = {};

  // ── Paleta de cores por nível ──────────────────────────────────────────
  // Verde: estoque >= ideal (ou >= mínimo se ideal não configurado)
  // Amarelo: estoque entre mínimo e ideal
  // Vermelho: estoque < mínimo
  // Neutro: nenhum limite configurado

  static const _verde = Color(0xFF16A34A);
  static const _verdeBg = Color(0xFFF0FDF4);
  static const _verdeBorder = Color(0xFFBBF7D0);

  static const _amarelo = Color(0xFFCA8A04);
  static const _amareloBg = Color(0xFFFEFCE8);
  static const _amareloBorder = Color(0xFFFDE68A);

  static const _vermelho = Color(0xFFDC2626);
  static const _vermelhoBg = Color(0xFFFEF2F2);
  static const _vermelhoBorder = Color(0xFFFECACA);

  static const _neutroBg = Color(0xFFFAFAFA);
  static const _neutroBorder = Color(0xFFE2E8F0);

  /// Retorna (bgColor, borderColor, accentColor, icon, label)
  _NivelEstoque _calcularNivel(double saldo, double minimo, double ideal) {
    if (minimo <= 0 && ideal <= 0) {
      return _NivelEstoque(
        bg: _neutroBg, border: _neutroBorder,
        accent: Colors.grey[600]!, icon: Icons.remove_circle_outline,
        label: 'Sem limites',
      );
    }
    if (minimo > 0 && saldo < minimo) {
      return _NivelEstoque(
        bg: _vermelhoBg, border: _vermelhoBorder,
        accent: _vermelho, icon: Icons.warning_amber_rounded,
        label: 'Abaixo do mínimo',
      );
    }
    if (ideal > 0 && saldo < ideal) {
      return _NivelEstoque(
        bg: _amareloBg, border: _amareloBorder,
        accent: _amarelo, icon: Icons.shield_outlined,
        label: 'Abaixo do ideal',
      );
    }
    return _NivelEstoque(
      bg: _verdeBg, border: _verdeBorder,
      accent: _verde, icon: Icons.check_circle_outline,
      label: 'Estoque saudável',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: BackendClient.estoques.dataStream.listen,
      builder: (_, __) => StreamOut(
        stream: BackendClient.pedidosCompra.dataStream.listen,
        builder: (_, ___) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(child: _lista()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final totalSaldo =
        BackendClient.estoques.data.fold(0.0, (s, e) => s + e.quantidade);
    final temNegativo =
        BackendClient.estoques.data.any((e) => e.quantidade < 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined,
                size: 18, color: AppColors.primaryMain),
            const SizedBox(width: 8),
            Text('Saldos de Estoque', style: AppCss.mediumBold),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: temNegativo
                    ? Colors.red.withValues(alpha: 0.10)
                    : AppColors.primaryMain.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  temNegativo
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_outlined,
                  size: 12,
                  color: temNegativo ? Colors.red[700]! : AppColors.primaryMain,
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: ${totalSaldo.toKg()}',
                  style: AppCss.minimumBold.setColor(
                    temNegativo ? Colors.red[700]! : AppColors.primaryMain,
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Ajuste o saldo atual de cada produto (implantação)',
              style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
          const SizedBox(height: 12),
          AppField(
            hint: 'Pesquisar produto...',
            controller: _search,
            suffixIcon: Icons.search,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    final produtos = BackendClient.produtos.data;
    if (produtos.isEmpty) {
      return const Center(child: Text('Nenhum produto cadastrado'));
    }
    final filtro = _search.text.toLowerCase();
    final filtrados = produtos
        .where((p) =>
            filtro.isEmpty ||
            p.nome.toLowerCase().contains(filtro) ||
            p.descricao.toLowerCase().contains(filtro))
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final produto = filtrados[i];
        final estoque = BackendClient.estoques.getByProdutoId(produto.id);
        return _itemCard(produto, estoque);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD DE PRODUTO — redesenhado com cores por nível
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _itemCard(produto, EstoqueModel? estoque) {
    final saldoFisico = estoque?.quantidade ?? 0.0;
    final estoqueMin = estoque?.estoqueMinimo ?? 0.0;
    final estoqueIdeal = estoque?.estoqueIdeal ?? 0.0;

    final itensPendentes =
        BackendClient.pedidosCompra.getPendentesByProdutoId(produto.id);
    final totalEmPedido =
        BackendClient.pedidosCompra.getTotalPendenteByProdutoId(produto.id);
    final saldoProjetado = saldoFisico + totalEmPedido;
    final temPedidos = itensPendentes.isNotEmpty;

    final nivel = _calcularNivel(saldoFisico, estoqueMin, estoqueIdeal);

    // Agrupa pedidos por grupoId
    final Map<String, List<PedidoCompraModel>> pedidosAgrupados = {};
    for (final item in itensPendentes) {
      pedidosAgrupados.putIfAbsent(item.grupoId, () => []).add(item);
    }
    final totalPedidos = pedidosAgrupados.length;
    final expandedKey = '${produto.id}_expanded';

    return StatefulBuilder(
      builder: (context, setCardState) {
        final isExpanded = _expandedProdutos[expandedKey] ?? false;

        return Container(
          decoration: BoxDecoration(
            color: nivel.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: nivel.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: nivel.accent.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header: nome + ícone de status + botão editar ───────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                child: Row(
                  children: [
                    // Ícone de status
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: nivel.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(nivel.icon, size: 17, color: nivel.accent),
                    ),
                    const SizedBox(width: 10),
                    // Nome e descrição
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(produto.nome, style: AppCss.minimumBold.setSize(13)),
                          Row(
                            children: [
                              Flexible(
                                child: Text(produto.descricao,
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.grey[500]!)
                                        .setSize(11),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 6),
                              // Badge de status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: nivel.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  nivel.label,
                                  style: AppCss.minimumBold
                                      .setColor(nivel.accent)
                                      .setSize(9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botão editar
                    Tooltip(
                      message: 'Editar saldo, mínimo e ideal',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 17, color: Colors.grey[400]),
                        onPressed: () => _showEditDialog(
                          produto,
                          saldoFisico,
                          estoqueMin,
                          estoqueIdeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Badges: Físico · Mínimo · Ideal ── alinhados ───────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    _badge(
                      'Físico',
                      saldoFisico.toKg(),
                      saldoFisico < 0 ? _vermelho : nivel.accent,
                      Icons.inventory_2_outlined,
                      destaque: true,
                    ),
                    const SizedBox(width: 6),
                    if (estoqueMin > 0) ...[
                      _badge(
                        'Mínimo',
                        estoqueMin.toKg(),
                        _amarelo,
                        Icons.shield_outlined,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (estoqueIdeal > 0)
                      _badge(
                        'Ideal',
                        estoqueIdeal.toKg(),
                        const Color(0xFF2563EB),
                        Icons.star_outline_rounded,
                      ),
                    const Spacer(),
                    // Barra visual de nível
                    if (estoqueMin > 0 || estoqueIdeal > 0)
                      _barraProgresso(saldoFisico, estoqueMin, estoqueIdeal, nivel),
                  ],
                ),
              ),

              // ── Em pedido (clicável) ───────────────────────────────
              if (temPedidos)
                InkWell(
                  onTap: () => setCardState(() {
                    _expandedProdutos[expandedKey] = !isExpanded;
                  }),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      border: Border(
                        top: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.12)),
                        bottom: isExpanded
                            ? BorderSide.none
                            : BorderSide(
                                color: Colors.blue.withValues(alpha: 0.12)),
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 13, color: Colors.blue[600]),
                      const SizedBox(width: 6),
                      Text('Em pedido:',
                          style: AppCss.minimumRegular
                              .setColor(Colors.blue[700]!)
                              .setSize(12)),
                      const SizedBox(width: 4),
                      Text('+${totalEmPedido.toKg()}',
                          style: AppCss.minimumBold
                              .setColor(Colors.blue[700]!)
                              .setSize(12)),
                      const Spacer(),
                      Text(
                        '$totalPedidos pedido${totalPedidos > 1 ? 's' : ''}',
                        style: AppCss.minimumRegular
                            .setColor(Colors.blue[400]!)
                            .setSize(11),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16, color: Colors.blue[400],
                      ),
                    ]),
                  ),
                ),

              // ── Detalhe por pedido ─────────────────────────────────
              if (temPedidos && isExpanded)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.025),
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.blue.withValues(alpha: 0.12)),
                    ),
                  ),
                  child: Column(
                    children: pedidosAgrupados.entries.map((entry) {
                      final itensDoGrupo = entry.value;
                      final qtdeGrupo = itensDoGrupo.fold<double>(
                          0, (s, i) => s + i.quantidade);
                      final primeiroItem = itensDoGrupo.first;
                      final isConfirmado =
                          primeiroItem.status == PedidoCompraStatus.confirmado;
                      return Container(
                        padding: const EdgeInsets.fromLTRB(24, 7, 14, 7),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: Colors.blue.withValues(alpha: 0.08)),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            isConfirmado
                                ? Icons.thumb_up_outlined
                                : Icons.pending_outlined,
                            size: 13,
                            color: isConfirmado
                                ? Colors.blue[500]
                                : Colors.orange[500],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(primeiroItem.fabricante.nome,
                                    style: AppCss.minimumBold
                                        .setColor(Colors.grey[700]!)
                                        .setSize(12)),
                                Text(primeiroItem.createdAt.ddMMyyyy(),
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.grey[400]!)
                                        .setSize(10)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConfirmado
                                  ? Colors.blue.withValues(alpha: 0.10)
                                  : Colors.orange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isConfirmado ? 'Confirmado' : 'Pendente',
                              style: AppCss.minimumBold
                                  .setColor(isConfirmado
                                      ? Colors.blue[700]!
                                      : Colors.orange[700]!)
                                  .setSize(9),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('+${qtdeGrupo.toKg()}',
                              style: AppCss.minimumBold
                                  .setColor(Colors.blue[600]!)
                                  .setSize(12)),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

              // ── Saldo projetado ────────────────────────────────────
              if (temPedidos)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Icon(Icons.account_balance_outlined,
                        size: 13, color: Colors.green[700]),
                    const SizedBox(width: 5),
                    Text('Projetado:',
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[600]!)
                            .setSize(11)),
                    const SizedBox(width: 4),
                    Text(
                      '(${saldoFisico.toKg()} + ${totalEmPedido.toKg()})',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[400]!)
                          .setSize(10),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.25)),
                      ),
                      child: Text(saldoProjetado.toKg(),
                          style: AppCss.minimumBold
                              .setColor(Colors.green[700]!)
                              .setSize(11)),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Badge compacto reutilizável ────────────────────────────────────────

  Widget _badge(String label, String valor, Color cor, IconData icon,
      {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: destaque
            ? cor.withValues(alpha: 0.10)
            : cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: cor),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppCss.minimumRegular
                    .setColor(cor.withValues(alpha: 0.70))
                    .setSize(9)),
            Text(valor,
                style: AppCss.minimumBold.setColor(cor).setSize(11)),
          ],
        ),
      ]),
    );
  }

  // ── Barra de progresso visual ──────────────────────────────────────────

  Widget _barraProgresso(
      double saldo, double minimo, double ideal, _NivelEstoque nivel) {
    final teto = ideal > 0 ? ideal : minimo;
    if (teto <= 0) return const SizedBox.shrink();
    final pct = (saldo / teto).clamp(0.0, 1.5);

    return Tooltip(
      message: '${(pct * 100).toStringAsFixed(0)}% do ${ideal > 0 ? "ideal" : "mínimo"}',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: 60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: AppCss.minimumBold
                    .setColor(nivel.accent)
                    .setSize(10)),
            const SizedBox(height: 2),
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: nivel.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: nivel.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG DE EDIÇÃO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showEditDialog(produto, double saldoAtual,
      double estoqueMinimoAtual, double estoqueIdealAtual) async {
    final form = EstoqueEditarSaldoModel(
      produtoId: produto.id,
      saldoAtual: saldoAtual,
      estoqueMinimoAtual: estoqueMinimoAtual,
      estoqueIdealAtual: estoqueIdealAtual,
    );
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar Estoque — ${produto.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo atual: ${saldoAtual.toKg()}',
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
            const SizedBox(height: 12),
            AppField(
              label: 'Novo saldo (kg)',
              controller: form.novoSaldo,
              type: TextInputType.number,
              hint: '0,000',
            ),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Text('Estoque de Segurança',
                  style: AppCss.minimumBold
                      .setColor(Colors.amber[700]!)
                      .setSize(13)),
            ]),
            const SizedBox(height: 4),
            Text('Quantidade mínima para alertar reposição.',
                style: AppCss.minimumRegular
                    .setColor(Colors.grey[500]!)
                    .setSize(11)),
            const SizedBox(height: 8),
            AppField(
              label: 'Estoque mínimo (kg)',
              controller: form.estoqueMinimo,
              type: TextInputType.number,
              hint: '0,000',
            ),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.star_outline_rounded,
                  size: 14, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text('Estoque Ideal',
                  style: AppCss.minimumBold
                      .setColor(Colors.blue[700]!)
                      .setSize(13)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Nível ótimo de estoque. Usado pelo simulador de compra para calcular a quantidade sugerida de reposição.',
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[500]!)
                  .setSize(11),
            ),
            const SizedBox(height: 8),
            AppField(
              label: 'Estoque ideal (kg)',
              controller: form.estoqueIdeal,
              type: TextInputType.number,
              hint: '0,000',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await estoqueCtrl.onEditarSaldo(form);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ── Modelo auxiliar de nível de estoque ──────────────────────────────────────
class _NivelEstoque {
  final Color bg;
  final Color border;
  final Color accent;
  final IconData icon;
  final String label;

  const _NivelEstoque({
    required this.bg,
    required this.border,
    required this.accent,
    required this.icon,
    required this.label,
  });
}
