import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManutencaoSettingsWidget extends StatefulWidget {
  const ManutencaoSettingsWidget({super.key});

  @override
  State<ManutencaoSettingsWidget> createState() =>
      _ManutencaoSettingsWidgetState();
}

class _ManutencaoSettingsWidgetState extends State<ManutencaoSettingsWidget> {
  final TextEditingController _buscaEC = TextEditingController();
  PedidoModel? _pedidoSelecionado;
  bool _analiseAberta = false;
  bool _infoExpandida = true;
  final ExpansibleController _produtosCtrl = ExpansibleController();
  final ExpansibleController _elementosCtrl = ExpansibleController();

  List<PedidoModel> get _pedidosFiltrados {
    final todos = BackendClient.pedidos.pepidosUnarchiveds.toList()
      ..sort((a, b) => a.localizador.compareTo(b.localizador));
    if (_buscaEC.text.length < 2) return todos;
    final busca = _buscaEC.text.toCompare;
    return todos
        .where((p) =>
            p.localizador.toCompare.contains(busca) ||
            p.pedidoFinanceiro.toCompare.contains(busca))
        .toList();
  }

  @override
  void dispose() {
    _buscaEC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pedidoSelecionado != null) {
      return _buildAnalise(_pedidoSelecionado!);
    }
    return _buildBusca();
  }

  // ══════════════════════════════════════════════════════
  //  TELA 1: BUSCA DE PEDIDO
  // ══════════════════════════════════════════════════════
  Widget _buildBusca() {
    final pedidos = _pedidosFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de busca
        TextField(
          controller: _buscaEC,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por localizador ou pedido financeiro...',
            prefixIcon:
                Icon(Icons.search, color: AppColors.primaryMain, size: 20),
            suffixIcon: _buscaEC.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _buscaEC.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${pedidos.length} pedidos encontrados',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 12),

        // Lista de pedidos
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: pedidos.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (_, i) {
                  final p = pedidos[i];
                  return _pedidoTile(p);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pedidoTile(PedidoModel p) {
    final tipo = p.tipo.name.toUpperCase();
    return InkWell(
      onTap: () => setState(() {
        _pedidoSelecionado = p;
        _analiseAberta = false;
        _infoExpandida = true;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Tipo badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _tipoColor(p).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: _tipoColor(p).withValues(alpha: 0.30)),
              ),
              child: Text(tipo,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _tipoColor(p))),
            ),
            const SizedBox(width: 10),
            // Localizador
            Expanded(
              child: Text(p.localizador,
                  style: AppCss.mediumBold.setSize(13),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            // Cliente
            Expanded(
              child: Text(p.cliente.nome,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            // Etapa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(p.step.name,
                  style: TextStyle(fontSize: 10, color: Colors.grey[700])),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Color _tipoColor(PedidoModel p) {
    switch (p.tipo.name) {
      case 'cd':
        return Colors.orange[700]!;
      case 'cda':
        return Colors.blue[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // ══════════════════════════════════════════════════════
  //  TELA 2: ANÁLISE DO PEDIDO
  // ══════════════════════════════════════════════════════
  Widget _buildAnalise(PedidoModel pedido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botão voltar
        InkWell(
          onTap: () => setState(() {
            _pedidoSelecionado = null;
            _analiseAberta = false;
            _infoExpandida = true;
          }),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text('Voltar à lista',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.secondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Card de informações básicas
        _infoCard(pedido),
        const SizedBox(height: 16),

        // Botão Análise de Dados
        if (!_analiseAberta)
          Center(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _analiseAberta = true),
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Análise de Dados'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ),

        // Árvores expansíveis
        if (_analiseAberta) ...[
          const SizedBox(height: 16),
          _produtosTree(pedido),
          const SizedBox(height: 12),
          _elementosTree(pedido),
        ],
      ],
    );
  }

  // ── Card de Informações ──
  Widget _infoCard(PedidoModel pedido) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Column(
      children: [
        // ── Cabeçalho com localizador ──
        InkWell(
          onTap: () => setState(() => _infoExpandida = !_infoExpandida),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryMain, const Color(0xFF1E3A5F)],
              ),
              borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(10),
                  bottom: Radius.circular(_infoExpandida ? 0 : 10)),
            ),
            child: Row(
              children: [
                _tipoBadge(pedido),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(pedido.localizador,
                      style: AppCss.largeBold.setSize(16).setColor(Colors.white)),
                ),
                _statusChip(pedido.status.name),
                const SizedBox(width: 12),
                Icon(_infoExpandida ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white),
              ],
            ),
          ),
        ),

        if (_infoExpandida)
          Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // ── Seção 1: Identificação ──
              _infoSection(
                icone: Icons.badge_outlined,
                titulo: 'Identificação',
                cor: Colors.indigo,
                campos: {
                  'ID': pedido.id,
                  'Cliente': pedido.cliente.nome,
                  'Obra': pedido.obra.descricao,
                  'Tipo': pedido.tipo.name.toUpperCase(),
                  'Etapa Atual': pedido.step.name,
                  'Index': pedido.index.toString(),
                },
              ),
              const SizedBox(height: 12),

              // ── Seção 2: Datas ──
              _infoSection(
                icone: Icons.calendar_today_outlined,
                titulo: 'Datas',
                cor: Colors.teal,
                campos: {
                  'Criação': df.format(pedido.createdAt),
                  'Entrega': pedido.deliveryAt != null
                      ? df.format(pedido.deliveryAt!)
                      : '— sem data —',
                },
              ),
              const SizedBox(height: 12),

              // ── Seção 3: Hierarquia ──
              _infoSection(
                icone: Icons.account_tree_outlined,
                titulo: 'Hierarquia',
                cor: Colors.deepPurple,
                campos: {
                  'É Mestre?': pedido.isMestre ? '✅ SIM' : '— NÃO',
                  'É Parcial?': pedido.isParcial
                      ? '✅ SIM (pai: ${BackendClient.pedidos.data.where((p) => p.id == pedido.pai).firstOrNull?.localizador ?? pedido.pai})'
                      : '— NÃO',
                  'Filhos': pedido.pedidosFilhos.length.toString(),
                  'Vinculados': pedido.pedidosVinculados.length.toString(),
                  'Importado?': pedido.isImportado ? '✅ SIM' : '— NÃO',
                },
              ),
              const SizedBox(height: 12),

              // ── Seção 4: Quantidades ──
              _infoSection(
                icone: Icons.scale_outlined,
                titulo: 'Quantidades',
                cor: Colors.orange,
                campos: {
                  'Peso Total': pedido.pesoTotal.toKg(),
                  'Produtos': '${pedido.produtos.length} bitolas',
                  'Elementos': '${pedido.elementos.length} elementos',
                },
              ),
              const SizedBox(height: 12),

              // ── Seção 5: Financeiro ──
              _infoSection(
                icone: Icons.receipt_long_outlined,
                titulo: 'Financeiro / Observações',
                cor: Colors.green,
                campos: {
                  'Pedido Financeiro': pedido.pedidoFinanceiro.isNotEmpty
                      ? pedido.pedidoFinanceiro
                      : '—',
                  'Planilhamento': pedido.planilhamento.isNotEmpty
                      ? pedido.planilhamento
                      : '—',
                  'Romaneio': pedido.romaneio ?? '—',
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tipoBadge(PedidoModel p) {
    final cor = _tipoColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
      ),
      child: Text(p.tipo.name.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: cor,
              letterSpacing: 0.5)),
    );
  }

  Widget _infoSection({
    required IconData icone,
    required String titulo,
    required Color cor,
    required Map<String, String> campos,
  }) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título da seção
          Row(
            children: [
              Icon(icone, size: 15, color: cor),
              const SizedBox(width: 6),
              Text(titulo.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cor,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          // Campos em grid
          Wrap(
            spacing: 20,
            runSpacing: 4,
            children: campos.entries.map((e) {
              return SizedBox(
                width: 260,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('${e.key}:',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500])),
                      ),
                      Expanded(
                        child: SelectableText(e.value,
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF1E293B))),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ÁRVORE: PRODUTOS
  // ══════════════════════════════════════════════════════
  Widget _produtosTree(PedidoModel pedido) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        controller: _produtosCtrl,
        onExpansionChanged: (expanded) {
          if (expanded) _elementosCtrl.collapse();
        },
        leading: Icon(Icons.inventory_2_outlined,
            size: 20, color: Colors.orange[700]),
        title: Text('PRODUTOS (${pedido.produtos.length})',
            style: AppCss.mediumBold.setSize(13)),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: pedido.produtos.map((p) => _produtoNode(p)).toList(),
      ),
    );
  }

  Widget _produtoNode(PedidoProdutoModel p) {
    final produto = p.produto;
    final statusAtual = p.status;
    final campos = <String, String>{
      'id': p.id,
      'pedidoId': p.pedidoId,
      'clienteId': p.clienteId,
      'obraId': p.obraId,
      'produto.id': produto.id,
      'produto.descricao': produto.descricao,
      'produto.number': produto.number.toString(),
      'produto.sortIndex': produto.sortIndex.toString(),
      'qtde': p.qtde.toStringAsFixed(3),
      'qtdeOriginal': p.qtdeOriginal.toStringAsFixed(3),
      'valorUnitario': p.valorUnitario.toStringAsFixed(2),
      'valorTotal': p.valorTotal.toStringAsFixed(2),
      'isPaused': p.isPaused.toString(),
      'isSelected': p.isSelected.toString(),
      'isAvailable': p.isAvailable.toString(),
      'status': statusAtual.status.name,
      'status.createdAt':
          DateFormat('dd/MM/yyyy HH:mm').format(statusAtual.createdAt),
      'materiaPrima':
          p.materiaPrima != null ? p.materiaPrima!.label : '—',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.orange[50]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: ExpansionTile(
        leading: _statusChip(statusAtual.status.name),
        title: Text('🔩 ${produto.descricao}',
            style: AppCss.mediumBold.setSize(12)),
        subtitle: Text('${p.qtde.toKg()} (original: ${p.qtdeOriginal.toKg()})',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _camposTable(campos),
          if (p.statusess.length > 1) ...[
            const SizedBox(height: 8),
            _historicoStatusProduto(p),
          ],
        ],
      ),
    );
  }

  Widget _historicoStatusProduto(PedidoProdutoModel p) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📜 Histórico de Status (${p.statusess.length})',
              style: AppCss.minimumBold.setSize(11)),
          const SizedBox(height: 6),
          for (int i = 0; i < p.statusess.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Text('[$i] ', style: _monoStyle),
                  _statusChip(p.statusess[i].status.name),
                  const SizedBox(width: 8),
                  Text(
                      DateFormat('dd/MM/yyyy HH:mm')
                          .format(p.statusess[i].createdAt),
                      style: _monoStyle),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ÁRVORE: ELEMENTOS
  // ══════════════════════════════════════════════════════
  Widget _elementosTree(PedidoModel pedido) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        controller: _elementosCtrl,
        onExpansionChanged: (expanded) {
          if (expanded) _produtosCtrl.collapse();
        },
        leading:
            Icon(Icons.construction_outlined, size: 20, color: Colors.blue[700]),
        title: Text('ELEMENTOS (${pedido.elementos.length})',
            style: AppCss.mediumBold.setSize(13)),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: pedido.elementos.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Nenhum elemento cadastrado',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic)),
                )
              ]
            : (pedido.elementos.toList()
                  ..sort((a, b) => a.nome.compareTo(b.nome)))
                .map((e) => _elementoNode(e))
                .toList(),
      ),
    );
  }

  Widget _elementoNode(ElementoModel e) {
    final campos = <String, String>{
      'id': e.id,
      'pedidoId': e.pedidoId,
      'nome': e.nome,
      'qtde': e.qtde.toString(),
      'qtdePronto': e.qtdePronto.toString(),
      'status': e.status.name,
      'pesoTotal': '${e.pesoTotal.toStringAsFixed(3)} Kg',
      'pesoUnitario': '${e.pesoUnitario.toStringAsFixed(3)} Kg',
      'progressoPronto': '${(e.progressoPronto * 100).toStringAsFixed(0)}%',
      'createdAt': DateFormat('dd/MM/yyyy HH:mm').format(e.createdAt),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: ExpansionTile(
        leading: _statusChip(e.status.name),
        title:
            Text('📐 ${e.nome}', style: AppCss.mediumBold.setSize(12)),
        subtitle: Text(
            'Qtde: ${e.qtde} | Pronto: ${e.qtdePronto} | Peso: ${e.pesoTotal.toStringAsFixed(1)} Kg',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _camposTable(campos),

          // Arquivos
          if (e.arquivos.isNotEmpty) ...[
            const SizedBox(height: 10),
            _arquivosSection(e),
          ],

          // Posições
          if (e.posicoes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _posicoesSection(e),
          ],
        ],
      ),
    );
  }

  Widget _arquivosSection(ElementoModel e) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple[50]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.purple[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📎 Arquivos (${e.arquivos.length})',
              style: AppCss.minimumBold.setSize(11)),
          const SizedBox(height: 6),
          for (final arq in e.arquivos)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _camposTable({
                'id': arq.id,
                'nome': arq.nome,
                'tipo': arq.tipo,
                'extensao': arq.extensao,
                'tamanho': '${arq.tamanho} bytes',
                'url': arq.url,
                'criadoEm':
                    DateFormat('dd/MM/yyyy HH:mm').format(arq.criadoEm),
              }),
            ),
        ],
      ),
    );
  }

  Widget _posicoesSection(ElementoModel e) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green[50]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📍 Posições (${e.posicoes.length})',
              style: AppCss.minimumBold.setSize(11)),
          const SizedBox(height: 6),
          for (final pos in e.posicoes) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _statusChip(pos.status.name),
                      const SizedBox(width: 8),
                      Text('${pos.nome} — OS: ${pos.numeroOs}',
                          style: AppCss.minimumBold.setSize(11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _camposTable({
                    'id': pos.id,
                    'elementoId': pos.elementoId,
                    'nome': pos.nome,
                    'numeroOs': pos.numeroOs,
                    'produtoId': pos.produtoId,
                    'bitola': pos.produto?.descricao ?? '—',
                    'pesoKg': '${pos.pesoKg.toStringAsFixed(3)} Kg',
                    'qtde': pos.qtde.toString(),
                    'comprCorte': pos.comprCorte.toStringAsFixed(3),
                    'status': pos.status.name,
                    'createdAt': DateFormat('dd/MM/yyyy HH:mm')
                        .format(pos.createdAt),
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGETS UTILITÁRIOS
  // ══════════════════════════════════════════════════════
  Widget _camposTable(Map<String, String> campos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: campos.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text('${e.key}:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        fontFamily: 'monospace')),
              ),
              Expanded(
                child: SelectableText(e.value, style: _monoStyle),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    Color cor;
    switch (status) {
      case 'pronto':
        cor = Colors.green[600]!;
        break;
      case 'produzindo':
      case 'armando':
        cor = Colors.orange[700]!;
        break;
      case 'separado':
        cor = Colors.blue[600]!;
        break;
      default:
        cor = Colors.grey[500]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor.withValues(alpha: 0.30)),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: cor)),
    );
  }

  TextStyle get _monoStyle => const TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: Color(0xFF334155),
      );
}
