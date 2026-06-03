import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/extensions/text_controller_ext.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/view_models/pedido_bitola_view_model.dart';
import 'package:flutter/material.dart';

Future<double?> showPedidoOrderEditBottom(
  PedidoBitolaCreateModel produto,
  double? qtdeDisponivel,
) async =>
    showModalBottomSheet(
      backgroundColor: AppColors.white,
      context: contextGlobal,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PedidoOrderEditBottom(produto, qtdeDisponivel),
    );

class PedidoOrderEditBottom extends StatefulWidget {
  final PedidoBitolaCreateModel produto;
  final double? qtdeDisponivel;
  const PedidoOrderEditBottom(this.produto, this.qtdeDisponivel, {super.key});

  @override
  State<PedidoOrderEditBottom> createState() => _PedidoOrderEditBottomState();
}

class _PedidoOrderEditBottomState extends State<PedidoOrderEditBottom> {
  final TextController qtdeEC = TextController();

  @override
  void initState() {
    qtdeEC.text = widget.produto.qtde.text;
    super.initState();
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;
    return BottomSheet(
      onClosing: () {},
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: keyboardPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight * 0.45),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
              const H(16),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(EdgeInsets.all(16)),
                      backgroundColor: WidgetStatePropertyAll(AppColors.white),
                      foregroundColor: WidgetStatePropertyAll(AppColors.black),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_backspace),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Editar Bitola', style: AppCss.largeBold),
                    const H(16),
                    AppDropDown<BitolaModel>(
                      label: 'Bitola',
                      disable: true,
                      controller: widget.produto.produtoEC,
                      nextFocus: widget.produto.qtde.focus,
                      item: widget.produto.produtoModel!,
                      itens: [widget.produto.produtoModel!],
                      itemLabel: (e) => e.descricao,
                      onSelect: (e) {},
                    ),
                    const H(8),
                    AppField(
                      label: 'Quantidade',
                      type: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      controller: qtdeEC,
                      action: TextInputAction.done,
                      suffixText: 'Kg',
                      onChanged: (_) => setState(() {}),
                      onEditingComplete: () {
                        if (qtdeEC.doubleValue <= 0) return;
                        if (widget.qtdeDisponivel != null &&
                            qtdeEC.doubleValue > widget.qtdeDisponivel!) {
                          NotificationService.showNegative(
                              'Quantidade indisponível',
                              'A quantidade disponível é de ${widget.qtdeDisponivel!.toStringAsFixed(3)}Kg');
                          return;
                        }
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context, qtdeEC.doubleValue);
                      },
                    ),
                    if (widget.qtdeDisponivel != null)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Spacer(),
                            Text(
                              'Quantidade disponível: ${widget.qtdeDisponivel!.toStringAsFixed(3)}Kg',
                              style: AppCss.minimumRegular.copyWith(
                                color: qtdeEC.doubleValue > widget.qtdeDisponivel!
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontWeight:
                                    qtdeEC.doubleValue > widget.qtdeDisponivel!
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const H(16),
                    AppTextButton(
                      isEnable: qtdeEC.doubleValue > 0,
                      label: 'Confirmar',
                      onPressed: () {
                        if (widget.qtdeDisponivel == null ||
                            qtdeEC.doubleValue <= widget.qtdeDisponivel!) {
                          Navigator.pop(context, qtdeEC.doubleValue);
                        } else {
                          NotificationService.showNegative(
                              'Quantidade indisponível',
                              'A quantidade disponível é de ${widget.qtdeDisponivel!.toStringAsFixed(3)}Kg');
                        }
                      },
                    ),
                    const H(16),
                  ],
                ),
              ),
            ],
            ),  // ListView
          ),    // Container
        ),      // ConstrainedBox
      ),        // Padding
    );          // BottomSheet
  }
}
