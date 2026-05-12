import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: BackendClient.estoques.dataStream.listen,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _header() {
    final totalSaldo = BackendClient.estoques.data
        .fold(0.0, (s, e) => s + e.quantidade);
    final temNegativo = BackendClient.estoques.data.any((e) => e.quantidade < 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryMain),
            const SizedBox(width: 8),
            Text('Saldos de Estoque', style: AppCss.mediumBold),
            const Spacer(),
            // Badge com saldo total
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
                  temNegativo ? Icons.warning_amber_rounded : Icons.account_balance_outlined,
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
    final filtrados = produtos.where((p) =>
        filtro.isEmpty ||
        p.nome.toLowerCase().contains(filtro) ||
        p.descricao.toLowerCase().contains(filtro)).toList()
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

  Widget _itemCard(produto, EstoqueModel? estoque) {
    final saldo = estoque?.quantidade ?? 0.0;
    final negativo = saldo < 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryMain),
        ),
        title: Text(produto.nome, style: AppCss.minimumBold),
        subtitle: Text(produto.descricao, style: AppCss.minimumRegular.setColor(Colors.grey[500]!)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: negativo
                    ? Colors.red.withValues(alpha: 0.10)
                    : AppColors.primaryMain.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                saldo.toKg(),
                style: AppCss.minimumBold.setColor(negativo ? Colors.red[700]! : AppColors.primaryMain),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Editar saldo',
              child: IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]),
                onPressed: () => _showEditDialog(produto, saldo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(produto, double saldoAtual) async {
    final form = EstoqueEditarSaldoModel(
      produtoId: produto.id,
      saldoAtual: saldoAtual,
    );
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar Saldo — ${produto.nome}'),
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
