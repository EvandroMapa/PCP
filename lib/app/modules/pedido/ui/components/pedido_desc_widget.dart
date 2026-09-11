import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/item_label.dart';
import 'package:aco_plus/app/core/components/row_itens_label.dart';
import 'package:aco_plus/app/core/enums/obra_status.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/cliente/ui/cliente_create_simplify_bottom.dart';
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
              Expanded(child: _clienteLabel(context)),
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

  void _abrirDialogTrocarCliente(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _TrocarClienteDialog(pedido: pedido),
    );
  }

  /// Label do cliente com lápis de edição para trocar o cliente e a obra
  Widget _clienteLabel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cliente',
              style: AppCss.minimumBold.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: AppColors.black.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () => _abrirDialogTrocarCliente(context),
              child: Icon(Icons.edit, size: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        Text(
          pedido.cliente.nome.isEmpty ? 'Sem cliente' : pedido.cliente.nome,
          style: AppCss.minimumRegular.setSize(13).setColor(AppColors.black),
        ),
      ],
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
    final filhosReais = widget.pedido.getPedidosFilhos();
    if (widget.pedido.isMestre && filhosReais.isNotEmpty) {
      final continuar = await _avisarAlteracaoEmParciais(
        filhosReais.length,
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

// ── Dialog de troca de cliente e obra do pedido ───────────────────────────────

class _TrocarClienteDialog extends StatefulWidget {
  final PedidoModel pedido;
  const _TrocarClienteDialog({required this.pedido});

  @override
  State<_TrocarClienteDialog> createState() => _TrocarClienteDialogState();
}

class _TrocarClienteDialogState extends State<_TrocarClienteDialog> {
  ClienteModel? _clienteSelecionado;
  ObraModel? _obraSelecionada;
  final TextEditingController _buscaCtrl = TextEditingController();
  final FocusNode _buscaFocus = FocusNode();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _buscaFocus.dispose();
    super.dispose();
  }

  List<ClienteModel> get _clientesFiltrados {
    final todos = List<ClienteModel>.from(BackendClient.clientes.data)
      ..sort((a, b) =>
          a.nome.trim().toLowerCase().compareTo(b.nome.trim().toLowerCase()));
    final query = _buscaCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return todos;
    final queryLimpa = query.replaceAll(RegExp(r'[^0-9]'), '');
    return todos.where((c) {
      final nome = c.nome.toLowerCase();
      final cod = c.codigo.toString();
      final cpf = c.cpf.replaceAll(RegExp(r'[^0-9]'), '');
      return nome.contains(query) ||
          cod.contains(query) ||
          (queryLimpa.isNotEmpty && cpf.contains(queryLimpa));
    }).toList();
  }

  void _selecionarCliente(ClienteModel cliente) {
    setState(() {
      _clienteSelecionado = cliente;
      _buscaCtrl.clear();
      if (cliente.obras.length == 1) {
        _obraSelecionada = cliente.obras.first;
      } else {
        _obraSelecionada = null;
      }
    });
    _buscaFocus.unfocus();
  }

  Future<void> _cadastrarNovoCliente() async {
    final novo = await showClienteCreateSimplifyBottom();
    if (novo != null) {
      setState(() {
        _clienteSelecionado = novo;
        _obraSelecionada = novo.obras.firstOrNull;
        _buscaCtrl.clear();
      });
    }
  }

  Future<void> _adicionarNovaObra() async {
    if (_clienteSelecionado == null) return;
    final nomeObraCtrl = TextEditingController();
    final criada = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cadastrar Nova Obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${_clienteSelecionado!.nome}',
              style: AppCss.minimumBold.setColor(Colors.grey[700]!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nomeObraCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nome da Obra *',
                hintText: 'Ex: Residencial Parque Sul',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomeObraCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );

    if (criada == true && nomeObraCtrl.text.trim().isNotEmpty) {
      final nova = ObraModel(
        id: HashService.get,
        descricao: nomeObraCtrl.text.trim(),
        telefoneFixo: '',
        endereco: EnderecoModel.empty(),
        status: ObraStatus.emAndamento,
      );
      await ClienteSupabaseCollection().addObra(nova, _clienteSelecionado!.id);
      setState(() {
        _clienteSelecionado!.obras.add(nova);
        _obraSelecionada = nova;
      });
      NotificationService.showPositive(
        'Obra Cadastrada',
        'Nova obra vinculada com sucesso.',
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> _salvar() async {
    if (_clienteSelecionado == null) {
      NotificationService.showNegative(
        'Cliente obrigatório',
        'Por favor, selecione o novo cliente.',
        position: NotificationPosition.bottom,
      );
      return;
    }
    if (_obraSelecionada == null) {
      NotificationService.showNegative(
        'Obra obrigatória',
        'Por favor, selecione a obra do novo cliente para este pedido.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    final filhosReais = widget.pedido.getPedidosFilhos();
    if (widget.pedido.isMestre && filhosReais.isNotEmpty) {
      final confirmar = await _avisarAlteracaoEmParciais(filhosReais.length);
      if (confirmar != true) return;
    }

    setState(() => _salvando = true);
    try {
      // 1. Atualiza no pedido principal
      widget.pedido.cliente = _clienteSelecionado!;
      widget.pedido.obra = _obraSelecionada!;

      // 2. Se for mestre, propaga para todos os parciais
      if (widget.pedido.isMestre) {
        for (final filho in filhosReais) {
          filho.cliente = _clienteSelecionado!;
          filho.obra = _obraSelecionada!;
          await BackendClient.pedidos.update(filho);
        }
      }

      // 3. Salva o pedido no banco
      pedidoCtrl.updatePedidoFirestore();

      NotificationService.showPositive(
        'Cliente e Obra Alterados',
        'O pedido foi atualizado com sucesso.',
        position: NotificationPosition.bottom,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao trocar cliente',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool?> _avisarAlteracaoEmParciais(int qtd) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
        title: const Text('Pedido Mestre'),
        content: Text(
          'Este pedido possui $qtd parcial${qtd > 1 ? 'is' : ''} que '
          'compartilham este cliente e obra. Ao trocar, '
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filhosReais = widget.pedido.getPedidosFilhos();
    final bool podeSalvar = _clienteSelecionado != null &&
        _obraSelecionada != null &&
        !(_clienteSelecionado!.id == widget.pedido.cliente.id &&
            _obraSelecionada!.id == widget.pedido.obra.id);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Trocar Cliente do Pedido',
                      style:
                          AppCss.mediumBold.setSize(16).setColor(Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Dados Atuais
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VÍNCULO ATUAL DO PEDIDO:',
                            style: AppCss.minimumBold
                                .setSize(11)
                                .setColor(Colors.grey[600]!),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 15, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.pedido.cliente.nome,
                                  style: AppCss.mediumBold
                                      .setSize(13)
                                      .setColor(Colors.grey[900]!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.business_outlined,
                                  size: 15, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.pedido.obra.descricao,
                                  style: AppCss.minimumRegular
                                      .setSize(12)
                                      .setColor(Colors.grey[700]!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── SEÇÃO 1: NOVO CLIENTE ─────────────────────────────
                    Text(
                      '1. NOVO CLIENTE *',
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(Colors.grey[600]!),
                    ),
                    const SizedBox(height: 6),

                    if (_clienteSelecionado == null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _buscaCtrl,
                              focusNode: _buscaFocus,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar cliente por nome ou CPF...',
                                hintStyle: AppCss.minimumRegular
                                    .setSize(13)
                                    .setColor(Colors.grey[400]!),
                                prefixIcon: Icon(Icons.search,
                                    size: 18, color: Colors.grey[500]),
                                suffixIcon: _buscaCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () => _buscaCtrl.clear(),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: AppColors.primaryMain, width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _cadastrarNovoCliente,
                            icon: const Icon(Icons.person_add_alt_1, size: 16),
                            label: const Text('Novo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMain,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Lista de clientes filtrados com altura fixa
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _clientesFiltrados.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum cliente encontrado.',
                                  style: AppCss.minimumRegular
                                      .setSize(13)
                                      .setColor(Colors.grey[500]!),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _clientesFiltrados.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.grey[100],
                                ),
                                itemBuilder: (_, i) {
                                  final c = _clientesFiltrados[i];
                                  final ehAtual =
                                      c.id == widget.pedido.cliente.id;
                                  return InkWell(
                                    onTap: () => _selecionarCliente(c),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: AppColors
                                                .primaryMain
                                                .withValues(alpha: 0.1),
                                            child: Text(
                                              c.nome.isNotEmpty
                                                  ? c.nome[0].toUpperCase()
                                                  : '?',
                                              style: AppCss.minimumBold
                                                  .setSize(11)
                                                  .setColor(
                                                      AppColors.primaryMain),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.nome,
                                                  style: AppCss.minimumBold
                                                      .setSize(13)
                                                      .setColor(
                                                          Colors.grey[900]!),
                                                ),
                                                Text(
                                                  '${c.obras.length} obra(s) cadastrada(s)${c.cpf.isNotEmpty && c.cpf != 'cpf' ? ' • ${c.cpf}' : ''}',
                                                  style: AppCss.minimumRegular
                                                      .setSize(11)
                                                      .setColor(
                                                          Colors.grey[500]!),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (ehAtual)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Atual',
                                                style: AppCss.minimumBold
                                                    .setSize(10)
                                                    .setColor(
                                                        Colors.grey[700]!),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      // Card do cliente selecionado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryMain.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 20, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _clienteSelecionado!.nome,
                                    style: AppCss.mediumBold
                                        .setSize(14)
                                        .setColor(Colors.grey[900]!),
                                  ),
                                  Text(
                                    '${_clienteSelecionado!.obras.length} obra(s) cadastrada(s)',
                                    style: AppCss.minimumRegular
                                        .setSize(12)
                                        .setColor(Colors.grey[600]!),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _clienteSelecionado = null;
                                  _obraSelecionada = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primaryMain
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.swap_horiz,
                                        size: 16,
                                        color: AppColors.primaryMain),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Trocar',
                                      style: AppCss.minimumBold
                                          .setSize(12)
                                          .setColor(AppColors.primaryMain),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── SEÇÃO 2: NOVA OBRA ────────────────────────────────
                    if (_clienteSelecionado != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '2. NOVA OBRA DO CLIENTE *',
                              style: AppCss.minimumBold
                                  .setSize(11)
                                  .setColor(Colors.grey[600]!),
                            ),
                          ),
                          if (_clienteSelecionado!.obras.isNotEmpty)
                            InkWell(
                              onTap: _adicionarNovaObra,
                              child: Text(
                                '+ Nova Obra',
                                style: AppCss.minimumBold
                                    .setSize(11)
                                    .setColor(AppColors.primaryMain),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_clienteSelecionado!.obras.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 18, color: Colors.orange[800]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Este cliente não possui obras cadastradas.',
                                      style: AppCss.minimumBold
                                          .setSize(12)
                                          .setColor(Colors.orange[900]!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _adicionarNovaObra,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Cadastrar Obra para este Cliente'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_clienteSelecionado!.obras.length == 1) ...[
                        // Obra única
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _obraSelecionada?.descricao ??
                                      _clienteSelecionado!.obras.first.descricao,
                                  style: AppCss.mediumBold
                                      .setSize(13)
                                      .setColor(Colors.green[900]!),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Obra única',
                                  style: AppCss.minimumBold
                                      .setSize(10)
                                      .setColor(Colors.green[800]!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Múltiplas obras: Dropdown elegante
                        DropdownButtonFormField<ObraModel>(
                          initialValue: _obraSelecionada,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Selecione a obra deste cliente...',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey[350]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey[350]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppColors.primaryMain, width: 2),
                            ),
                          ),
                          items: _clienteSelecionado!.obras
                              .map(
                                (o) => DropdownMenuItem<ObraModel>(
                                  value: o,
                                  child: Text(
                                    o.descricao,
                                    style: AppCss.mediumBold
                                        .setSize(13)
                                        .setColor(Colors.grey[900]!),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (obra) {
                            setState(() => _obraSelecionada = obra);
                          },
                        ),
                      ],
                    ],

                    // Aviso Mestre
                    if (widget.pedido.isMestre &&
                        filhosReais.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: Colors.blue[800]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Atenção: Este pedido possui ${filhosReais.length} parcial(is) que também serão atualizados com o novo cliente e a nova obra.',
                                style: AppCss.minimumRegular
                                    .setSize(12)
                                    .setColor(Colors.blue[900]!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.grey[700],
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_salvando || !podeSalvar) ? null : _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirmar Troca'),
        ),
      ],
    );
  }
}

