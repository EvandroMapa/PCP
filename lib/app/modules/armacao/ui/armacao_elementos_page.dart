import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/fullscreen_button.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class ArmacaoElementosPage extends StatefulWidget {
  final PedidoModel pedido;
  const ArmacaoElementosPage({required this.pedido, super.key});

  @override
  State<ArmacaoElementosPage> createState() => _ArmacaoElementosPageState();
}

class _ArmacaoElementosPageState extends State<ArmacaoElementosPage> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  // Filtros de visibilidade por status (Pronto oculto por padrão no Armador)
  final Map<ElementoStatus, bool> _statusVisivel = {
    ElementoStatus.aguardando: true,
    ElementoStatus.armando: true,
    ElementoStatus.pronto: false,
  };

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await armacaoCtrl.onFetchElementos(widget.pedido);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showImageDialog(ElementoModel elemento) async {
    if (elemento.arquivos.isEmpty) return;

    // 1. Restrição de Status: Desenho só visível em produção ou pronto
    if (elemento.status == ElementoStatus.aguardando) {
      showInfoDialog(
        'VISUALIZAÇÃO BLOQUEADA!\n\n'
        'O desenho técnico só fica disponível após o início da produção.\n\n'
        'Mude o status para "ARMANDO" para liberar a visualização.',
      );
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => _MediaViewerDialog(elemento: elemento),
    );
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
              style: AppCss.minimumRegular.setColor(AppColors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        actions: [
          FullscreenButton(),
          const SizedBox(width: 8),
        ],
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
          : StreamOut<List<PedidoModel>>(
              stream: AppSupabaseClient.pedidos.dataStream.listen,
              builder: (_, allPedidos) {
                // Busca a versão mais atualizada do pedido no stream global
                final currentPedido = allPedidos.firstWhere(
                  (p) => p.id == widget.pedido.id,
                  orElse: () => widget.pedido,
                );

                return Column(
                  children: [
                    _ResumoProducaoBar(
                      pedido: currentPedido,
                      statusVisivel: _statusVisivel,
                      onToggle: (status) => setState(() => _statusVisivel[status] = !(_statusVisivel[status] ?? true)),
                    ),
                    Expanded(
                      child: StreamOut<List<ElementoModel>>(
                        stream: armacaoCtrl.elementosStream.listen,
                        builder: (_, elementos) {
                          final filtrados = elementos.where((e) {
                            if (e.isProntoParcial) {
                              return (_statusVisivel[ElementoStatus.armando] ?? true) ||
                                     (_statusVisivel[ElementoStatus.pronto] ?? true);
                            }
                            return _statusVisivel[e.status] ?? true;
                          }).toList();
                          if (filtrados.isEmpty) {
                            return const EmptyData(message: 'Nenhum elemento visível com os filtros ativos.');
                          }
                          return Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: GridView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(24),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 350,
                                    mainAxisExtent: 160,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                                  itemCount: filtrados.length,
                                  itemBuilder: (context, index) {
                                    final elemento = filtrados[index];
                                    return _ElementoArmacaoCard(
                                      elemento: elemento,
                                      onStatusPressed: () async {
                                        if (elemento.qtde > 1) {
                                          await armacaoCtrl.openProgressoParcialDirect(currentPedido, elemento);
                                        } else {
                                          await _showStatusPicker(elemento);
                                        }
                                      },
                                      onImagePressed: () => _showImageDialog(elemento),
                                    );
                                  },
                                ),
                              );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _showStatusPicker(ElementoModel elemento) async {
    final allowedStatuses = <ElementoStatus>[];
    if (elemento.status == ElementoStatus.aguardando) {
      allowedStatuses.addAll([ElementoStatus.aguardando, ElementoStatus.armando]);
    } else if (elemento.status == ElementoStatus.armando) {
      allowedStatuses.addAll([ElementoStatus.aguardando, ElementoStatus.armando, ElementoStatus.pronto]);
    } else if (elemento.status == ElementoStatus.pronto) {
      allowedStatuses.addAll([ElementoStatus.armando, ElementoStatus.pronto]);
    }

    await showDialog(
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
  final Map<ElementoStatus, bool> statusVisivel;
  final ValueChanged<ElementoStatus> onToggle;
  const _ResumoProducaoBar({required this.pedido, required this.statusVisivel, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final resumo = pedido.armacaoResumo;
    final Map<String, dynamic> details = resumo.containsKey('details')
        ? resumo['details'] as Map<String, dynamic>
        : {
            'aguardando': {'qtd': 0, 'peso': 0.0, 'prcnt_qtd': 0.0, 'prcnt_peso': 0.0},
            'armando': {'qtd': 0, 'peso': 0.0, 'prcnt_qtd': 0.0, 'prcnt_peso': 0.0},
            'pronto': {'qtd': 0, 'peso': 0.0, 'prcnt_qtd': 0.0, 'prcnt_peso': 0.0},
          };
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: [
          _buildResumoItem('AGUARDANDO', ElementoStatus.aguardando, details['aguardando']),
          const SizedBox(width: 16),
          _buildResumoItem('ARMANDO', ElementoStatus.armando, details['armando']),
          const SizedBox(width: 16),
          _buildResumoItem('PRONTO', ElementoStatus.pronto, details['pronto']),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, ElementoStatus status, Map<String, dynamic> data) {
    final double prcntQtd = (data['prcnt_qtd'] ?? 0.0) * 100;
    final double prcntPeso = (data['prcnt_peso'] ?? 0.0) * 100;
    final bool isVisible = statusVisivel[status] ?? true;

    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isVisible ? status.backgroundColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isVisible ? Colors.black : Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: isVisible ? Colors.grey[800] : Colors.grey[400],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppCss.largeBold.setSize(15).setColor(Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onToggle(status),
                    child: Icon(
                      isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ELEMENTOS', style: AppCss.largeBold.setSize(12).setColor(isVisible ? Colors.black : Colors.grey[400]!)),
                      Text(
                        '${data['qtd']} (${prcntQtd.toStringAsFixed(0)}%)',
                        style: AppCss.largeBold.setSize(18).setColor(isVisible ? Colors.black : Colors.grey[400]!),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('PESO (KG)', style: AppCss.largeBold.setSize(12).setColor(isVisible ? Colors.black : Colors.grey[400]!)),
                      Text(
                        '${data['peso'].toStringAsFixed(1)} (${prcntPeso.toStringAsFixed(0)}%)',
                        style: AppCss.largeBold.setSize(18).setColor(isVisible ? Colors.black : Colors.grey[400]!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementoArmacaoCard extends StatelessWidget {
  final ElementoModel elemento;
  final VoidCallback onStatusPressed;
  final VoidCallback onImagePressed;

  const _ElementoArmacaoCard({
    required this.elemento,
    required this.onStatusPressed,
    required this.onImagePressed,
  });

  // Cor do card baseada no progresso real
  Color get _cardColor {
    if (elemento.status == ElementoStatus.pronto) return Colors.green[50]!;
    if (elemento.isProntoParcial) return Colors.green[50]!;
    return elemento.status.backgroundColor;
  }

  Color get _cardBorderColor {
    if (elemento.status == ElementoStatus.pronto) return Colors.green[700]!;
    if (elemento.isProntoParcial) return Colors.green[400]!;
    if (elemento.status == ElementoStatus.armando) return Colors.amber[700]!;
    return Colors.grey[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onStatusPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Text(
                  elemento.status.label.toUpperCase(),
                  style: AppCss.largeBold.setSize(22).setColor(Colors.black).copyWith(letterSpacing: 1.5),
                ),
              ),
            ),
            // Barra de progresso parcial dentro de um Container robusto
            if (elemento.qtde > 1 && elemento.qtdePronto > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: elemento.progressoPronto,
                        minHeight: 22,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          elemento.status == ElementoStatus.pronto
                              ? Colors.green[700]!
                              : Colors.green[500]!,
                        ),
                      ),
                    ),
                    Text(
                      '${elemento.qtdePronto} / ${elemento.qtde} PÇ PRONTAS',
                      style: AppCss.mediumBold.setSize(11).setColor(
                        elemento.progressoPronto > 0.5 ? Colors.white : Colors.green[900]!
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfo('QTDE', '${elemento.qtde} pç'),
                  _buildInfo('PESO', '${elemento.pesoTotal.toStringAsFixed(1)} kg'),
                  _buildInfo('OS', '${elemento.posicoes.length} os'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            elemento.nome.toUpperCase(),
            style: AppCss.largeBold.setSize(20).setColor(Colors.white),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (elemento.arquivos.isNotEmpty)
            Positioned(
              right: 0,
              child: GestureDetector(
                onTap: onImagePressed,
                child: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppCss.largeBold.setSize(15).setColor(Colors.black.withValues(alpha: 0.7)),
        ),
        Text(
          value,
          style: AppCss.largeBold.setSize(20).setColor(Colors.black),
        ),
      ],
    );
  }
}

class _MediaViewerDialog extends StatefulWidget {
  final ElementoModel elemento;
  const _MediaViewerDialog({required this.elemento});

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  int _currentIndex = 0;
  final Map<String, bool> _registeredFactories = {};

  @override
  Widget build(BuildContext context) {
    if (widget.elemento.arquivos.isEmpty) return const SizedBox();
    
    // Garantir bounds do currentIndex
    if (_currentIndex >= widget.elemento.arquivos.length) {
      _currentIndex = 0;
    }

    final currentArq = widget.elemento.arquivos[_currentIndex];
    final isPdf = currentArq.extensao.toLowerCase() == 'pdf' || currentArq.tipo.contains('pdf');

    Widget mainContent;

    if (isPdf) {
      final viewId = 'pdf-viewer-${currentArq.id}';
      if (!_registeredFactories.containsKey(viewId)) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewId,
          (int id) {
            final iframe = html.IFrameElement();
            iframe.src = currentArq.url;
            iframe.style.border = 'none';
            iframe.style.width = '100%';
            iframe.style.height = '100%';
            return iframe;
          },
        );
        _registeredFactories[viewId] = true;
      }
      mainContent = HtmlElementView(viewType: viewId);
    } else {
      mainContent = InteractiveViewer(
        minScale: 0.1,
        maxScale: 15.0,
        child: Image.network(
          currentArq.url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Text('Erro ao carregar imagem. Verifique sua conexão.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: mainContent),

          // Botão para Restaurar a tela (Voltar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: 'restore_image',
              onPressed: () => Navigator.pop(context),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              label: const Text(
                'RESTAURAR TELA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Galeria de Thumbnails caso haja mais de 1 anexo
          if (widget.elemento.arquivos.length > 1)
            Positioned(
              bottom: 40,
              left: 40,
              right: 40,
              child: Center(
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.elemento.arquivos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (ctx, i) {
                      final arq = widget.elemento.arquivos[i];
                      final arqIsPdf = arq.extensao.toLowerCase() == 'pdf' || arq.tipo.contains('pdf');
                      final isSelected = i == _currentIndex;

                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 66,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryMain : Colors.transparent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (arqIsPdf)
                                const Center(
                                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 36),
                                )
                              else
                                Image.network(arq.url, fit: BoxFit.cover),
                              if (!isSelected)
                                Container(color: Colors.white.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
