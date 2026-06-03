import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/audit/audit_log_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _buscaCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, String>> _usuarios = [];
  List<String> _dispositivos = [];

  @override
  void initState() {
    super.initState();
    setWebTitle('Logs de Auditoria');
    auditLogCtrl.onInit();
    _carregarFiltros();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      auditLogCtrl.carregarMais();
    }
  }

  Future<void> _carregarFiltros() async {
    final usuarios = await auditLogCtrl.obterUsuarios();
    final dispositivos = await auditLogCtrl.obterDispositivos();
    if (mounted) {
      setState(() {
        _usuarios = usuarios;
        _dispositivos = dispositivos;
      });
    }
  }

  void _aplicarFiltros() {
    auditLogCtrl.filtroBusca =
        _buscaCtrl.text.isNotEmpty ? _buscaCtrl.text : null;
    auditLogCtrl.buscar();
  }

  void _limparFiltros() {
    _buscaCtrl.clear();
    auditLogCtrl.resetFiltros();
    auditLogCtrl.buscar();
    setState(() {});
  }

  Future<void> _selecionarData() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: auditLogCtrl.filtroData,
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => auditLogCtrl.filtroData = picked);
      _aplicarFiltros();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text('Logs de Auditoria',
            style: AppCss.largeBold.setColor(AppColors.white)),
        backgroundColor: AppColors.primaryMain,
        iconTheme: IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            tooltip: 'Limpar filtros',
            onPressed: _limparFiltros,
            icon: Icon(Icons.filter_alt_off, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => auditLogCtrl.buscar(),
            icon: Icon(Icons.refresh, color: AppColors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtros ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
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
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Usuário
                _buildDropdown<String>(
                  largura: 180,
                  hint: 'Usuário',
                  value: auditLogCtrl.filtroUsuarioId,
                  items: _usuarios.map((u) {
                    return DropdownMenuItem(
                      value: u['id'],
                      child: Text(u['nome'] ?? '', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => auditLogCtrl.filtroUsuarioId = v);
                    _aplicarFiltros();
                  },
                ),

                // Evento
                _buildDropdown<String>(
                  largura: 200,
                  hint: 'Evento',
                  value: auditLogCtrl.filtroAcao,
                  items: AuditService.acaoLabels.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => auditLogCtrl.filtroAcao = v);
                    _aplicarFiltros();
                  },
                ),

                // Dispositivo
                _buildDropdown<String>(
                  largura: 180,
                  hint: 'Dispositivo',
                  value: auditLogCtrl.filtroDispositivo,
                  items: _dispositivos.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(d, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => auditLogCtrl.filtroDispositivo = v);
                    _aplicarFiltros();
                  },
                ),

                // Data
                InkWell(
                  onTap: _selecionarData,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          auditLogCtrl.filtroData != null
                              ? '${DateFormat('dd/MM').format(auditLogCtrl.filtroData!.start)} — ${DateFormat('dd/MM').format(auditLogCtrl.filtroData!.end)}'
                              : 'Período',
                          style: TextStyle(
                            fontSize: 13,
                            color: auditLogCtrl.filtroData != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Busca por entidade
                SizedBox(
                  width: 220,
                  height: 40,
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar pedido/entidade...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _aplicarFiltros(),
                  ),
                ),
              ],
            ),
          ),

          // ── Tabela de logs ──────────────────────────────────────────
          Expanded(
            child: StreamOut<List<AuditLogEntry>>(
              stream: auditLogCtrl.logsStream.listen,
              builder: (_, logs) {
                if (logs.isEmpty) {
                  return StreamOut<bool>(
                    stream: auditLogCtrl.carregandoStream.listen,
                    builder: (_, carregando) {
                      if (carregando) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48,
                                color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('Nenhum log encontrado',
                                style: AppCss.mediumRegular
                                    .copyWith(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    },
                  );
                }

                return Column(
                  children: [
                    // Info de resultados
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 14,
                              color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            '${logs.length} registro(s)${auditLogCtrl.temMais ? '+' : ''}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // Linhas
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: logs.length + (auditLogCtrl.temMais ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= logs.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          return _LogRow(entry: logs[i]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required double largura,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: largura,
      height: 40,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }
}

// ─── LINHA DO LOG ────────────────────────────────────────────────────────────
class _LogRow extends StatelessWidget {
  final AuditLogEntry entry;

  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final corAcao = _corPorAcao(entry.acao);
    final descricao = _descricao();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Linha 1: Data | Usuário | Ação | Dispositivo ──
          Row(
            children: [
              // Data
              SizedBox(
                width: 120,
                child: Text(
                  DateFormat('dd/MM/yy HH:mm').format(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              // Usuário
              SizedBox(
                width: 120,
                child: Text(
                  entry.usuarioNome,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // Ação (badge)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: corAcao.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.acaoFormatada,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: corAcao),
                ),
              ),

              const Spacer(),

              // Dispositivo
              Text(
                entry.dispositivo ?? '',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),

          // ── Linha 2: Descrição rica ──
          if (descricao.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                descricao,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// Monta uma frase descritiva do que aconteceu a partir da ação,
  /// entidade e detalhes JSON.
  String _descricao() {
    final label = entry.entidadeLabel ?? '';
    final det = entry.detalhes;

    switch (entry.acao) {
      case 'login':
        return 'Entrou no sistema';
      case 'logout':
        return 'Saiu do sistema';

      case 'excluir_pedido':
        final cliente = det['cliente']?.toString() ?? '';
        final produtos = det['produtos']?.toString() ?? '';
        final partes = <String>[];
        if (label.isNotEmpty) partes.add('Pedido "$label"');
        if (cliente.isNotEmpty) partes.add('cliente: $cliente');
        if (produtos.isNotEmpty) partes.add('$produtos produto(s)');
        return partes.isNotEmpty ? partes.join(' — ') : 'Pedido excluído';

      case 'criar_pedido':
        final cliente = det['cliente']?.toString() ?? '';
        final tipo = det['tipo']?.toString() ?? '';
        final produtos = det['produtos']?.toString() ?? '';
        final partes = <String>[];
        if (label.isNotEmpty) partes.add('Pedido "$label" criado');
        if (cliente.isNotEmpty) partes.add('cliente: $cliente');
        if (tipo.isNotEmpty) partes.add('tipo: $tipo');
        if (produtos.isNotEmpty) partes.add('$produtos produto(s)');
        return partes.isNotEmpty ? partes.join(' — ') : 'Novo pedido criado';

      case 'editar_pedido':
        final clienteEdit = det['cliente']?.toString() ?? '';
        final parteEdit = <String>[];
        if (label.isNotEmpty) parteEdit.add('Pedido "$label" editado');
        if (clienteEdit.isNotEmpty) parteEdit.add('cliente: $clienteEdit');
        return parteEdit.isNotEmpty ? parteEdit.join(' — ') : 'Pedido editado';

      case 'arquivar_pedido':
        final clienteArq = det['cliente']?.toString() ?? '';
        final parteArq = <String>[];
        if (label.isNotEmpty) parteArq.add('Pedido "$label" arquivado');
        if (clienteArq.isNotEmpty) parteArq.add('cliente: $clienteArq');
        return parteArq.isNotEmpty ? parteArq.join(' — ') : 'Pedido arquivado';

      case 'desarquivar_pedido':
        final clienteDes = det['cliente']?.toString() ?? '';
        final parteDes = <String>[];
        if (label.isNotEmpty) parteDes.add('Pedido "$label" desarquivado');
        if (clienteDes.isNotEmpty) parteDes.add('cliente: $clienteDes');
        return parteDes.isNotEmpty ? parteDes.join(' — ') : 'Pedido desarquivado';

      case 'mover_etapa':
        final de = det['de']?.toString() ?? '?';
        final para = det['para']?.toString() ?? '?';
        return label.isNotEmpty
            ? 'Pedido "$label" movido de "$de" → "$para"'
            : 'Movido de "$de" → "$para"';

      case 'excluir_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" excluída'
            : 'Ordem excluída';

      case 'criar_ordem':
        final produtos = det['produtos']?.toString() ?? '';
        return label.isNotEmpty
            ? 'Ordem "$label" criada${produtos.isNotEmpty ? ' com $produtos produto(s)' : ''}'
            : 'Nova ordem criada';

      case 'editar_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" editada'
            : 'Ordem editada';

      case 'arquivar_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" arquivada'
            : 'Ordem arquivada';

      case 'desarquivar_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" desarquivada'
            : 'Ordem desarquivada';

      case 'congelar_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" congelada (removida da esteira)'
            : 'Ordem congelada';

      case 'descongelar_ordem':
        return label.isNotEmpty
            ? 'Ordem "$label" descongelada (voltou à esteira)'
            : 'Ordem descongelada';

      case 'excluir_cliente':
        return label.isNotEmpty
            ? 'Cliente "$label" excluído'
            : 'Cliente excluído';

      case 'excluir_bitola':
        return label.isNotEmpty
            ? 'Produto "$label" excluído'
            : 'Produto excluído';

      case 'excluir_etapa':
        return label.isNotEmpty
            ? 'Etapa "$label" excluída'
            : 'Etapa excluída';

      case 'excluir_obra':
        return label.isNotEmpty
            ? 'Obra "$label" excluída'
            : 'Obra excluída';

      case 'excluir_perfil':
        return label.isNotEmpty
            ? 'Perfil "$label" excluído'
            : 'Perfil de acesso excluído';

      case 'restaurar_pedido':
        final produtos = det['produtos']?.toString() ?? '';
        final elementos = det['elementos']?.toString() ?? '';
        final partes = <String>[];
        if (label.isNotEmpty) partes.add('Pedido "$label" restaurado do backup');
        if (produtos.isNotEmpty) partes.add('$produtos produto(s)');
        if (elementos.isNotEmpty) partes.add('$elementos elemento(s)');
        return partes.isNotEmpty
            ? partes.join(' — ')
            : 'Pedido restaurado do backup';

      case 'restaurar_backup_completo':
        return 'Backup completo restaurado';

      default:
        // Fallback genérico
        if (label.isNotEmpty) return label;
        return '';
    }
  }

  Color _corPorAcao(String acao) {
    if (acao.startsWith('excluir')) return Colors.red;
    if (acao.startsWith('arquivar') || acao.startsWith('congelar')) {
      return Colors.orange;
    }
    if (acao.startsWith('desarquivar') || acao.startsWith('descongelar')) {
      return Colors.teal;
    }
    if (acao.startsWith('criar') || acao == 'restaurar_pedido') {
      return Colors.green;
    }
    if (acao.startsWith('editar') || acao == 'mover_etapa') {
      return Colors.blue;
    }
    if (acao == 'login') return Colors.indigo;
    if (acao == 'logout') return Colors.grey;
    return Colors.blueGrey;
  }
}
