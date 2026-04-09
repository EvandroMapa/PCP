import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/elemento/ui/elemento_comparativo_dialog.dart';
import 'package:aco_plus/app/modules/elemento/ui/elemento_form_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ElementosTab extends StatefulWidget {
  final PedidoModel pedido;
  const ElementosTab({required this.pedido, super.key});

  @override
  State<ElementosTab> createState() => _ElementosTabState();
}

class _ElementosTabState extends State<ElementosTab> {
  @override
  void initState() {
    super.initState();
    elementoCtrl.onInit(widget.pedido.id);
  }

  String _fmt(double v) => NumberFormat('#,##0.000', 'pt_BR').format(v);

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<ElementoModel>>(
      stream: elementoCtrl.elementosStream.listen,
      builder: (_, elementos) {
        final validacao = elementoCtrl.getValidacaoBitola(widget.pedido);
        return Column(
          children: [
            const SizedBox(height: 8),

            // ── Botão adicionar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Elementos (${elementos.length})',
                    style: AppCss.mediumBold,
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryMain,
                          side: BorderSide(color: AppColors.primaryMain),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon:
                            const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Importar PDF'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (result != null &&
                              result.files.single.bytes != null) {
                            final res = await elementoCtrl.onImportPDF(
                                result.files.single.bytes!, widget.pedido);

                            if (!res['success'] && context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Resultado da Importação'),
                                  content: SizedBox(
                                    width: 500,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Erro: ${res['error']}',
                                              style: AppCss.mediumBold
                                                  .copyWith(color: Colors.red)),
                                          const SizedBox(height: 16),
                                          const Text(
                                              'Abaixo está o texto que o sistema conseguiu ler do PDF. Se estiver vazio ou ilegível, o PDF pode ser bloqueado ou ser uma imagem:'),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey.shade300),
                                            ),
                                            child: Text(
                                              res['rawText'].isEmpty
                                                  ? '(Nenhum texto extraído)'
                                                  : res['rawText'],
                                              style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Fechar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMain,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo Elemento'),
                        onPressed: () => showElementoFormDialog(
                          context,
                          pedido: widget.pedido,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão de Comparativo (Status)
                      InkWell(
                        onTap: () => showElementoComparativoDialog(
                          context,
                          validacao: validacao,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: validacao.isOk
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: validacao.isOk
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                validacao.isOk
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_rounded,
                                color: validacao.isOk ? Colors.green : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Comparativo',
                                style: AppCss.smallBold.copyWith(
                                  color: validacao.isOk
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Lista de elementos ────────────────────────────────────────
            if (elementos.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Nenhum elemento cadastrado',
                          style: AppCss.mediumRegular
                              .copyWith(color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text('Clique em "Novo Elemento" para começar',
                          style: AppCss.smallRegular
                              .copyWith(color: Colors.grey[400])),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: elementos.length,
                  separatorBuilder: (_, __) => const Divisor(),
                  itemBuilder: (_, i) => _ElementoTile(
                    elemento: elementos[i],
                    pedido: widget.pedido,
                    fmt: _fmt,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── TILE DE ELEMENTO ─────────────────────────────────────────────────────────
class _ElementoTile extends StatefulWidget {
  final ElementoModel elemento;
  final PedidoModel pedido;
  final String Function(double) fmt;
  const _ElementoTile(
      {required this.elemento, required this.pedido, required this.fmt});

  @override
  State<_ElementoTile> createState() => _ElementoTileState();
}

class _ElementoTileState extends State<_ElementoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final el = widget.elemento;
    return Column(
      children: [
        // ── Linha do elemento ─────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.neutralDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(el.nome, style: AppCss.mediumBold),
                      Text(
                        '${el.posicoes.length} posição(ões) · ${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.smallRegular
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Peso total em destaque
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.fmt(el.pesoTotal)} kg',
                    style: AppCss.mediumBold
                        .setColor(AppColors.primaryMain),
                  ),
                ),
                const SizedBox(width: 8),
                // Ações
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await showElementoFormDialog(context,
                          pedido: widget.pedido, elemento: el);
                    } else if (action == 'delete') {
                      await elementoCtrl.onDeleteElemento(el);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Editar')
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir',
                              style: TextStyle(color: Colors.red))
                        ])),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Posições expandidas ───────────────────────────────────────────
        if (_expanded)
          Container(
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Cabeçalho das colunas
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('Posição',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 2,
                          child: Text('OS',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 2,
                          child: Text('Bitola',
                              style: AppCss.smallBold.copyWith(
                                  color: Colors.grey[500]))),
                      Expanded(
                          flex: 1,
                          child: Text('Peso (kg)',
                              style: AppCss.smallBold
                                  .copyWith(color: Colors.grey[500]),
                              textAlign: TextAlign.end)),
                    ],
                  ),
                ),
                const Divisor(),
                ...el.posicoes.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(p.nome,
                                  style: AppCss.smallRegular)),
                          Expanded(
                              flex: 2,
                              child: Text(p.numeroOs,
                                  style: AppCss.smallRegular)),
                          Expanded(
                            flex: 2,
                            child: Text(
                              p.produto?.labelMinified ?? p.produtoId,
                              style: AppCss.smallRegular,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              widget.fmt(p.pesoKg),
                              style: AppCss.smallBold
                                  .setColor(AppColors.primaryMain),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
                // Subtotal
                const Divisor(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Subtotal: ',
                          style: AppCss.smallBold
                              .copyWith(color: Colors.grey[600])),
                      Text(
                        '${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.mediumBold
                            .setColor(AppColors.primaryMain),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
