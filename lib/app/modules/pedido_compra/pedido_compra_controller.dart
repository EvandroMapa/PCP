import 'dart:typed_data';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/pedido_compra_create_page.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/pedido_compra_efetivar_page.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/relatorio/pedido_compra_compra_pdf.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/relatorio/pedido_compra_cotacao_pdf.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';

final pedidoCompraCtrl = PedidoCompraController();

class PedidoCompraController {
  static final PedidoCompraController _instance = PedidoCompraController._();
  PedidoCompraController._();
  factory PedidoCompraController() => _instance;

  final AppStream<PedidoCompraCreateModel> formStream =
      AppStream<PedidoCompraCreateModel>.seed(PedidoCompraCreateModel());
  PedidoCompraCreateModel get form => formStream.value;

  final AppStream<bool> showEfetivadosStream = AppStream<bool>.seed(false);
  bool get showEfetivados => showEfetivadosStream.value;

  void onInit() {
    formStream.add(PedidoCompraCreateModel());
    showEfetivadosStream.add(false);
    BackendClient.pedidosCompra.fetch();
  }

  Future<void> onCreate(BuildContext context) async {
    try {
      if (!form.isValid) {
        NotificationService.showNegative(
          'Campos obrigatórios',
          'Adicione pelo menos um item válido ao pedido',
          position: NotificationPosition.bottom,
        );
        return;
      }

      final usuarioNome = usuarioCtrl.usuario?.nome;
      // Fabricante placeholder vazio — será definido na confirmação
      const fabricanteIdVazio = '';

      if (form.modoEdicao) {
        // EDIÇÃO: apaga itens antigos e recria com mesmo grupoId
        final grupoId = form.grupoId!;
        final itensAntigos = BackendClient.pedidosCompra.data
            .where((e) => e.grupoId == grupoId)
            .toList();
        // Preserva o fabricanteId atual (não altera)
        final fabricanteIdAtual = itensAntigos.isNotEmpty
            ? itensAntigos.first.fabricanteId
            : fabricanteIdVazio;
        for (final item in itensAntigos) {
          await BackendClient.pedidosCompra.delete(item);
        }
        for (final item in form.itensValidos) {
          final pedido = PedidoCompraModel.novo(
            grupoId: grupoId,
            produtoId: item.produto!.id,
            fabricanteId: fabricanteIdAtual,
            quantidade: item.quantidadeValue,
            usuarioNome: usuarioNome,
          );
          await BackendClient.pedidosCompra.add(pedido);
        }
        NotificationService.showPositive(
          'Pedido atualizado',
          '${form.itensValidos.length} item${form.itensValidos.length > 1 ? 's' : ''} salvos',
          position: NotificationPosition.bottom,
        );
      } else {
        // CRIAÇÃO: novo grupoId
        final grupoId = HashService.get;
        for (final item in form.itensValidos) {
          final pedido = PedidoCompraModel.novo(
            grupoId: grupoId,
            produtoId: item.produto!.id,
            fabricanteId: fabricanteIdVazio,
            quantidade: item.quantidadeValue,
            usuarioNome: usuarioNome,
          );
          await BackendClient.pedidosCompra.add(pedido);
        }
        NotificationService.showPositive(
          'Pedido registrado',
          '${form.itensValidos.length} item${form.itensValidos.length > 1 ? 's' : ''} — selecione o fornecedor ao confirmar',
          position: NotificationPosition.bottom,
        );
      }

      form.clear();
      formStream.update();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao salvar pedido',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ── Iniciar edição de grupo pendente ─────────────────────────────────────

  void onIniciarEdicao(BuildContext context, List<PedidoCompraModel> itens) {
    final modelo = PedidoCompraCreateModel()
      ..grupoId = itens.first.grupoId;

    for (final item in itens) {
      final itemForm = PedidoCompraItemForm()
        ..produto = item.produto
        ..quantidade.text = item.quantidade.toStringAsFixed(3);
      modelo.itens.add(itemForm);
    }
    // Remove item vazio inicial
    modelo.itens.removeWhere((i) => i.produto == null);

    formStream.add(modelo);
    push(context, const PedidoCompraCreatePage());
  }

  // ── Excluir grupo pendente ────────────────────────────────────────────────

  Future<void> onExcluirGrupo(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    final fabricante = itens.first.fabricante.nome;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Pedido?'),
        content: Text(
          'O pedido de $fabricante com ${itens.length} '
          'item${itens.length > 1 ? 's' : ''} será excluído permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      for (final item in itens) {
        await BackendClient.pedidosCompra.delete(item);
      }
      NotificationService.showNegative(
        'Pedido excluído',
        fabricante,
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao excluir', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  // ── Voltar confirmado para pendente ───────────────────────────────────────

  Future<void> onVoltarParaPendente(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Voltar para Pendente?'),
        content: const Text(
          'O pedido voltara ao status de orcamento.\n'
          'O fornecedor e a data prevista serao removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Voltar para Pendente'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      for (final item in itens) {
        await BackendClient.pedidosCompra.update(
          item.copyWith(
            status: PedidoCompraStatus.pendente,
            clearDataPrevista: true,
            clearFabricante: true,
            clearNumeroPedido: true,
            updatedAt: DateTime.now(),
          ),
        );
      }
      NotificationService.showPending(
        'Pedido voltou para Pendente',
        'Fornecedor removido - selecione ao confirmar',
      );
    } catch (e) {
      NotificationService.showNegative('Erro', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  // ── Confirmar grupo (orçamento → pedido confirmado) ──────────────────────


  Future<void> onConfirmarGrupo(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    DateTime? dataPrevista;
    String? fabricanteId;
    String? fabricanteNome;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmarGrupoDialog(
        fabricanteAtualId: itens.first.fabricanteId,
        onFabricanteChanged: (id, nome) {
          fabricanteId = id;
          fabricanteNome = nome;
        },
        onDataChanged: (d) => dataPrevista = d,
      ),
    );

    if (confirmado != true) return;

    if (fabricanteId == null || fabricanteId!.isEmpty) {
      NotificationService.showNegative(
        'Fornecedor obrigatorio',
        'Selecione o fornecedor para confirmar o pedido',
        position: NotificationPosition.bottom,
      );
      return;
    }

    try {
      // Gera numero sequencial NNN/AA
      final numeroPedido = _gerarNumeroPedido();

      for (final item in itens) {
        await BackendClient.pedidosCompra.update(
          item.copyWith(
            status: PedidoCompraStatus.confirmado,
            fabricanteId: fabricanteId,
            dataPrevista: dataPrevista,
            numeroPedido: numeroPedido,
            updatedAt: DateTime.now(),
          ),
        );
      }

      NotificationService.showPositive(
        'Pedido $numeroPedido confirmado',
        '${fabricanteNome ?? ''} - ${itens.length} item${itens.length > 1 ? 's' : ''}',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao confirmar pedido',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Gera o proximo numero de pedido no formato NNN/AA
  /// Conta grupos distintos que ja possuem numero_pedido com o sufixo do ano atual
  String _gerarNumeroPedido() {
    final anoAtual = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final sufixo = '/$anoAtual';

    // Conta grupos unicos que ja tem numero de pedido neste ano
    final gruposComNumero = BackendClient.pedidosCompra.data
        .where((e) =>
            e.numeroPedido != null && e.numeroPedido!.endsWith(sufixo))
        .map((e) => e.grupoId)
        .toSet();

    final proximo = gruposComNumero.length + 1;
    return '${proximo.toString().padLeft(3, '0')}$sufixo';
  }

  // ── Gerar PDF de Cotação (somente Pendente) ───────────────────────────────

  Future<void> onGerarCotacao(
    BuildContext context,
    List<PedidoCompraModel> itens,
    FabricanteModel fabricante,
  ) async {
    try {
      NotificationService.showNeutral(
        'Gerando cotação…',
        'Aguarde',
        position: NotificationPosition.bottom,
      );
      final logoBytes = await LogoHelper.logoBytesForPdf();
      final pdfDoc = await PedidoCompraCotacaoPdfPage(
        itens: itens,
        fabricante: fabricante,
        nomeEmpresa: PreferencesService.nomeEmpresa.value,
        descricaoEmpresa: PreferencesService.descricaoEmpresa.value,
        usuarioNome: usuarioCtrl.usuario?.nome,
      ).build(logoBytes);
      final bytes = await pdfDoc.save();
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadPDF(
        'cotacao_${fabricante.nome.toLowerCase().replaceAll(' ', '_')}_$ts.pdf',
        '/pedido_compra/cotacao/',
        Uint8List.fromList(bytes),
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao gerar cotação',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ── Gerar PDF de Pedido de Compra (somente Confirmado) ───────────────────

  Future<void> onGerarPedidoCompra(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    try {
      NotificationService.showNeutral(
        'Gerando pedido de compra…',
        'Aguarde',
        position: NotificationPosition.bottom,
      );
      final fabricante = itens.first.fabricante;
      final logoBytes = await LogoHelper.logoBytesForPdf();
      final numero = itens.first.numeroPedido ?? itens.first.grupoId.substring(0, 8).toUpperCase();
      final pdfDoc = await PedidoCompraCompraPdfPage(
        itens: itens,
        fabricante: fabricante,
        nomeEmpresa: PreferencesService.nomeEmpresa.value,
        descricaoEmpresa: PreferencesService.descricaoEmpresa.value,
        usuarioNome: usuarioCtrl.usuario?.nome,
        numeroPedido: numero,
      ).build(logoBytes);
      final bytes = await pdfDoc.save();
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadPDF(
        'pedido_compra_${fabricante.nome.toLowerCase().replaceAll(' ', '_')}_$ts.pdf',
        '/pedido_compra/compra/',
        Uint8List.fromList(bytes),
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao gerar pedido de compra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ── Efetivar grupo: abre página de conferência ────────────────────────────

  void onEfetivarGrupo(BuildContext context, List<PedidoCompraModel> itens) {
    push(context, PedidoCompraEfetivarPage(itens: itens));
  }

  /// Chamado pela PedidoCompraEfetivarPage após o usuário confirmar
  Future<void> onEfetivarComModel(
    BuildContext context,
    PedidoCompraConverterGrupoModel model,
  ) async {
    try {
      final fabricante = model.itens.first.fabricante;
      int efetivados = 0;

      for (var i = 0; i < model.itens.length; i++) {
        final item = model.itens[i];
        final qtdeRecebida = model.getQuantidadeRecebida(i);
        if (qtdeRecebida <= 0) continue;

        await estoqueCtrl.onRegistrarCompraManual(
          produtoId: item.produtoId,
          quantidade: qtdeRecebida,
          observacao:
              'Compra de ${fabricante.nome} — Pedido #${item.grupoId.substring(0, 6)}',
        );

        await BackendClient.pedidosCompra.update(
          item.copyWith(
            status: PedidoCompraStatus.convertido,
            quantidadeRecebida: qtdeRecebida,
            updatedAt: DateTime.now(),
          ),
        );
        efetivados++;
      }

      NotificationService.showPositive(
        'Compra efetivada',
        '$efetivados item${efetivados > 1 ? 's' : ''} adicionados ao estoque',
        position: NotificationPosition.bottom,
      );

      // Volta 2 telas: efetivar page + fecha o card
      if (context.mounted) {
        Navigator.pop(context); // fecha PedidoCompraEfetivarPage
      }
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao efetivar compra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ── Estornar grupo efetivado → volta para confirmado ─────────────────────

  Future<void> onEstornarGrupo(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    final fabricante = itens.first.fabricante.nome;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Estornar Compra?'),
        content: Text(
          'O estoque será debitado e o pedido de $fabricante voltará '
          'para o status Confirmado.\n\n'
          'Use apenas se a compra foi efetivada por engano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      for (final item in itens) {
        final qtdeRecebida = item.quantidadeRecebida ?? item.quantidade;
        await estoqueCtrl.onEstornarCompraManual(
          produtoId: item.produtoId,
          quantidade: qtdeRecebida,
          observacao:
              'Estorno — $fabricante · Pedido #${item.grupoId.substring(0, 6)}',
        );
        await BackendClient.pedidosCompra.update(
          item.copyWith(
            status: PedidoCompraStatus.confirmado,
            quantidadeRecebida: 0,
            updatedAt: DateTime.now(),
          ),
        );
      }
      NotificationService.showPending(
        'Compra estornada',
        '$fabricante voltou para Confirmado',
      );
    } catch (e) {
      NotificationService.showNegative('Erro ao estornar', e.toString(),
          position: NotificationPosition.bottom);
    }
  }

  // ── Descartar grupo ───────────────────────────────────────────────────────

  Future<void> onDescartarGrupo(
    BuildContext context,
    List<PedidoCompraModel> itens,
  ) async {
    final fabricante = itens.first.fabricante.nome;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar Pedido?'),
        content: Text(
          'O pedido de $fabricante com ${itens.length} '
          'item${itens.length > 1 ? 's' : ''} será descartado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final item in itens) {
        await BackendClient.pedidosCompra.update(
          item.copyWith(
            status: PedidoCompraStatus.descartado,
            updatedAt: DateTime.now(),
          ),
        );
      }

      NotificationService.showNegative(
        'Pedido descartado',
        '$fabricante — ${itens.length} item${itens.length > 1 ? 's' : ''}',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao descartar',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}

// ── Dialog: Confirmar Pedido ──────────────────────────────────────────────

class _ConfirmarGrupoDialog extends StatefulWidget {
  final String? fabricanteAtualId;
  final void Function(String id, String nome) onFabricanteChanged;
  final ValueChanged<DateTime?> onDataChanged;
  const _ConfirmarGrupoDialog({
    required this.fabricanteAtualId,
    required this.onFabricanteChanged,
    required this.onDataChanged,
  });

  @override
  State<_ConfirmarGrupoDialog> createState() => _ConfirmarGrupoDialogState();
}

class _ConfirmarGrupoDialogState extends State<_ConfirmarGrupoDialog> {
  DateTime? _dataPrevista;
  FabricanteModel? _fabricanteSelecionado;

  @override
  void initState() {
    super.initState();
    // Se já tem fabricante pré-selecionado (edição)
    if (widget.fabricanteAtualId != null &&
        widget.fabricanteAtualId!.isNotEmpty) {
      try {
        _fabricanteSelecionado = BackendClient.fabricantes.data
            .firstWhere((f) => f.id == widget.fabricanteAtualId);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final fabricantes = [...BackendClient.fabricantes.data]
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blue),
          SizedBox(width: 10),
          Text('Confirmar Pedido'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O pedido será marcado como confirmado.\nO estoque só será creditado ao efetivar a entrega.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Fornecedor (obrigatório) ──────────────────────────────
            Text(
              'Fornecedor *',
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FabricanteModel>(
              value: _fabricanteSelecionado,
              decoration: InputDecoration(
                hintText: 'Selecione o fornecedor',
                prefixIcon: const Icon(Icons.factory_outlined, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: fabricantes
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.nome),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _fabricanteSelecionado = v);
                if (v != null) widget.onFabricanteChanged(v.id, v.nome);
              },
            ),

            const SizedBox(height: 16),

            // ── Prazo previsto ────────────────────────────────────────
            Text(
              'Prazo previsto de entrega (opcional)',
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    _dataPrevista != null
                        ? '${_dataPrevista!.day.toString().padLeft(2, '0')}/'
                            '${_dataPrevista!.month.toString().padLeft(2, '0')}/'
                            '${_dataPrevista!.year}'
                        : 'Selecionar data',
                    style: TextStyle(
                      color: _dataPrevista != null
                          ? Colors.black87
                          : Colors.grey[400],
                    ),
                  ),
                  if (_dataPrevista != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _dataPrevista = null);
                        widget.onDataChanged(null);
                      },
                      child:
                          Icon(Icons.close, size: 16, color: Colors.grey[400]),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          onPressed: _fabricanteSelecionado != null
              ? () => Navigator.pop(context, true)
              : null,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Confirmar Pedido'),
        ),
      ],
    );
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dataPrevista = picked);
      widget.onDataChanged(picked);
    }
  }
}

// ── Dialog: Efetivar Compra ───────────────────────────────────────────────

class _EfetivarGrupoDialog extends StatefulWidget {
  final PedidoCompraConverterGrupoModel model;
  const _EfetivarGrupoDialog({required this.model});

  @override
  State<_EfetivarGrupoDialog> createState() => _EfetivarGrupoDialogState();
}

class _EfetivarGrupoDialogState extends State<_EfetivarGrupoDialog> {
  @override
  Widget build(BuildContext context) {
    final fabricante = widget.model.itens.first.fabricante.nome;
    return AlertDialog(
      title: Text('Efetivar Compra — $fabricante'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirme as quantidades recebidas:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...List.generate(widget.model.itens.length, (i) {
                final item = widget.model.itens[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.produto.nome} · ${item.produto.descricao}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Pedido: ${item.quantidade.toStringAsFixed(3)} kg',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller:
                            widget.model.quantidadesRecebidas[i].controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qtde recebida (kg)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              TextFormField(
                controller: widget.model.observacao.controller,
                decoration: const InputDecoration(
                  labelText: 'Observação geral (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          onPressed: widget.model.isValid
              ? () => Navigator.pop(context, true)
              : null,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Efetivar Compra'),
        ),
      ],
    );
  }
}
