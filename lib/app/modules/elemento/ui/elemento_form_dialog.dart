import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showElementoFormDialog(
  BuildContext context, {
  required PedidoModel pedido,
  ElementoModel? elemento,
}) {
  return showDialog(
    context: context,
    builder: (_) =>
        ElementoFormDialog(pedido: pedido, elemento: elemento),
  );
}

class ElementoFormDialog extends StatefulWidget {
  final PedidoModel pedido;
  final ElementoModel? elemento;

  const ElementoFormDialog(
      {required this.pedido, this.elemento, super.key});

  @override
  State<ElementoFormDialog> createState() => _ElementoFormDialogState();
}

class _ElementoFormDialogState extends State<ElementoFormDialog> {
  late ElementoCreateModel _form;

  // Produtos disponíveis no pedido = bitolas
  List<ProdutoModel> get _bitolas {
    final ids = widget.pedido
        .getProdutos()
        .map((pp) => pp.produto.id)
        .toSet();
    return FirestoreClient.produtos.data
        .where((p) => ids.contains(p.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.elemento != null) {
      _form = ElementoCreateModel.fromModel(widget.elemento!);
    } else {
      _form = ElementoCreateModel();
      _form.posicoes.add(ElementoPosicaoCreateModel());
    }
  }

  Future<void> _save() async {
    if (!_form.isValid) return;
    await elementoCtrl.onSaveElemento(_form, widget.pedido.id);
    if (mounted) Navigator.pop(context);
  }

  void _addPosicao() =>
      setState(() => _form.posicoes.add(ElementoPosicaoCreateModel()));

  void _removePosicao(int i) =>
      setState(() => _form.posicoes.removeAt(i));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding:
          const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding:
          const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding:
          const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.1)),
            ),
            child: Icon(Icons.layers_rounded,
                color: AppColors.primaryMain, size: 24),
          ),
          const SizedBox(width: 14),
          Text(
            widget.elemento == null ? 'Novo Elemento' : 'Editar Elemento',
            style: AppCss.largeBold.setSize(20),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Nome e Quantidade do elemento ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nome do Elemento', style: AppCss.mediumBold),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _form.nome.controller,
                          maxLength: 30,
                          decoration: _inputDecor('Ex: Bloco B1, Pilar P2...'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qtde', style: AppCss.mediumBold),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _form.qtde.controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _inputDecor('1'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Cabeçalho posições ─────────────────────────────────────
              Row(
                children: [
                  Text('Posições e OS', style: AppCss.mediumBold.setSize(15)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addPosicao,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Adicionar Posição',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        backgroundColor: AppColors.secondary.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Linha de cabeçalho das colunas (pequeno) ───────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    _colHeader('Posição', flex: 3),
                    const SizedBox(width: 6),
                    _colHeader('N° OS', flex: 2),
                    const SizedBox(width: 6),
                    _colHeader('Bitola', flex: 3),
                    const SizedBox(width: 6),
                    _colHeader('Peso (kg)', flex: 2),
                    const SizedBox(width: 32),
                  ],
                ),
              ),

              // ── Linhas de posição ───────────────────────────────────────
              ..._form.posicoes.asMap().entries.map((e) {
                final i = e.key;
                final pos = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome da posição
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: pos.nome.controller,

                          decoration: _inputDecor('Ex: Pilar P1'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Número OS
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: pos.numeroOs.controller,

                          decoration: _inputDecor('OS 1'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Bitola (dropdown)
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<ProdutoModel>(
                          value: pos.produto,
                          hint: const Text('Bitola',
                              style: TextStyle(fontSize: 13)),
                          isExpanded: true,
                          decoration: _inputDecor(''),
                          items: _bitolas
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.labelMinified,
                                        style: const TextStyle(
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (p) =>
                              setState(() => pos.produto = p),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Peso
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: pos.pesoKg.controller,

                          decoration: _inputDecor('0.000'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d,\.]'))
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Remover posição
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 20),
                        onPressed: _form.posicoes.length > 1
                            ? () => _removePosicao(i)
                            : null,
                        tooltip: 'Remover posição',
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // ── Subtotal calculado ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryMain.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primaryMain.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total do Elemento:',
                        style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
                    Text(
                      '${_form.pesoTotal.toStringAsFixed(3)} kg',
                      style: AppCss.largeBold
                          .setColor(AppColors.primaryMain),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[500],
            elevation: _form.isValid ? 2 : 0,
            shadowColor: AppColors.primaryMain.withValues(alpha: 0.3),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(
            widget.elemento == null
                ? 'Criar Elemento'
                : 'Salvar Alterações',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          onPressed: _form.isValid ? _save : null,
        ),
      ],
    );
  }

  Widget _colHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppCss.smallRegular.copyWith(
            color: Colors.grey[500], fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        isDense: true,
        fillColor: Colors.grey.shade50,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryMain, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        counterText: '',
      );
}
