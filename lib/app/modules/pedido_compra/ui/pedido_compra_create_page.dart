import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PedidoCompraCreatePage extends StatefulWidget {
  const PedidoCompraCreatePage({super.key});

  @override
  State<PedidoCompraCreatePage> createState() =>
      _PedidoCompraCreatePageState();
}

class _PedidoCompraCreatePageState extends State<PedidoCompraCreatePage> {
  // Estado local do item sendo digitado
  BitolaModel? _produtoSelecionado;
  final _qtdeCtrl = TextEditingController();
  final _qtdeFocus = FocusNode();

  @override
  void initState() {
    setWebTitle('Pedido de Compra');
    // Só reinicia o form se NÃO for modo edição
    if (!pedidoCompraCtrl.form.modoEdicao) {
      pedidoCompraCtrl.formStream.add(PedidoCompraCreateModel());
    }
    super.initState();
  }

  @override
  void dispose() {
    _qtdeCtrl.dispose();
    _qtdeFocus.dispose();
    super.dispose();
  }

  void _adicionarItem(PedidoCompraCreateModel form) {
    final qtde =
        double.tryParse(_qtdeCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (_produtoSelecionado == null || qtde <= 0) return;

    final item = PedidoCompraItemForm()
      ..produto = _produtoSelecionado
      ..quantidade.text = _qtdeCtrl.text;

    form.itens.add(item);
    pedidoCompraCtrl.formStream.update();

    // Limpa para próximo item
    setState(() {
      _produtoSelecionado = null;
      _qtdeCtrl.clear();
    });
    // Foco volta pro produto
    Future.microtask(() => FocusScope.of(context).requestFocus(FocusNode()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final form = pedidoCompraCtrl.form;
        if (form.itens.isEmpty) {
          Navigator.pop(context);
          return;
        }
        final sair = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
                'Você tem itens no pedido que ainda não foram salvos. Deseja sair e perder as alterações?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
        if (sair == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: StreamOut<PedidoCompraCreateModel>(
          stream: pedidoCompraCtrl.formStream.listen,
          builder: (_, form) => Text(
            form.modoEdicao ? 'Editar Pedido de Compra' : 'Novo Pedido de Compra',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: AppColors.primaryMain,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamOut<PedidoCompraCreateModel>(
        stream: pedidoCompraCtrl.formStream.listen,
        builder: (_, form) => _body(context, form),
      ),
    ),
    );
  }

  Widget _body(BuildContext context, PedidoCompraCreateModel form) {
    final fabricantes = [...BackendClient.fabricantes.data]
      ..sort((a, b) => a.nome.compareTo(b.nome));

    // Produtos já adicionados não aparecem como opção
    final produtosAdicionados =
        form.itens.map((i) => i.produto?.id).whereType<String>().toSet();
    final produtos = [...BackendClient.bitolas.data]
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    final produtosDisponiveis =
        produtos.where((p) => !produtosAdicionados.contains(p.id)).toList();

    final totalKg = form.itens.fold<double>(
        0, (s, i) => s + (double.tryParse(i.quantidade.text.replaceAll(',', '.')) ?? 0));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 1. Fabricante ─────────────────────────────────────────
              _bloco(
                icon: Icons.factory_outlined,
                label: 'Fabricante *',
                child: DropdownButtonFormField(
                  value: form.fabricante,
                  decoration: _dec('Selecione o fornecedor'),
                  items: fabricantes
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.nome),
                          ))
                      .toList(),
                  onChanged: (v) {
                    form.fabricante = v;
                    pedidoCompraCtrl.formStream.update();
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Entrada rápida de itens ────────────────────────────
              Row(children: [
                Icon(Icons.add_shopping_cart_outlined,
                    size: 16, color: AppColors.primaryMain),
                const SizedBox(width: 6),
                Text('Adicionar item',
                    style: AppCss.minimumBold.setSize(13)),
                Text(' *',
                    style: AppCss.minimumBold
                        .setColor(Colors.red)
                        .setSize(13)),
              ]),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Produto — exclui os já adicionados
                    DropdownButtonFormField<BitolaModel>(
                      value: _produtoSelecionado,
                      decoration: _dec('Bitola'),
                      items: produtosDisponiveis
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                    '${p.nome} · ${p.descricao}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _produtoSelecionado = v);
                        if (v != null) {
                          Future.microtask(() =>
                              FocusScope.of(context)
                                  .requestFocus(_qtdeFocus));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    // Quantidade + botão adicionar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtdeCtrl,
                            focusNode: _qtdeFocus,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d,\.]')),
                            ],
                            decoration: _dec('Quantidade (kg)'),
                            onFieldSubmitted: (_) =>
                                _adicionarItem(form),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMain,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                            ),
                            onPressed: () => _adicionarItem(form),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Adicionar'),
                          ),
                        ),
                      ],
                    ),
                    // Dica Enter
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.keyboard_return,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Pressione Enter para adicionar rapidamente',
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[400]!)
                              .setSize(11)),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 4. Lista de itens adicionados ─────────────────────────
              if (form.itens.isNotEmpty) ...[
                Row(children: [
                  Icon(Icons.list_alt_outlined,
                      size: 16, color: AppColors.primaryMain),
                  const SizedBox(width: 6),
                  Text(
                    'Itens do pedido (${form.itens.length})',
                    style: AppCss.minimumBold.setSize(13),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${totalKg.toKg()}',
                    style: AppCss.minimumBold
                        .setColor(AppColors.primaryMain)
                        .setSize(13),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: (List<PedidoCompraItemForm>.from(form.itens)
                      ..sort((a, b) => (a.produto?.sortIndex ?? 0)
                          .compareTo(b.produto?.sortIndex ?? 0)))
                        .asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isLast = idx == form.itens.length - 1;
                      final qtde = double.tryParse(
                              item.quantidade.text
                                  .replaceAll(',', '.')) ??
                          0.0;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMain
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: AppCss.minimumBold
                                        .setColor(AppColors.primaryMain)
                                        .setSize(11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.produto?.nome ?? '',
                                      style: AppCss.minimumBold
                                          .setSize(13),
                                    ),
                                    Text(
                                      item.produto?.descricao ?? '',
                                      style: AppCss.minimumRegular
                                          .setColor(Colors.grey[500]!)
                                          .setSize(11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                qtde.toKg(),
                                style: AppCss.minimumBold
                                    .setColor(AppColors.primaryMain)
                                    .setSize(13),
                              ),
                              const SizedBox(width: 6),
                              // Editar quantidade
                              Tooltip(
                                message: 'Editar quantidade',
                                child: GestureDetector(
                                  onTap: () => _editarQuantidade(item),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.blue
                                          .withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit_outlined,
                                        size: 14,
                                        color: Colors.blue[400]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Excluir item
                              Tooltip(
                                message: 'Remover item',
                                child: GestureDetector(
                                  onTap: () {
                                    form.removerItem(item);
                                    pedidoCompraCtrl.formStream.update();
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red
                                          .withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.delete_outline,
                                        size: 14,
                                        color: Colors.red[400]),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          if (!isLast)
                            const Divider(height: 1, indent: 14),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Botão fixo ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[200],
                disabledForegroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: form.isValid
                  ? () => pedidoCompraCtrl.onCreate(context)
                  : null,
              icon: const Icon(Icons.shopping_cart_checkout_outlined),
              label: Text(
                form.itens.isEmpty
                    ? 'Salvar Pedido'
                    : 'Salvar Pedido (${form.itens.length} item${form.itens.length > 1 ? 's' : ''})',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bloco({
    required IconData icon,
    required String label,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: AppColors.primaryMain),
              const SizedBox(width: 6),
              Text(label, style: AppCss.minimumBold.setSize(13)),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primaryMain),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      );

  void _editarQuantidade(PedidoCompraItemForm item) {
    final editCtrl = TextEditingController(text: item.quantidade.text);
    editCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editCtrl.text.length,
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Editar Quantidade — ${item.produto?.nome ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.produto?.descricao != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  item.produto!.descricao,
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[500]!)
                      .setSize(12),
                ),
              ),
            TextFormField(
              controller: editCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]')),
              ],
              decoration: _dec('Quantidade (kg)'),
              onFieldSubmitted: (_) {
                final texto = editCtrl.text;
                Navigator.pop(dialogContext);
                item.quantidade.text = texto;
                pedidoCompraCtrl.formStream.update();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final texto = editCtrl.text;
              Navigator.pop(dialogContext);
              item.quantidade.text = texto;
              pedidoCompraCtrl.formStream.update();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
