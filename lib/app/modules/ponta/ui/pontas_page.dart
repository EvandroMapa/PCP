import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/ponta/ponta_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PontasPage extends StatefulWidget {
  const PontasPage({super.key});

  @override
  State<PontasPage> createState() => _PontasPageState();
}

class _PontasPageState extends State<PontasPage> {
  List<PontaBitolaGrupo> _grupos = [];
  bool _carregando = true;
  String? _bitolaAbertaId;

  @override
  void initState() {
    super.initState();
    setWebTitle('Cadastro de Pontas');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([
        Tooltip(
          message: 'Adicionar Bitola',
          child: IconButton(
            onPressed: _adicionarBitola,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ]);
    });
    _carregarPontas();
  }

  Future<void> _carregarPontas() async {
    setState(() => _carregando = true);
    try {
      final data = await SupabaseService.client
          .from('pontas')
          .select()
          .order('bitola_descricao')
          .order('tamanho', ascending: false);
      final pontas = data.map((e) => PontaModel.fromSupabaseMap(e)).toList();

      final Map<String, PontaBitolaGrupo> mapa = {};
      for (final p in pontas) {
        mapa.putIfAbsent(
          p.bitolaId,
          () => PontaBitolaGrupo(
            bitolaId: p.bitolaId,
            bitolaDescricao: p.bitolaDescricao,
            pontas: [],
          ),
        );
        mapa[p.bitolaId]!.pontas.add(p);
      }
      _grupos = mapa.values.toList();
      for (var g in _grupos) {
        g.sort();
      }
    } catch (_) {
      _grupos = [];
    }
    setState(() => _carregando = false);
  }

  // ─── Adicionar bitola (grupo vazio) ───────────────────────────────────────
  Future<void> _adicionarBitola() async {
    final produtos = FirestoreClient.produtos.data.toList();
    if (produtos.isEmpty) return;

    // Filtrar bitolas já cadastradas
    final bitolaIdsExistentes = _grupos.map((g) => g.bitolaId).toSet();
    final disponiveis =
        produtos.where((p) => !bitolaIdsExistentes.contains(p.id)).toList();

    if (disponiveis.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Todas as bitolas já foram adicionadas.')),
        );
      }
      return;
    }

    final selecionado = await showDialog(
      context: context,
      builder: (ctx) => _DialogSelecionarBitola(produtos: disponiveis),
    );
    if (selecionado == null) return;

    // Criar grupo local vazio e abrir
    setState(() {
      _grupos.add(PontaBitolaGrupo(
        bitolaId: selecionado.id,
        bitolaDescricao: '${selecionado.nome} - ${selecionado.descricao}',
        pontas: [],
      ));
      _bitolaAbertaId = selecionado.id;
    });
  }

  // ─── Adicionar ponta dentro de uma bitola ─────────────────────────────────
  Future<void> _adicionarPonta(PontaBitolaGrupo grupo) async {
    final resultado = await showDialog<_PontaResultado>(
      context: context,
      builder: (ctx) => _DialogPonta(bitolaDescricao: grupo.bitolaDescricao),
    );
    if (resultado == null) return;

    try {
      await SupabaseService.client.from('pontas').insert({
        'bitola_id': grupo.bitolaId,
        'bitola_descricao': grupo.bitolaDescricao,
        'tamanho': resultado.tamanho,
        'quantidade': resultado.quantidade,
        'localizador': resultado.localizador,
      });
      _bitolaAbertaId = grupo.bitolaId;
      _carregarPontas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar: $e')),
        );
      }
    }
  }

  // ─── Editar ponta ─────────────────────────────────────────────────────────
  Future<void> _editarPonta(PontaModel ponta) async {
    final resultado = await showDialog<_PontaResultado>(
      context: context,
      builder: (ctx) => _DialogPonta(
        bitolaDescricao: ponta.bitolaDescricao,
        tamanhoInicial: ponta.tamanho,
        quantidadeInicial: ponta.quantidade,
        localizadorInicial: ponta.localizador,
      ),
    );
    if (resultado == null) return;

    try {
      await SupabaseService.client.from('pontas').update({
        'tamanho': resultado.tamanho,
        'quantidade': resultado.quantidade,
        'localizador': resultado.localizador,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', ponta.id);
      _carregarPontas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao editar: $e')),
        );
      }
    }
  }

  // ─── Remover ponta ────────────────────────────────────────────────────────
  Future<void> _removerPonta(PontaModel ponta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover ponta?'),
        content: Text(
            'Remover ponta de ${ponta.tamanho.toStringAsFixed(0)} (qtde: ${ponta.quantidade})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await SupabaseService.client
          .from('pontas')
          .delete()
          .eq('id', ponta.id);
      _carregarPontas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: $e')),
        );
      }
    }
  }

  // ─── Limpar tudo de uma bitola ────────────────────────────────────────────
  Future<void> _limparBitola(PontaBitolaGrupo grupo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar todas as pontas?'),
        content: Text(
            'Remover todas as ${grupo.pontas.length} pontas de ${grupo.bitolaDescricao}? A bitola será removida da lista.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white),
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await SupabaseService.client
          .from('pontas')
          .delete()
          .eq('bitola_id', grupo.bitolaId);
      _bitolaAbertaId = null;
      _carregarPontas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());

    if (_grupos.isEmpty) return const Center(child: EmptyData());

    return RefreshIndicator(
      onRefresh: _carregarPontas,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _grupos.length,
        separatorBuilder: (_, __) => const H(10),
        itemBuilder: (_, i) => _buildGrupoBitola(_grupos[i]),
      ),
    );
  }

  Widget _buildGrupoBitola(PontaBitolaGrupo grupo) {
    final aberta = _bitolaAbertaId == grupo.bitolaId;
    final temPontas = grupo.pontas.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header da bitola
          InkWell(
            onTap: () => setState(() {
              _bitolaAbertaId = aberta ? null : grupo.bitolaId;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: aberta ? AppColors.primaryMain : Colors.grey[100],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: aberta
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.primaryMain.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.straighten,
                      size: 18,
                      color: aberta ? Colors.white : AppColors.primaryMain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.bitolaDescricao,
                          style: AppCss.smallBold.setSize(14).setColor(
                              aberta ? Colors.white : Colors.grey[800]!),
                        ),
                        if (temPontas)
                          Text(
                            '${grupo.totalPecas} ponta${grupo.totalPecas > 1 ? 's' : ''} · Peso total: ${grupo.totalPeso.toStringAsFixed(1)} kg',
                            style: AppCss.minimumRegular.setSize(11).setColor(
                                aberta
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.grey[600]!),
                          )
                        else
                          Text(
                            'Nenhuma ponta cadastrada',
                            style: AppCss.minimumRegular.setSize(11).setColor(
                                aberta
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.grey[500]!),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    aberta ? Icons.expand_less : Icons.expand_more,
                    color: aberta ? Colors.white : Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo expandido
          if (aberta) ...[
            const Divisor(),
            if (temPontas) ...[
              _buildTabelaPontas(grupo),
              // Peso total dentro da sub-lista
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: Colors.grey[50],
                child: Text(
                  'Total: ${grupo.totalPecas} ponta${grupo.totalPecas > 1 ? 's' : ''} · Peso: ${grupo.totalPeso.toStringAsFixed(1)} kg',
                  style: AppCss.minimumBold
                      .setSize(12)
                      .setColor(Colors.grey[700]!),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
            // Ações
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Adicionar ponta
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adicionarPonta(grupo),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Ponta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        side: BorderSide(
                            color:
                                AppColors.primaryMain.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (temPontas) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _limparBitola(grupo),
                      icon: Icon(Icons.delete_sweep,
                          size: 16, color: Colors.red[600]),
                      label: Text('Limpar',
                          style: AppCss.minimumBold
                              .setSize(12)
                              .setColor(Colors.red[600]!)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabelaPontas(PontaBitolaGrupo grupo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.3),
          3: FlexColumnWidth(1.3),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(2),
          6: FixedColumnWidth(72),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            children: [
              _headerCell('Comprimento (cm)', columnId: 'tamanho', grupo: grupo),
              _headerCell('Qtde', columnId: 'quantidade', grupo: grupo),
              _headerCell('Peso Uni.'),
              _headerCell('Peso Total'),
              _headerCell('Localizador', columnId: 'localizador', grupo: grupo),
              _headerCell('Origem'),
              _headerCell(''),
            ],
          ),
          ...grupo.pontas.asMap().entries.map((e) {
            final idx = e.key;
            final p = e.value;
            return TableRow(
              decoration: BoxDecoration(
                color: idx.isOdd ? Colors.grey[50] : Colors.white,
              ),
              children: [
                _dataCell(p.tamanho.toStringAsFixed(0)),
                _dataCell('${p.quantidade}'),
                _dataCell(_pesoUnitario(grupo, p),
                    cor: Colors.grey[600]),
                _dataCell(_pesoTotal(grupo, p),
                    cor: Colors.teal[700]),
                _dataCell(_localizadorLabel(p),
                    cor: _localizadorLabel(p) == '—' ? Colors.grey[400]! : null),
                _dataCell(_origemLabel(p),
                    cor: p.ordemId == null ? Colors.grey[400]! : Colors.teal[700]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _editarPonta(p),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: Colors.blue[600]),
                        ),
                      ),
                      InkWell(
                        onTap: () => _removerPonta(p),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 16, color: Colors.red[400]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String texto, {String? columnId, PontaBitolaGrupo? grupo}) {
    if (columnId == null || grupo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(texto,
            style: AppCss.minimumBold.setSize(14).setColor(Colors.black)),
      );
    }

    final isSorted = grupo.sortColumn == columnId;
    final isAsc = grupo.sortAscending;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSorted) {
            grupo.sortAscending = !isAsc;
          } else {
            grupo.sortColumn = columnId;
            // Para tamanho/quantidade costuma ser melhor decrescente, mas vamos padronizar crescente inicial
            grupo.sortAscending = true;
          }
          grupo.sort();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto,
                style: AppCss.minimumBold.setSize(14).setColor(
                    isSorted ? AppColors.primaryMain : Colors.black)),
            const SizedBox(width: 4),
            Icon(
              isAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isSorted ? AppColors.primaryMain : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String texto, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(texto,
          style: AppCss.minimumRegular
              .setSize(16)
              .setColor(cor ?? Colors.black)),
    );
  }

  String _origemLabel(PontaModel p) {
    if (p.ordemId == null || p.ordemId!.isEmpty) return '—';
    try {
      final ordem = FirestoreClient.ordens.data
          .firstWhere((o) => o.id == p.ordemId);
      return ordem.localizator;
    } catch (_) {
      return p.ordemId!;
    }
  }

  /// Peso de 1 ponta: (tamanho_cm / 100) * massaFinal
  String _pesoUnitario(PontaBitolaGrupo grupo, PontaModel p) {
    try {
      final produto = FirestoreClient.produtos.data
          .firstWhere((pr) => pr.id == grupo.bitolaId);
      final peso = (p.tamanho / 100) * produto.massaFinal;
      return '${peso.toStringAsFixed(2)} kg';
    } catch (_) {
      return '—';
    }
  }

  /// Peso total da linha: peso unitário × quantidade
  String _pesoTotal(PontaBitolaGrupo grupo, PontaModel p) {
    try {
      final produto = FirestoreClient.produtos.data
          .firstWhere((pr) => pr.id == grupo.bitolaId);
      final peso = (p.tamanho / 100) * produto.massaFinal * p.quantidade;
      return '${peso.toStringAsFixed(2)} kg';
    } catch (_) {
      return '—';
    }
  }

  /// Retorna o localizador do pedido vinculado à ordem (se for de plano)
  /// ou o localizador original da ponta.
  String _localizadorLabel(PontaModel p) {
    if (p.ordemId != null && p.ordemId!.isNotEmpty) {
      try {
        final ordem = FirestoreClient.ordens.data
            .firstWhere((o) => o.id == p.ordemId);
        final pedidosLocalizadores =
            ordem.pedidos.map((e) => e.localizador).join(', ');
        if (pedidosLocalizadores.isNotEmpty) {
          return pedidosLocalizadores;
        }
      } catch (_) {}
    }
    return p.localizador.isEmpty ? '—' : p.localizador;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Resultado de dialog
// ═══════════════════════════════════════════════════════════════════════════════
class _PontaResultado {
  final double tamanho;
  final int quantidade;
  final String localizador;
  _PontaResultado(
      {required this.tamanho,
      required this.quantidade,
      required this.localizador});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dialog Selecionar Bitola
// ═══════════════════════════════════════════════════════════════════════════════
class _DialogSelecionarBitola extends StatelessWidget {
  final List produtos;
  const _DialogSelecionarBitola({required this.produtos});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Bitola'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.separated(
          itemCount: produtos.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = produtos[i];
            return ListTile(
              leading: Icon(Icons.straighten, color: AppColors.primaryMain),
              title: Text('${p.nome} - ${p.descricao}',
                  style: AppCss.minimumRegular.setSize(14)),
              onTap: () => Navigator.of(context).pop(p),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dialog Ponta (novo/editar)
// ═══════════════════════════════════════════════════════════════════════════════
class _DialogPonta extends StatefulWidget {
  final String bitolaDescricao;
  final double? tamanhoInicial;
  final int? quantidadeInicial;
  final String? localizadorInicial;

  const _DialogPonta({
    required this.bitolaDescricao,
    this.tamanhoInicial,
    this.quantidadeInicial,
    this.localizadorInicial,
  });

  @override
  State<_DialogPonta> createState() => _DialogPontaState();
}

class _DialogPontaState extends State<_DialogPonta> {
  late final TextEditingController _tamanhoCtrl;
  late final TextEditingController _quantidadeCtrl;
  late final TextEditingController _localizadorCtrl;

  late final FocusNode _quantidadeFocus;
  late final FocusNode _localizadorFocus;

  bool get _editando => widget.tamanhoInicial != null;

  @override
  void initState() {
    super.initState();
    _tamanhoCtrl = TextEditingController(
        text: widget.tamanhoInicial?.toStringAsFixed(0) ?? '');
    _quantidadeCtrl = TextEditingController(
        text: (widget.quantidadeInicial ?? 1).toString());
    _localizadorCtrl =
        TextEditingController(text: widget.localizadorInicial ?? '');

    _quantidadeFocus = FocusNode();
    _localizadorFocus = FocusNode();
  }

  @override
  void dispose() {
    _tamanhoCtrl.dispose();
    _quantidadeCtrl.dispose();
    _localizadorCtrl.dispose();
    _quantidadeFocus.dispose();
    _localizadorFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editando
          ? 'Editar Ponta — ${widget.bitolaDescricao}'
          : 'Nova Ponta — ${widget.bitolaDescricao}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tamanhoCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _quantidadeFocus.requestFocus(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Comprimento (cm)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const H(12),
            TextField(
              controller: _quantidadeCtrl,
              focusNode: _quantidadeFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _localizadorFocus.requestFocus(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantidade',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const H(12),
            TextField(
              controller: _localizadorCtrl,
              focusNode: _localizadorFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirmar(),
              decoration: InputDecoration(
                labelText: 'Localizador (opcional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
          ),
          child: Text(_editando ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }

  void _confirmar() {
    final tamanho =
        double.tryParse(_tamanhoCtrl.text.replaceAll(',', '.').trim());
    final qtde = int.tryParse(_quantidadeCtrl.text.trim());
    if (tamanho == null || tamanho <= 0) return;
    Navigator.of(context).pop(_PontaResultado(
      tamanho: tamanho,
      quantidade: qtde ?? 1,
      localizador: _localizadorCtrl.text.trim(),
    ));
  }
}
