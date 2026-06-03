import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:aco_plus/app/modules/modulo_importacao/spe/spe_importacao_service.dart';
import 'package:aco_plus/app/modules/modulo_importacao/spe/spe_supabase_client.dart';
import 'package:flutter/material.dart';

/// Abre o dialog de importação SPE para o pedido informado.
Future<bool> showSpeImportarDialog(PedidoModel pedido) async {
  final resultado = await showDialog<bool>(
    context: contextGlobal,
    barrierDismissible: false,
    builder: (context) => SpeImportarDialog(pedido: pedido),
  );
  return resultado == true;
}

class SpeImportarDialog extends StatefulWidget {
  final PedidoModel pedido;
  const SpeImportarDialog({super.key, required this.pedido});

  @override
  State<SpeImportarDialog> createState() => _SpeImportarDialogState();
}

class _SpeImportarDialogState extends State<SpeImportarDialog> {
  // Etapa 0 = selecionar pedido técnico, 1 = conferência
  int _etapa = 0;
  bool _carregando = true;
  bool _importando = false;

  // Lista de pedidos técnicos do SPE
  List<Map<String, dynamic>> _pedidosTecnicos = [];
  Map<String, dynamic>? _pedidoSelecionado;

  // Dados extraídos
  SpeExtracao? _extracao;

  // Filtro de busca
  final TextEditingController _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarPedidosTecnicos();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPedidosTecnicos() async {
    setState(() => _carregando = true);
    try {
      final client = SpeSupabaseClient();
      _pedidosTecnicos = await client.buscarPedidosTecnicosAbertos();
    } catch (e) {
      log('SpeImportarDialog._carregarPedidosTecnicos erro: $e');
    }
    setState(() => _carregando = false);
  }

  Future<void> _selecionarPedido(Map<String, dynamic> pedidoTecnico) async {
    setState(() {
      _pedidoSelecionado = pedidoTecnico;
      _carregando = true;
    });

    try {
      final service = SpeImportacaoService();
      _extracao = await service.extrairDados(pedidoTecnico);
      setState(() {
        _etapa = 1;
        _carregando = false;
      });
    } catch (e) {
      log('SpeImportarDialog._selecionarPedido erro: $e');
      NotificationService.showNegative('Erro', 'Falha ao extrair dados: $e');
      setState(() => _carregando = false);
    }
  }

  Future<void> _executarImportacao(String modo) async {
    if (_extracao == null || _pedidoSelecionado == null) return;

    setState(() => _importando = true);

    try {
      final service = SpeImportacaoService();
      await service.importarParaPedido(
        pedido: widget.pedido,
        extracao: _extracao!,
        modo: modo,
      );

      // Atualizar os elementos localmente
      await elementoCtrl.onFetch(widget.pedido.id);

      if (mounted) {
        Navigator.pop(context, true);
        NotificationService.showPositive(
          'Importação Concluída',
          '${_extracao!.bitolas.length} bitolas e '
              '${_extracao!.elementos.length} elementos importados',
        );
      }
    } catch (e) {
      NotificationService.showNegative('Erro', 'Falha na importação: $e');
    }

    if (mounted) setState(() => _importando = false);
  }

  void _confirmarImportacao() {
    // Verificar se o pedido já tem produtos ou elementos
    final temProdutos = widget.pedido.produtos.isNotEmpty;
    final temElementos = widget.pedido.elementos.isNotEmpty;

    if (temProdutos || temElementos) {
      showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
          title: const Text('Dados existentes'),
          content: Text(
            'Este pedido já possui ${temProdutos ? "produtos" : ""}'
            '${temProdutos && temElementos ? " e " : ""}'
            '${temElementos ? "elementos" : ""} cadastrados.\n\n'
            'O que deseja fazer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancelar'),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'acrescentar'),
              child: const Text('Acrescentar aos existentes'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'substituir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpar e importar novos'),
            ),
          ],
        ),
      ).then((valor) {
        if (valor == 'substituir' || valor == 'acrescentar') {
          _executarImportacao(valor!);
        }
      });
    } else {
      _executarImportacao('acrescentar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppCss.radius12),
      child: Container(
        width: 780,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: AppCss.radius12,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _etapa == 0
                      ? _buildEtapaSelecao()
                      : _buildEtapaConferencia(),
            ),
            if (!_carregando) _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_download_rounded, color: Colors.white),
          const W(12),
          Text(
            _etapa == 0
                ? 'IMPORTAR DO SPE'
                : 'CONFERÊNCIA — ${_pedidoSelecionado?['identificador'] ?? ''}',
            style: AppCss.smallBold.setSize(14).setColor(Colors.white),
          ),
          const Spacer(),
          if (!_importando)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  // ── Etapa 0: Seleção ──────────────────────────────────────────────────────
  Widget _buildEtapaSelecao() {
    final busca = _buscaCtrl.text.toLowerCase().trim();
    final filtrados = busca.isEmpty
        ? _pedidosTecnicos
        : _pedidosTecnicos.where((p) {
            final id = (p['identificador'] ?? '').toString().toLowerCase();
            final cliente = (p['cliente_nome'] ?? '').toString().toLowerCase();
            final obra = (p['obra_nome'] ?? '').toString().toLowerCase();
            return id.contains(busca) ||
                cliente.contains(busca) ||
                obra.contains(busca);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de busca
          TextField(
            controller: _buscaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por identificador, cliente ou obra...',
              hintStyle: AppCss.minimumRegular.setSize(13),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const H(12),
          Text(
            '${filtrados.length} pedidos técnicos abertos',
            style: AppCss.minimumBold.setSize(12).setColor(Colors.grey[600]!),
          ),
          const H(8),

          // Lista de pedidos
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum pedido técnico encontrado',
                      style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const H(6),
                    itemBuilder: (context, index) {
                      final pt = filtrados[index];
                      final elementos = List.from(pt['elementos'] ?? []);
                      final pesoTotal = elementos.fold<double>(
                        0.0,
                        (s, e) =>
                            s +
                            (double.tryParse(
                                    (e['peso_total'] ?? '0').toString()) ??
                                0),
                      );

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selecionarPedido(pt),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMain
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.description_outlined,
                                    color: AppColors.primaryMain, size: 20),
                              ),
                              const W(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pt['identificador'] ?? 'Sem identificador',
                                      style: AppCss.smallBold.setSize(13),
                                    ),
                                    const H(2),
                                    Text(
                                      '${pt['cliente_nome'] ?? ''} — ${pt['obra_nome'] ?? ''}',
                                      style: AppCss.minimumRegular
                                          .setSize(11)
                                          .setColor(Colors.grey[600]!),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    pesoTotal.toKg(),
                                    style: AppCss.minimumBold
                                        .setSize(12)
                                        .setColor(AppColors.primaryMain),
                                  ),
                                  Text(
                                    '${elementos.length} elementos',
                                    style: AppCss.minimumRegular
                                        .setSize(10)
                                        .setColor(Colors.grey[500]!),
                                  ),
                                ],
                              ),
                              const W(8),
                              Icon(Icons.chevron_right,
                                  color: Colors.grey[400], size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Etapa 1: Conferência ──────────────────────────────────────────────────
  Widget _buildEtapaConferencia() {
    if (_extracao == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info do pedido SPE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                const W(10),
                Expanded(
                  child: Text(
                    'Pedido: ${_pedidoSelecionado?['identificador']} — '
                    '${_pedidoSelecionado?['observacao'] ?? 'Sem observação'}',
                    style: AppCss.minimumRegular.setSize(12),
                  ),
                ),
              ],
            ),
          ),
          const H(20),

          // ── Bitolas ─────────────────────────────────────────────────────
          Text(
            'BITOLAS (${_extracao!.bitolas.length})',
            style: AppCss.smallBold.setSize(13),
          ),
          const H(8),

          if (_extracao!.bitolasSemMatch.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[800], size: 18),
                  const W(8),
                  Expanded(
                    child: Text(
                      '${_extracao!.bitolasSemMatch.length} bitola(s) sem correspondência no PCP: '
                      '${_extracao!.bitolasSemMatch.join(", ")}',
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(Colors.amber[900]!),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Bitola',
                              style: AppCss.minimumBold.setSize(11))),
                      Expanded(
                          flex: 2,
                          child: Text('Peso',
                              style: AppCss.minimumBold.setSize(11))),
                      Expanded(
                          flex: 2,
                          child: Text('Status',
                              style: AppCss.minimumBold.setSize(11))),
                    ],
                  ),
                ),
                // Linhas
                ...List.generate(_extracao!.bitolas.length, (i) {
                  final b = _extracao!.bitolas[i];
                  final encontrado = b.produtoPcp != null;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            b.bitolaNome,
                            style: AppCss.minimumRegular.setSize(12).setColor(
                                encontrado ? Colors.black : Colors.red),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            b.pesoTotalKg.toKg(),
                            style: AppCss.minimumBold.setSize(12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: encontrado
                                  ? Colors.green[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              encontrado ? '✓ Encontrada' : '✗ Não encontrada',
                              style: AppCss.minimumBold.setSize(10).setColor(
                                  encontrado
                                      ? Colors.green[700]!
                                      : Colors.red[700]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const H(20),

          // ── Elementos ───────────────────────────────────────────────────
          Text(
            'ELEMENTOS (${_extracao!.elementos.length})',
            style: AppCss.smallBold.setSize(13),
          ),
          const H(8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Elemento',
                              style: AppCss.minimumBold.setSize(11))),
                      Expanded(
                          flex: 1,
                          child: Text('Qtde',
                              style: AppCss.minimumBold.setSize(11))),
                      Expanded(
                          flex: 1,
                          child: Text('Posições',
                              style: AppCss.minimumBold.setSize(11))),
                      Expanded(
                          flex: 2,
                          child: Text('Peso Total',
                              style: AppCss.minimumBold.setSize(11))),
                    ],
                  ),
                ),
                ...List.generate(_extracao!.elementos.length, (i) {
                  final elem = _extracao!.elementos[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(elem.nome,
                              style: AppCss.minimumBold.setSize(12)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('${elem.qtde}',
                              style: AppCss.minimumRegular.setSize(12)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('${elem.posicoes.length}',
                              style: AppCss.minimumRegular.setSize(12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            elem.pesoTotal.toKg(),
                            style: AppCss.minimumBold
                                .setSize(12)
                                .setColor(AppColors.primaryMain),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_etapa == 1) ...[
            TextButton(
              onPressed: _importando
                  ? null
                  : () => setState(() {
                        _etapa = 0;
                        _pedidoSelecionado = null;
                        _extracao = null;
                      }),
              child: const Text('Voltar'),
            ),
            const W(12),
            ElevatedButton.icon(
              onPressed: _importando ? null : _confirmarImportacao,
              icon: _importando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(_importando ? 'Importando...' : 'Importar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
