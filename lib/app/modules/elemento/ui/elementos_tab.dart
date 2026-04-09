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
import 'package:flutter/services.dart';
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
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          backgroundColor: AppColors.secondary.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.1))),
                        ),
                        icon:
                            const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Importar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (result != null &&
                              result.files.single.bytes != null) {
                            _showProgressDialog(context);
                            final res = await elementoCtrl.onImportPDF(
                                result.files.single.bytes!, widget.pedido);
                            
                            if (mounted) Navigator.pop(context); // Fecha progresso

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
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                    'Erro: ${res['error']}',
                                                    style: AppCss.mediumBold
                                                        .copyWith(
                                                            color: Colors.red)),
                                              ),
                                              IconButton(
                                                tooltip: 'Copiar Texto',
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(
                                                      text: res['rawText']));
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Texto copiado!')),
                                                  );
                                                },
                                                icon: const Icon(Icons.copy,
                                                    size: 18),
                                              ),
                                            ],
                                          ),
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
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primaryMain,
                                        textStyle: AppCss.mediumBold,
                                      ),
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
                      // Botão Borracha (Apagar Tudo)
                      StreamOut<List<ElementoModel>>(
                        stream: elementoCtrl.elementosStream.listen,
                        builder: (_, elementos) {
                          if (elementos.isEmpty) return const SizedBox();
                          return Tooltip(
                            message: 'Apagar todos os elementos',
                            child: InkWell(
                              onTap: () async {
                                if (await showConfirmDialog(
                                  'Apagar TODOS os elementos?',
                                  'Esta ação não pode ser desfeita. Deseja continuar?',
                                )) {
                                  await elementoCtrl.onDeleteAllElementos(widget.pedido.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: const Icon(Icons.auto_fix_normal_rounded,
                                    color: Colors.red, size: 18),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMain,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.primaryMain.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Novo Elemento', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: elementos.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ElementoTile(
                      elemento: elementos[i],
                      pedido: widget.pedido,
                      fmt: _fmt,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StreamOut<ImportProgress?>(
        stream: elementoCtrl.importProgressStream.listen,
        builder: (_, progress) {
          final p = progress;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_upload_rounded,
                        color: AppColors.secondary, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    p?.status ?? 'Iniciando importação...',
                    style: AppCss.mediumBold,
                    textAlign: TextAlign.center,
                  ),
                  if (p != null && p.total > 0) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: p.percent,
                        minHeight: 8,
                        backgroundColor: AppColors.secondary.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(p.percent * 100).toInt()}% concluído',
                      style: AppCss.minimumRegular
                          .copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    elementoCtrl.cancelImport();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar Importação',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Linha do elemento ─────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Indicador lateral
                  Container(
                    width: 4,
                    color: AppColors.primaryMain.withOpacity(_expanded ? 1.0 : 0.3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(el.nome, style: AppCss.mediumBold.setSize(16)),
                              if (el.qtde > 1)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMain.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('x${el.qtde}',
                                      style: AppCss.minimumBold
                                          .setColor(AppColors.primaryMain)
                                          .setSize(11)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${el.posicoes.length} posição(ões) · Unit: ${widget.fmt(el.pesoUnitario)} kg',
                            style: AppCss.minimumRegular
                                .copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Peso total em destaque
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.fmt(el.pesoTotal)} kg',
                          style: AppCss.mediumBold
                              .setColor(AppColors.primaryMain)
                              .setSize(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Ações
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 20),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await showElementoFormDialog(context,
                            pedido: widget.pedido, elemento: el);
                      } else if (action == 'delete') {
                        await elementoCtrl.onDeleteElemento(el);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 12),
                            const Text('Editar')
                          ])),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 12),
                            const Text('Excluir',
                                style: TextStyle(color: Colors.red))
                          ])),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // ── Posições expandidas ───────────────────────────────────────────
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: Colors.grey.shade50.withOpacity(0.5),
              child: Column(
                children: [
                  const Divisor(height: 1),
                  const SizedBox(height: 12),
                  // Cabeçalho das colunas
                  Row(
                    children: [
                      _colHead('Posição', 2),
                      _colHead('OS', 2),
                      _colHead('Bitola', 3),
                      _colHead('Peso Un.', 2, isEnd: true),
                      _colHead('T. Item', 2, isEnd: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...el.posicoes.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text(p.nome,
                                    style: AppCss.minimumRegular)),
                            Expanded(
                                flex: 2,
                                child: Text(p.numeroOs,
                                    style: AppCss.minimumRegular.copyWith(color: Colors.grey[600]))),
                            Expanded(
                              flex: 3,
                              child: Text(
                                p.produto?.labelMinified ?? p.produtoId,
                                style: AppCss.minimumBold.setSize(12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${widget.fmt(p.pesoKg)}',
                                style: AppCss.minimumRegular,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${widget.fmt(p.pesoKg * el.qtde)}',
                                style: AppCss.minimumBold
                                    .setColor(AppColors.primaryMain),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      )),
                  // Subtotal
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Total do Elemento: ',
                          style: AppCss.minimumRegular
                              .copyWith(color: Colors.grey[600])),
                      Text(
                        '${widget.fmt(el.pesoTotal)} kg',
                        style: AppCss.mediumBold
                            .setColor(AppColors.primaryMain)
                            .setSize(15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

  Widget _colHead(String label, int flex, {bool isEnd = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppCss.minimumBold.copyWith(color: Colors.grey[400], fontSize: 11),
        textAlign: isEnd ? TextAlign.end : TextAlign.start,
      ),
    );
  }
}
