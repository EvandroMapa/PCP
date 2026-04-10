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
        backgroundColor: AppColors.secondary,
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
          : Column(
              children: [
                _ResumoProducaoBar(pedido: widget.pedido),
                Expanded(
                  child: widget.pedido.elementos.isEmpty
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
                              onPressed: () async {
                                await _showStatusPicker(elemento);
                                setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showStatusPicker(ElementoModel elemento) {
    // Regra: Não pode pular de Aguardando para Pronto e vice-versa. Tem que passar por Armando.
    final allowedStatuses = <ElementoStatus>[];
    if (elemento.status == ElementoStatus.aguardando) {
      allowedStatuses.addAll([ElementoStatus.aguardando, ElementoStatus.armando]);
    } else if (elemento.status == ElementoStatus.armando) {
      allowedStatuses.addAll([ElementoStatus.aguardando, ElementoStatus.armando, ElementoStatus.pronto]);
    } else if (elemento.status == ElementoStatus.pronto) {
      allowedStatuses.addAll([ElementoStatus.armando, ElementoStatus.pronto]);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ALTERAR STATUS: ${elemento.nome}',
                style: AppCss.mediumBold.setSize(18).setColor(AppColors.primaryMain),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'O fluxo deve obrigatoriamente passar por "Armando"',
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...allowedStatuses.map((status) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: elemento.status == status ? status.color : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  tileColor: elemento.status == status ? status.backgroundColor : Colors.transparent,
                  leading: CircleAvatar(
                    backgroundColor: status.color,
                    radius: 12,
                    child: elemento.status == status ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  title: Text(status.label, style: AppCss.mediumBold),
                  onTap: () async {
                    Navigator.pop(context);
                    await armacaoCtrl.updateElementoStatus(widget.pedido, elemento, status);
                    setState(() {});
                  },
                ),
              )),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCELAR', style: AppCss.mediumBold.setColor(Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoProducaoBar extends StatelessWidget {
  final PedidoModel pedido;
  const _ResumoProducaoBar({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final resumo = pedido.armacaoResumo;
    if (resumo.isEmpty) return const SizedBox.shrink();

    final details = resumo['details'] as Map<String, dynamic>;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: [
          _buildResumoItem(
            'AGUARDANDO',
            ElementoStatus.aguardando,
            details['aguardando'],
          ),
          const SizedBox(width: 16),
          _buildResumoItem(
            'ARMANDO',
            ElementoStatus.armando,
            details['armando'],
          ),
          const SizedBox(width: 16),
          _buildResumoItem(
            'PRONTO',
            ElementoStatus.pronto,
            details['pronto'],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, ElementoStatus status, Map<String, dynamic> data) {
    final double prcntQtd = (data['prcnt_qtd'] ?? 0.0) * 100;
    final double prcntPeso = (data['prcnt_peso'] ?? 0.0) * 100;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: status.color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: status.color, radius: 4),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppCss.minimumBold.setColor(status.color).setSize(11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elementos', style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[600]!)),
                    Text(
                      '${data['qtd']} (${prcntQtd.toStringAsFixed(0)}%)',
                      style: AppCss.mediumBold.setSize(13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Peso (Kg)', style: AppCss.minimumRegular.setSize(10).setColor(Colors.grey[600]!)),
                    Text(
                      '${data['peso'].toStringAsFixed(1)} (${prcntPeso.toStringAsFixed(0)}%)',
                      style: AppCss.mediumBold.setSize(13),
                    ),
                  ],
                ),
              ],
            ),
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
