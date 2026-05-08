import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/item_label.dart';
import 'package:aco_plus/app/core/components/row_itens_label.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/endereco/endereco_create_page.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:url_launcher/url_launcher.dart';

class PedidoDescWidget extends StatelessWidget {
  final PedidoModel pedido;
  const PedidoDescWidget(this.pedido, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ItemLabel('Cliente', pedido.cliente.nome)),
              Expanded(child: _obraLabel(context)),
            ],
          ),
          const H(16),
          RowItensLabel([
            ItemLabel(
              'Descrição',
              pedido.descricao.isEmpty ? 'Sem descrição' : pedido.descricao,
            ),
            if (pedido.deliveryAt != null)
              ItemLabel(
                'Previsão de Entrega',
                pedido.deliveryAt!.text(),
                isEditable: true,
                onDelete: () async {
                  pedido.deliveryAt = null;
                  pedidoCtrl.updatePedidoFirestore();
                  NotificationService.showPositive(
                    'Previsão de Entrega Removida',
                    'A previsão de entrega foi removida com sucesso',
                  );
                },
                onEdit: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: pedido.deliveryAt!,
                  );
                  if (date != null) {
                    pedido.deliveryAt = date;
                    pedidoCtrl.updatePedidoFirestore();
                    NotificationService.showPositive(
                      'Previsão de Entrega Alterada',
                      'A previsão de entrega foi alterada com sucesso',
                    );
                  }
                },
              ),
          ]),
          const H(16),
          RowItensLabel([
            ItemLabel('Planilhamento', pedido.planilhamento),
            if (pedido.romaneio != null)
              ItemLabel('ROMANEIO', pedido.romaneio!),
          ]),
        ],
      ),
    );
  }

  void _abrirDialogEditarObra(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditarObraDialog(pedido: pedido),
    );
  }

  /// Label da obra com lápis de edição + ícone do Google Maps
  Widget _obraLabel(BuildContext context) {
    final temEndereco = pedido.obra.endereco != null;
    final nomeObra = pedido.obra.endereco?.localidade != null &&
            pedido.obra.endereco!.localidade.isNotEmpty
        ? '${pedido.obra.descricao} - ${pedido.obra.endereco!.localidade.toUpperCase()}'
        : pedido.obra.descricao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Obra',
              style: AppCss.minimumBold.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: AppColors.black.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () => _abrirDialogEditarObra(context),
              child: Icon(Icons.edit, size: 14, color: Colors.grey[700]),
            ),
            if (temEndereco) const SizedBox(width: 5),
            if (temEndereco)
              Tooltip(
                message: 'Localização da obra',
                preferBelow: false,
                waitDuration: const Duration(milliseconds: 300),
                child: PopupMenuButton<String>(
                  onSelected: (opcao) => _onMenuMaps(opcao),
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.red[600],
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'maps',
                      child: Row(
                        children: [
                          Icon(Icons.map_outlined, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 10),
                          const Text('Abrir no Google Maps'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat, size: 18, color: Colors.green[600]),
                          const SizedBox(width: 10),
                          const Text('Enviar pelo WhatsApp'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copiar',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 10),
                          const Text('Copiar link'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Text(
          nomeObra,
          style: AppCss.minimumRegular.setSize(13).setColor(AppColors.black),
        ),
      ],
    );
  }

  /// Monta a URL do Google Maps para o endereço da obra.
  String? _montarUrlMaps() {
    final end = pedido.obra.endereco;
    if (end == null) return null;

    if (end.lat != 0.0 && end.lon != 0.0) {
      return 'https://www.google.com/maps/search/?api=1&query=${end.lat},${end.lon}';
    }

    final partes = [
      end.logradouro,
      end.numero,
      end.bairro,
      end.localidade,
      end.estado,
    ].where((p) => p.isNotEmpty).join(', ');

    if (partes.isEmpty) return null;
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(partes)}';
  }

  Future<void> _onMenuMaps(String opcao) async {
    final url = _montarUrlMaps();
    if (url == null) return;

    switch (opcao) {
      case 'maps':
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        break;

      case 'whatsapp':
        final mensagem = _montarMensagemWhatsApp(url);
        final waUrl = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(mensagem)}';
        await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
        break;

      case 'copiar':
        await Clipboard.setData(ClipboardData(text: url));
        NotificationService.showPositive(
          'Link copiado',
          'Link do Google Maps copiado para a área de transferência',
          position: NotificationPosition.bottom,
        );
        break;
    }
  }

  String _montarMensagemWhatsApp(String urlMaps) {
    final linhas = <String>[];

    linhas.add('🏗️ *ENTREGA DE OBRA*');
    linhas.add('');

    if (pedido.localizador.isNotEmpty) {
      linhas.add('📋 *Pedido:* ${pedido.localizador}');
    }
    linhas.add('🏢 *Obra:* ${pedido.obra.descricao}');
    linhas.add('👤 *Cliente:* ${pedido.cliente.nome}');

    if (pedido.cliente.telefone.isNotEmpty &&
        pedido.cliente.telefone != 'fone') {
      linhas.add('📞 *Tel. Cliente:* ${pedido.cliente.telefone}');
    }
    if (pedido.obra.telefoneFixo.isNotEmpty &&
        pedido.obra.telefoneFixo != 'fone') {
      linhas.add('📱 *Tel. Obra:* ${pedido.obra.telefoneFixo}');
    }

    if (pedido.instrucoesEntrega.isNotEmpty) {
      linhas.add('');
      linhas.add('📝 *Instruções de entrega:*');
      linhas.add(pedido.instrucoesEntrega);
    }

    linhas.add('');
    linhas.add('📍 *Localização:*');
    linhas.add(urlMaps);

    return linhas.join('\n');
  }
}


// ── Dialog de edição da obra ─────────────────────────────────────────────────

class _EditarObraDialog extends StatefulWidget {
  final PedidoModel pedido;
  const _EditarObraDialog({required this.pedido});

  @override
  State<_EditarObraDialog> createState() => _EditarObraDialogState();
}

class _EditarObraDialogState extends State<_EditarObraDialog> {
  late final TextEditingController _descricaoCtrl;
  EnderecoModel? _endereco;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(text: widget.pedido.obra.descricao);
    _endereco = widget.pedido.obra.endereco;
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    super.dispose();
  }

  String get _enderecoLabel {
    if (_endereco == null) return 'Sem endereço';
    if (_endereco!.localidade.isEmpty && _endereco!.logradouro.isEmpty) {
      return 'Sem endereço';
    }
    if (_endereco!.localidade.isNotEmpty) {
      return '${_endereco!.logradouro.isNotEmpty ? '${_endereco!.logradouro}, ' : ''}${_endereco!.localidade} - ${_endereco!.estado.toUpperCase()}';
    }
    return _endereco!.logradouro;
  }

  Future<void> _editarEndereco() async {
    final novoEndereco = await push(
      context,
      EnderecoCreatePage(endereco: _endereco),
    );
    if (novoEndereco != null && novoEndereco is EnderecoModel) {
      setState(() => _endereco = novoEndereco);
    }
  }

  Future<void> _salvar() async {
    final descricao = _descricaoCtrl.text.trim();
    if (descricao.isEmpty) {
      NotificationService.showNegative(
        'Campo obrigatório',
        'A descrição da obra não pode ser vazia.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    // Caso 2: editar dados da obra de pedido mestre
    // Como parciais compartilham a mesma obraId, a alteração reflete em todos
    if (widget.pedido.isMestre && widget.pedido.pedidosFilhos.isNotEmpty) {
      final continuar = await _avisarAlteracaoEmParciais(
        widget.pedido.pedidosFilhos.length,
      );
      if (continuar != true) return;
    }

    setState(() => _salvando = true);
    try {
      await pedidoCtrl.onUpdateObraCompleto(
        widget.pedido,
        descricao: descricao,
        endereco: _endereco,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Avisa que a obra é compartilhada com parciais e pede confirmação.
  Future<bool?> _avisarAlteracaoEmParciais(int qtd) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
        title: const Text('Pedido Mestre'),
        content: Text(
          'Este pedido possui $qtd parcial${qtd > 1 ? 'is' : ''} que '
          'compartilham esta obra. Ao alterar a descrição ou o endereço, '
          'as mudanças serão refletidas em todos eles.\n\nDeseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryMain,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Editar Obra',
                  style: AppCss.mediumBold.setSize(16).setColor(Colors.white),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo descrição
                Text(
                  'DESCRIÇÃO',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(Colors.grey[500]!),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descricaoCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style:
                      AppCss.mediumBold.setSize(14).setColor(Colors.grey[900]!),
                  decoration: InputDecoration(
                    hintText: 'Ex: Residencial São José',
                    hintStyle: AppCss.mediumBold
                        .setSize(14)
                        .setColor(Colors.grey[400]!),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[350]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[350]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.primaryMain, width: 2),
                    ),
                    suffixIcon: Icon(Icons.edit,
                        size: 16, color: AppColors.primaryMain),
                  ),
                ),

                const SizedBox(height: 16),

                // Campo endereço
                Text(
                  'ENDEREÇO',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(Colors.grey[500]!),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _editarEndereco,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _enderecoLabel,
                            style: AppCss.mediumBold.setSize(13).setColor(
                                  _enderecoLabel == 'Sem endereço'
                                      ? Colors.grey[400]!
                                      : Colors.grey[800]!,
                                ),
                          ),
                        ),
                        Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.primaryMain),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
