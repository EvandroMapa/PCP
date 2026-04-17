import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:flutter/material.dart';

/// Tabela de saldo: Mestre + Parciais por produto.
///
/// Colunas: Pedido | Produto A | Produto B | ...
/// Linhas:  Mestre | qtdeOriginal | qtdeOriginal
///          Parcial 1 | qtde | qtde
///          Parcial 2 | qtde | qtde
///          SALDO     | \$mestre - \$soma parciais por produto
class PaiPedidoSaldoTableWidget extends StatelessWidget {
  final PedidoModel mestre;
  final List<PedidoModel> filhos;

  const PaiPedidoSaldoTableWidget({
    super.key,
    required this.mestre,
    required this.filhos,
  });

  @override
  Widget build(BuildContext context) {
    // Produtos do mestre como colunas
    final produtos = mestre.produtos;
    if (produtos.isEmpty) return const SizedBox();

    // Calcula saldo por produto: qtdeOriginal do mestre - soma dos filhos
    double _saldo(PedidoProdutoModel mestProduto) {
      final totalFilhos = filhos.fold<double>(0, (acc, filho) {
        final fp = filho.produtos.where(
          (p) => p.produto.id == mestProduto.produto.id,
        );
        return acc + fp.fold<double>(0, (a, p) => a + p.qtdeOriginal);
      });
      return mestProduto.qtdeOriginal - totalFilhos;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          _headerRow(produtos),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Linha Mestre ────────────────────────────────────────────────
          _mestreRow(mestre, produtos),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Linhas Parciais ─────────────────────────────────────────────
          for (int i = 0; i < filhos.length; i++) ...[
            _filhoRow(context, filhos[i], produtos, isEven: i.isEven),
            if (i < filhos.length - 1)
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],

          // ── Linha Saldo ─────────────────────────────────────────────────
          const Divider(height: 1, thickness: 2, color: Color(0xFFCBD5E1)),
          _saldoRow(produtos, _saldo),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _headerRow(List<PedidoProdutoModel> produtos) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Pedido',
              style: AppCss.minimumBold.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final p in produtos)
            Expanded(
              flex: 2,
              child: Text(
                '${p.produto.nome}\n${p.produto.descricao}',
                textAlign: TextAlign.right,
                maxLines: 2,
                style: AppCss.minimumBold.copyWith(
                  color: const Color(0xFF64748B),
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── LINHA MESTRE ──────────────────────────────────────────────────────────

  Widget _mestreRow(PedidoModel mestre, List<PedidoProdutoModel> produtos) {
    return Container(
      color: const Color(0xFFFFFBEB), // âmbar clarinho
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFFF59E0B), width: 0.5),
                  ),
                  child: Text(
                    'MESTRE',
                    style: AppCss.minimumBold.copyWith(
                        fontSize: 8, color: const Color(0xFF92400E)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mestre.localizador,
                    style: AppCss.minimumBold.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final p in produtos)
            Expanded(
              flex: 2,
              child: Text(
                p.qtdeOriginal.toKg(),
                textAlign: TextAlign.right,
                style: AppCss.minimumBold.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── LINHA PARCIAL ─────────────────────────────────────────────────────────

  Widget _filhoRow(
    BuildContext context,
    PedidoModel filho,
    List<PedidoProdutoModel> produtos,
    {required bool isEven}
  ) {
    return InkWell(
      onTap: () async {
        await push(
          context,
          PedidoPage(pedido: filho, reason: PedidoInitReason.page),
        );
        // Busca o mestre FRESCO após qualquer mudança no parcial
        final mestreAtualizado = FirestoreClient.pedidos.getById(mestre.id);
        pedidoCtrl.pedidoStream.add(mestreAtualizado);
      },
      child: Container(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF3B82F6), width: 0.5),
                    ),
                    child: Text(
                      'PARCIAL',
                      style: AppCss.minimumBold.copyWith(
                          fontSize: 8, color: const Color(0xFF1E40AF)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      filho.localizador,
                      style: AppCss.minimumRegular.copyWith(
                        fontSize: 12,
                        color: AppColors.primaryMain,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            AppColors.primaryMain.withValues(alpha: 0.4),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
            for (final mestreProduto in produtos)
              Expanded(
                flex: 2,
                child: Builder(builder: (context) {
                  final fp = filho.produtos.where(
                    (p) => p.produto.id == mestreProduto.produto.id,
                  );
                  final qtde =
                      fp.isEmpty ? 0.0 : fp.fold(0.0, (a, p) => a + p.qtdeOriginal);
                  return Text(
                    qtde > 0 ? '− ${qtde.toKg()}' : '---',
                    textAlign: TextAlign.right,
                    style: AppCss.minimumRegular.copyWith(
                      fontSize: 12,
                      color: qtde > 0
                          ? const Color(0xFFDC2626)
                          : Colors.grey[400],
                      fontWeight:
                          qtde > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ── LINHA SALDO ───────────────────────────────────────────────────────────

  Widget _saldoRow(
    List<PedidoProdutoModel> produtos,
    double Function(PedidoProdutoModel) saldoFn,
  ) {
    return Container(
      color: const Color(0xFFF0FDF4), // verde clarinho
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(
                  'SALDO',
                  style: AppCss.minimumBold.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF16A34A),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          for (final p in produtos)
            Expanded(
              flex: 2,
              child: Builder(builder: (context) {
                final saldo = saldoFn(p);
                final isNegative = saldo < 0;
                return Text(
                  saldo.toKg(),
                  textAlign: TextAlign.right,
                  style: AppCss.minimumBold.copyWith(
                    fontSize: 13,
                    color: isNegative
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
