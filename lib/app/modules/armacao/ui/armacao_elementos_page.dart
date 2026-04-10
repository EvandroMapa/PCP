import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:flutter/material.dart';

class ArmacaoElementosPage extends StatefulWidget {
  final PedidoModel pedido;
  const ArmacaoElementosPage({required this.pedido, super.key});

  @override
  State<ArmacaoElementosPage> createState() => _ArmacaoElementosPageState();
}

class _ArmacaoElementosPageState extends State<ArmacaoElementosPage> {
  bool _isLoading = true;

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    await armacaoCtrl.onFetchElementos(widget.pedido);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pedido.localizador,
              style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
            ),
            Text(
              widget.pedido.cliente.nome,
              style: AppCss.minimumRegular.setColor(AppColors.white.withOpacity(0.8)),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryMain,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Aguarde, carregando elementos...', style: AppCss.mediumRegular),
                ],
              ),
            )
          : widget.pedido.elementos.isEmpty
              ? const EmptyData(message: 'Nenhum elemento cadastrado!')
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: widget.pedido.elementos.length,
                  itemBuilder: (context, index) {
                    final elemento = widget.pedido.elementos[index];
                    return _ElementoArmacaoCard(
                      elemento: elemento,
                      onPressed: () => _showStatusPicker(elemento),
                    );
                  },
                ),
    );
  }

  void _showStatusPicker(ElementoModel elemento) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ALTERAR STATUS: ${elemento.nome}',
              style: AppCss.mediumBold.setSize(16),
            ),
            const SizedBox(height: 24),
            ...ElementoStatus.values.map((status) => ListTile(
                  leading: CircleAvatar(backgroundColor: status.color, radius: 12),
                  title: Text(status.label, style: AppCss.mediumBold),
                  selected: elemento.status == status,
                  onTap: () async {
                    Navigator.pop(context);
                    await armacaoCtrl.updateElementoStatus(widget.pedido, elemento, status);
                    setState(() {});
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _ElementoArmacaoCard extends StatelessWidget {
  final ElementoModel elemento;
  final VoidCallback onPressed;
  const _ElementoArmacaoCard({required this.elemento, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: elemento.status.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: elemento.status == ElementoStatus.aguardando 
                ? Colors.grey[200]! 
                : elemento.status.color.withOpacity(0.5), 
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  elemento.nome,
                  style: AppCss.largeBold.setSize(18).setColor(
                    elemento.status == ElementoStatus.aguardando 
                        ? AppColors.primaryMain 
                        : AppColors.primaryDark
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.scale_rounded, size: 18, color: Colors.grey[600]!),
                    const SizedBox(width: 8),
                    Text(
                      '${elemento.pesoTotal.toStringAsFixed(2)} kg',
                      style: AppCss.largeBold.setSize(18).setColor(Colors.grey[800]!),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 18, color: Colors.grey[600]!),
                    const SizedBox(width: 8),
                    Text(
                      '${elemento.posicoes.length} ETIQUETAS (OS)',
                      style: AppCss.mediumBold.setSize(14).setColor(Colors.grey[700]!),
                    ),
                  ],
                ),
                if (elemento.qtde > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Qtde: ${elemento.qtde}',
                        style: AppCss.mediumBold.setColor(AppColors.secondary).setSize(12),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: elemento.status.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  elemento.status.label.toUpperCase(),
                  style: AppCss.minimumBold.setColor(
                    elemento.status == ElementoStatus.armando ? Colors.black87 : Colors.white
                  ).setSize(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
