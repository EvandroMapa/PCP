import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/backup/backup_explorer_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BackupExplorerPage extends StatefulWidget {
  final String nomeBackup;

  const BackupExplorerPage({super.key, required this.nomeBackup});

  @override
  State<BackupExplorerPage> createState() => _BackupExplorerPageState();
}

class _BackupExplorerPageState extends State<BackupExplorerPage> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explorar Backup',
                style: AppCss.largeBold.setColor(AppColors.white)),
            Text(
              widget.nomeBackup,
              style: AppCss.smallRegular
                  .copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryMain,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: Column(
        children: [
          // ── Barra de busca ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por localizador, cliente ou ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _busca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _buscaCtrl.clear();
                                setState(() => _busca = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (v) => setState(() => _busca = v),
                  ),
                ),
                const SizedBox(width: 12),
                StreamBuilder<List<BackupPedidoResumo>>(
                  stream: backupExplorerCtrl.pedidosStream.listen,
                  builder: (_, snap) {
                    final total = snap.data?.length ?? 0;
                    final filtrados =
                        backupExplorerCtrl.filtrar(_busca).length;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMain.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _busca.length >= 2
                            ? '$filtrados / $total pedidos'
                            : '$total pedidos',
                        style: AppCss.smallRegular.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Lista de pedidos ────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<BackupPedidoResumo>>(
              stream: backupExplorerCtrl.pedidosStream.listen,
              builder: (_, snap) {
                final pedidos = backupExplorerCtrl.filtrar(_busca);
                if (pedidos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _busca.isNotEmpty
                              ? 'Nenhum pedido encontrado para "$_busca"'
                              : 'Nenhum pedido no backup',
                          style: AppCss.mediumRegular
                              .copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pedidos.length,
                  itemBuilder: (_, i) => _PedidoCard(pedido: pedidos[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CARD DO PEDIDO (expansível em árvore) ───────────────────────────────────
class _PedidoCard extends StatefulWidget {
  final BackupPedidoResumo pedido;

  const _PedidoCard({required this.pedido});

  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: _expandido ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _expandido
              ? AppColors.primaryMain.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primaryMain.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long,
                        color: AppColors.primaryMain, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.localizador,
                            style: AppCss.mediumBold),
                        const SizedBox(height: 2),
                        Text(
                          p.clienteNome,
                          style: AppCss.smallRegular
                              .copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (p.isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text('Arquivado',
                          style: TextStyle(
                              fontSize: 10, color: Colors.orange[700])),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${p.totalSubRegistros} registros',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child:
                        Icon(Icons.expand_more, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),

          // ── Corpo expandido (árvore) ────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildArvore(p),
            crossFadeState: _expandido
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildArvore(BackupPedidoResumo p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Info do pedido ────────────────────────────────────────
          _buildInfoRow('ID', p.id),
          if (p.createdAt.isNotEmpty) _buildInfoRow('Criado em', _formatDate(p.createdAt)),
          if (p.tipo.isNotEmpty) _buildInfoRow('Tipo', p.tipo),
          if (p.status.isNotEmpty) _buildInfoRow('Status', p.status),

          const SizedBox(height: 12),

          // ── Produtos ──────────────────────────────────────────────
          _buildSecao(
            icone: Icons.inventory_2_outlined,
            titulo: 'Produtos',
            cor: Colors.blue,
            items: p.produtosRaw,
            builder: (item) {
              final produtoNome =
                  p.produtosDefMap[item['produto_id']] ?? item['produto_id'];
              final qtde = item['qtde'] ?? item['quantidade'] ?? '?';
              return '$produtoNome — ${qtde}kg';
            },
          ),

          // ── Histórico de Status ───────────────────────────────────
          _buildSecao(
            icone: Icons.timeline,
            titulo: 'Histórico de Status',
            cor: Colors.purple,
            items: p.statusRaw,
            builder: (item) {
              final status = item['status'] ?? '?';
              final data = _formatDate(item['created_at']?.toString() ?? '');
              return '$status — $data';
            },
          ),

          // ── Histórico de Etapas ───────────────────────────────────
          _buildSecao(
            icone: Icons.route,
            titulo: 'Histórico de Etapas',
            cor: Colors.teal,
            items: p.stepsRaw,
            builder: (item) {
              final stepNome =
                  p.stepsDefMap[item['step_id']] ?? item['step_id'] ?? '?';
              final data = _formatDate(item['created_at']?.toString() ?? '');
              return '$stepNome — $data';
            },
          ),

          // ── Tags ──────────────────────────────────────────────────
          _buildSecao(
            icone: Icons.label_outline,
            titulo: 'Tags',
            cor: Colors.orange,
            items: p.tagsRaw,
            builder: (item) =>
                p.tagsDefMap[item['tag_id']]?.toString() ??
                item['tag_id']?.toString() ??
                '?',
          ),

          // ── Elementos ─────────────────────────────────────────────
          _buildSecao(
            icone: Icons.extension_outlined,
            titulo: 'Elementos',
            cor: Colors.green,
            items: p.elementosRaw,
            builder: (item) {
              final nome = item['nome'] ?? item['id'] ?? '?';
              final posicoes = p.posicoesRaw
                  .where((pos) => pos['elemento_id'] == item['id'])
                  .length;
              return '$nome ($posicoes posições)';
            },
          ),

          // ── Comentários ───────────────────────────────────────────
          _buildSecao(
            icone: Icons.chat_bubble_outline,
            titulo: 'Comentários',
            cor: Colors.indigo,
            items: p.commentsRaw,
            builder: (item) {
              final texto = item['texto'] ?? item['comment'] ?? '?';
              return texto.toString().length > 60
                  ? '${texto.toString().substring(0, 60)}...'
                  : texto.toString();
            },
          ),

          const SizedBox(height: 16),

          // ── Botões ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: AppColors.primaryMain),
                  ),
                  icon: const Icon(Icons.troubleshoot, size: 18),
                  label: const Text('Diagnosticar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _onDiagnosticar(context, p),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restaurar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () =>
                      backupExplorerCtrl.restaurarPedido(context, p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onDiagnosticar(
      BuildContext context, BackupPedidoResumo pedido) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final resultado =
        await backupExplorerCtrl.diagnosticarPedido(pedido);

    if (context.mounted) Navigator.pop(context); // fecha loading

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => _DiagnosticoDialog(
        pedido: pedido,
        resultado: resultado,
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(valor,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao({
    required IconData icone,
    required String titulo,
    required Color cor,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) builder,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 28, bottom: 4),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icone, size: 16, color: cor),
          ),
          title: Text(
            '$titulo (${items.length})',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: cor),
          ),
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      builder(item),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }
}

// ─── DIALOG DE DIAGNÓSTICO ───────────────────────────────────────────────────
class _DiagnosticoDialog extends StatelessWidget {
  final BackupPedidoResumo pedido;
  final DiagnosticoResult resultado;

  const _DiagnosticoDialog({
    required this.pedido,
    required this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.troubleshoot,
                color: AppColors.primaryMain, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diagnóstico', style: AppCss.largeBold),
                Text(
                  pedido.localizador,
                  style: AppCss.smallRegular.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),

            // ── Cabeçalho da tabela ───────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Text('Tabela',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[600])),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Backup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue[700])),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Banco',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.purple[700])),
                  ),
                ],
              ),
            ),

            // ── Linhas ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                children: resultado.tabelas.map((tabela) {
                  final noBkp = resultado.backup[tabela] ?? 0;
                  final noBanco = resultado.banco[tabela] ?? 0;

                  IconData icone;
                  Color corIcone;

                  if (noBanco == -1) {
                    icone = Icons.error_outline;
                    corIcone = Colors.grey;
                  } else if (tabela == 'ordem_produtos' && noBanco > 0) {
                    icone = Icons.warning_amber_rounded;
                    corIcone = Colors.orange;
                  } else if (noBanco > 0 && noBkp == 0) {
                    icone = Icons.warning_amber_rounded;
                    corIcone = Colors.orange;
                  } else if (noBanco == 0 && noBkp > 0) {
                    icone = Icons.cancel_outlined;
                    corIcone = Colors.red;
                  } else if (noBanco == noBkp && noBkp > 0) {
                    icone = Icons.check_circle_outline;
                    corIcone = Colors.green;
                  } else {
                    icone = Icons.remove_circle_outline;
                    corIcone = Colors.grey;
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Icon(icone, size: 16, color: corIcone),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(resultado.label(tabela),
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            noBkp.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: noBkp > 0
                                  ? Colors.blue[700]
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            noBanco == -1 ? 'erro' : noBanco.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: noBanco > 0
                                  ? Colors.purple[700]
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Legenda ───────────────────────────────────────────────
            const SizedBox(height: 12),
            if (resultado.temOrfaos)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Registros órfãos encontrados no banco.\n'
                        'A restauração irá sobrescrever esses dados.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),

            if (!resultado.temOrfaos &&
                (resultado.banco['pedidos'] ?? 0) == 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nenhum registro encontrado no banco.\n'
                        'Restauração segura — sem conflitos.',
                        style:
                            TextStyle(fontSize: 11, color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),

            if ((resultado.banco['pedidos'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pedido ainda existe no banco de dados.\n'
                        'A restauração não será permitida.',
                        style:
                            TextStyle(fontSize: 11, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
