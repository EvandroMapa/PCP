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
                    // Cabeçalho
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                              width: 130,
                              child: Text('Data',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          SizedBox(
                              width: 130,
                              child: Text('Usuário',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          SizedBox(
                              width: 180,
                              child: Text('Ação',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          Expanded(
                              child: Text('Entidade',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          SizedBox(
                              width: 130,
                              child: Text('Dispositivo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Data
          SizedBox(
            width: 130,
            child: Text(
              DateFormat('dd/MM/yy HH:mm').format(entry.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),

          // Usuário
          SizedBox(
            width: 130,
            child: Text(
              entry.usuarioNome,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Ação
          SizedBox(
            width: 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: corAcao.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.acaoFormatada,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: corAcao),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Entidade
          Expanded(
            child: Text(
              entry.entidadeLabel ?? entry.entidadeId ?? '—',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Dispositivo
          SizedBox(
            width: 130,
            child: Text(
              entry.dispositivo ?? '—',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
