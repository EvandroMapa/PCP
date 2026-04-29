
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/modules/ponta/ponta_model.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_engine.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_gravado_model.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PlanoCorteRelatorioPage extends StatefulWidget {
  final PlanoCorteGravadoModel? planoParaEditar;
  const PlanoCorteRelatorioPage({super.key, this.planoParaEditar});

  @override
  State<PlanoCorteRelatorioPage> createState() =>
      _PlanoCorteRelatorioPageState();
}

class _PlanoCorteRelatorioPageState extends State<PlanoCorteRelatorioPage> {
  // ─── Estado ────────────────────────────────────────────────────────────────
  OrdemModel? _ordemSelecionada;
  final List<_MateriaPrimaItem> _materiaPrima = [_MateriaPrimaItem.padrao()];
  PlanoCorteResultado? _resultado;
  bool _carregando = false;
  bool _salvando = false;
  bool _exportandoPdf = false;
  bool _executando = false;
  List<ElementoModel>? _elementosOrdem;
  final TextEditingController _descricaoCtrl = TextEditingController();

  bool get _editando => widget.planoParaEditar != null;
  String? get _planoId => widget.planoParaEditar?.id;
  String get _planoStatus => widget.planoParaEditar?.status ?? 'pendente';
  bool get _planoExecutado => _planoStatus == 'executado';

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _inicializarEdicao();
    }
  }

  Future<void> _inicializarEdicao() async {
    final plano = widget.planoParaEditar!;
    _descricaoCtrl.text = plano.descricao;

    // Restaurar matéria prima
    _materiaPrima.clear();
    for (final mp in plano.materiaPrimaJson) {
      final pontaId = mp['ponta_id']?.toString();
      if (pontaId != null) {
        // Restaurar como ponta importada
        try {
          final pontaData = await SupabaseService.client
              .from('pontas')
              .select()
              .eq('id', pontaId)
              .maybeSingle();
          if (pontaData != null) {
            final ponta = PontaModel.fromSupabaseMap(pontaData);
            _materiaPrima.add(_MateriaPrimaItem.dePonta(ponta));
            continue;
          }
        } catch (_) {}
        // Se não encontrar a ponta, cai no fluxo padrão
      }
      final item = _MateriaPrimaItem();
      item.comprimentoCtrl.text = (mp['comprimento'] ?? 0).toString();
      item.isIlimitado = mp['ilimitado'] == true;
      if (!item.isIlimitado) {
        item.quantidadeCtrl.text = (mp['quantidade'] ?? '').toString();
      }
      _materiaPrima.add(item);
    }
    if (_materiaPrima.isEmpty) _materiaPrima.add(_MateriaPrimaItem.padrao());

    // Encontrar e selecionar a ordem
    setState(() => _carregando = true);
    try {
      final ordens = FirestoreClient.ordens.ordensNaoArquivadas
          .where((o) => o.id == plano.ordemId)
          .toList();
      if (ordens.isNotEmpty) {
        _ordemSelecionada = ordens.first;
        await _carregarElementosOrdem(_ordemSelecionada!);
        // Auto-gerar resultado para edição
        _gerarPlanoCorte();
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _resultado == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final sair = await _confirmarSairSemSalvar();
        if (sair && mounted) Navigator.of(context).pop();
      },
      child: AppScaffold(
        backgroundColor: AppColors.neutralLightest,
        appBar: AppBar(
          title: Text(_editando ? 'Editar Plano de Corte' : 'Plano de Corte',
              style: AppCss.largeBold.setColor(AppColors.white)),
          backgroundColor: AppColors.primaryMain,
          iconTheme: IconThemeData(color: AppColors.white),
          actions: [
            if (_resultado != null) ...[
              IconButton(
                onPressed: _exportandoPdf ? null : _exportarPdf,
                tooltip: 'Exportar PDF',
                icon: _exportandoPdf
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf, color: Colors.white),
              ),
              IconButton(
                onPressed: _salvando ? null : _salvarPlanoCorte,
                tooltip: 'Salvar',
                icon: _salvando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, color: Colors.white),
              ),
            ],
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _buildConteudo(),
      ),
    );
  }

  Future<bool> _confirmarSairSemSalvar() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
            'O plano de corte ainda não foi salvo. Deseja sair mesmo assim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Widget _buildConteudo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Passo 1: Selecionar Ordem ──
        _buildSecao(
          titulo: 'Passo 1 — Selecionar Ordem de Produção',
          icone: Icons.assignment,
          child: _editando ? _buildOrdemTravada() : _buildSeletorOrdem(),
        ),
        const H(16),

        // ── Passo 2: Matéria Prima ──
        _buildSecao(
          titulo: 'Passo 2 — Matéria Prima (Barras)',
          icone: Icons.straighten,
          child: _buildMateriaPrima(),
        ),
        const H(16),

        // ── Descrição ──
        TextField(
          controller: _descricaoCtrl,
          readOnly: _planoExecutado,
          enabled: !_planoExecutado,
          decoration: InputDecoration(
            hintText: 'Descrição do plano (opcional)',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(Icons.notes, size: 18, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const H(24),

        // ── Botões Gerar / Executar ──
        if (_ordemSelecionada != null && _materiaPrima.isNotEmpty)
          Row(
            children: [
              if (!_planoExecutado)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _gerarPlanoCorte,
                      icon: const Icon(Icons.content_cut, size: 20),
                      label: Text(
                          _resultado != null ? 'RECALCULAR PLANO' : 'GERAR PLANO DE CORTE',
                          style: AppCss.smallBold.setColor(Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
              if (_resultado != null && _editando) ...[
                const SizedBox(width: 12),
                if (_planoExecutado)
                  // Plano já executado — botão Cancelar Execução
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _executando ? null : _cancelarExecucao,
                      icon: _executando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.undo, size: 20),
                      label: Text('CANCELAR EXECUÇÃO',
                          style: AppCss.smallBold.setColor(Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  )
                else
                  // Plano pendente — botão Executar
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _executando ? null : _executarPlano,
                      icon: _executando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text('EXECUTAR PLANO',
                          style: AppCss.smallBold.setColor(Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
              ],
            ],
          ),

        // ── Resultado inline ──
        if (_resultado != null) ...[
          const H(24),
          _buildResultadoInline(),
        ],
      ],
    );
  }

  // ── Seção genérica ──
  Widget _buildSecao(
      {required String titulo,
      required IconData icone,
      required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icone, size: 20, color: AppColors.primaryMain),
              const SizedBox(width: 10),
              Text(titulo, style: AppCss.smallBold),
            ]),
          ),
          const Divisor(),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ── Seletor de Ordem ──
  Widget _buildSeletorOrdem() {
    final ordensAtivas = FirestoreClient.ordens.ordensNaoArquivadas
        .where((o) => !o.freezed.isFreezed && o.id.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<OrdemModel>(
          initialValue: _ordemSelecionada,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Selecione uma ordem...',
            hintStyle: AppCss.smallRegular.setColor(Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: ordensAtivas.map((o) {
            return DropdownMenuItem(
              value: o,
              child: Text(
                '${o.localizator} — ${o.produto.descricao}',
                style: AppCss.minimumRegular,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (o) async {
            _ordemSelecionada = o;
            _resultado = null;
            _elementosOrdem = null;
            setState(() {});
            if (o != null) await _carregarElementosOrdem(o);
          },
        ),
        if (_ordemSelecionada != null && _elementosOrdem != null) ...[
          const H(12),
          _buildResumoOrdem(),
        ],
      ],
    );
  }

  // ── Ordem travada (edição) ──
  Widget _buildOrdemTravada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _ordemSelecionada != null
                      ? '${_ordemSelecionada!.localizator} — ${_ordemSelecionada!.produto.descricao}'
                      : widget.planoParaEditar?.ordemLocalizator ?? '',
                  style: AppCss.minimumRegular.setColor(Colors.grey[700]!),
                ),
              ),
            ],
          ),
        ),
        if (_ordemSelecionada != null && _elementosOrdem != null) ...[
          const H(12),
          _buildResumoOrdem(),
        ],
      ],
    );
  }

  // ── Resumo da ordem selecionada ──
  Widget _buildResumoOrdem() {
    if (_elementosOrdem == null) return const SizedBox.shrink();
    int totalPosicoes = 0;
    int posicoesSemCorte = 0;
    for (final e in _elementosOrdem!) {
      for (final p in e.posicoes) {
        totalPosicoes++;
        if (p.comprCorte <= 0) posicoesSemCorte++;
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_elementosOrdem!.length} elementos • $totalPosicoes posições',
            style: AppCss.minimumBold,
          ),
          if (posicoesSemCorte > 0) ...[
            const H(4),
            Text(
              '⚠ $posicoesSemCorte posições sem comprimento de corte definido (serão ignoradas)',
              style: AppCss.minimumRegular.setColor(Colors.orange[800]!),
            ),
          ],
        ],
      ),
    );
  }

  // ── Matéria Prima ──
  Widget _buildMateriaPrima() {
    return Column(
      children: [
        ..._materiaPrima.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Badge ponta
                if (item.isPonta)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: 'Importada do Cadastro de Pontas',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber[300]!),
                        ),
                        child: Icon(Icons.recycling, size: 16, color: Colors.amber[800]),
                      ),
                    ),
                  ),
                // Comprimento
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: item.comprimentoCtrl,
                    readOnly: _planoExecutado || item.isPonta,
                    enabled: !_planoExecutado && !item.isPonta,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.,]')),
                    ],
                    style: AppCss.minimumRegular,
                    decoration: InputDecoration(
                      labelText: item.isPonta ? 'Ponta (cm)' : 'Comprimento',
                      labelStyle: AppCss.minimumRegular.setColor(
                          item.isPonta ? Colors.amber[800]! : Colors.grey),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Quantidade
                Expanded(
                  flex: 2,
                  child: item.isIlimitado
                      ? Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text('ILIMITADO',
                              style: AppCss.minimumBold
                                  .setColor(Colors.green[700]!)),
                        )
                      : TextFormField(
                          controller: item.quantidadeCtrl,
                          readOnly: _planoExecutado || item.isPonta,
                          enabled: !_planoExecutado && !item.isPonta,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppCss.minimumRegular,
                          decoration: InputDecoration(
                            labelText: 'Qtde',
                            labelStyle:
                                AppCss.minimumRegular.setColor(Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                // Toggle ilimitado — oculto para pontas
                if (!_planoExecutado && !item.isPonta)
                  Tooltip(
                    message:
                        item.isIlimitado ? 'Definir quantidade' : 'Ilimitado',
                    child: IconButton(
                      onPressed: () {
                        setState(() => item.isIlimitado = !item.isIlimitado);
                      },
                      icon: Icon(
                        item.isIlimitado ? Icons.all_inclusive : Icons.pin,
                        size: 20,
                        color: item.isIlimitado
                            ? Colors.green[600]
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                // Espaçador para pontas (manter alinhamento)
                if (!_planoExecutado && item.isPonta)
                  const SizedBox(width: 48),
                // Remover
                if (!_planoExecutado)
                  IconButton(
                    onPressed: () =>
                        setState(() => _materiaPrima.removeAt(idx)),
                    icon: Icon(Icons.close, size: 18, color: Colors.red[400]),
                  ),
              ],
            ),
          );
        }),
        const H(8),
        if (!_planoExecutado)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _materiaPrima.add(_MateriaPrimaItem())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar Barra'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryMain,
                  side: BorderSide(color: AppColors.primaryMain.withValues(alpha: 0.3)),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (_ordemSelecionada != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _importarPontas,
                  icon: Icon(Icons.recycling, size: 18, color: Colors.amber[800]),
                  label: Text('Importar Pontas',
                      style: TextStyle(color: Colors.amber[900])),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber[300]!),
                    backgroundColor: Colors.amber[50],
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // ─── Importar pontas do cadastro ───────────────────────────────────────────
  Future<void> _importarPontas() async {
    if (_ordemSelecionada == null) return;
    final bitolaId = _ordemSelecionada!.produto.id;

    // Buscar pontas disponíveis da mesma bitola
    final data = await SupabaseService.client
        .from('pontas')
        .select()
        .eq('bitola_id', bitolaId)
        .order('tamanho', ascending: false);
    final pontasDisponiveis =
        data.map((e) => PontaModel.fromSupabaseMap(e)).toList();

    // Filtrar pontas já importadas na lista atual
    final idsJaImportados = _materiaPrima
        .where((m) => m.isPonta)
        .map((m) => m.pontaOrigem!.id)
        .toSet();
    final pontasFiltradas =
        pontasDisponiveis.where((p) => !idsJaImportados.contains(p.id)).toList();

    if (pontasFiltradas.isEmpty) {
      NotificationService.showNeutral(
        'Sem pontas disponíveis',
        'Não há pontas dessa bitola no cadastro para importar.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    if (!mounted) return;

    // Dialog: importar todas ou escolher?
    final opcao = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.recycling, size: 40, color: Colors.amber[800]),
        title: const Text('Importar Pontas'),
        content: Text(
            '${pontasFiltradas.length} ponta${pontasFiltradas.length > 1 ? 's' : ''} disponíve${pontasFiltradas.length > 1 ? 'is' : 'l'} para esta bitola.\n\nDeseja importar todas ou escolher individualmente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('escolher'),
            child: const Text('Escolher'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('todas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Importar Todas'),
          ),
        ],
      ),
    );

    if (opcao == null) return;

    if (opcao == 'todas') {
      setState(() {
        for (final p in pontasFiltradas) {
          _materiaPrima.add(_MateriaPrimaItem.dePonta(p));
        }
      });
      NotificationService.showPositive(
        'Pontas Importadas',
        '${pontasFiltradas.length} ponta${pontasFiltradas.length > 1 ? 's' : ''} adicionada${pontasFiltradas.length > 1 ? 's' : ''} à matéria prima.',
        position: NotificationPosition.bottom,
      );
    } else {
      // Dialog de seleção individual
      if (!mounted) return;
      final selecionadas = await showDialog<List<PontaModel>>(
        context: context,
        builder: (ctx) => _DialogSelecionarPontas(pontas: pontasFiltradas),
      );
      if (selecionadas == null || selecionadas.isEmpty) return;
      setState(() {
        for (final p in selecionadas) {
          _materiaPrima.add(_MateriaPrimaItem.dePonta(p));
        }
      });
      NotificationService.showPositive(
        'Pontas Importadas',
        '${selecionadas.length} ponta${selecionadas.length > 1 ? 's' : ''} adicionada${selecionadas.length > 1 ? 's' : ''} à matéria prima.',
        position: NotificationPosition.bottom,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULTADO (inline no ListView)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResultadoInline() {
    final r = _resultado!;
    final layouts = _agruparLayouts(r.barrasUsadas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divisor(),
        const H(8),
        Text('Resultado — ${_ordemSelecionada!.localizator}',
            style: AppCss.mediumBold),
        const H(12),
        // Resumo
        _buildResumoGeral(r),
        if (r.temFalta) ...[
          const H(12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r.pecasNaoAlocadas.length} peça(s) não puderam ser alocadas (falta de matéria prima)',
                    style: AppCss.minimumBold.setColor(Colors.red[700]!),
                  ),
                ),
              ],
            ),
          ),
        ],
        const H(16),
        // Layouts
        ...layouts.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBarraCard(e.value.barra, e.key + 1, e.value.quantidade),
            )),
        // Peças não alocadas
        if (r.temFalta)
          _buildFaltaCard(r.pecasNaoAlocadas),
      ],
    );
  }

  Widget _buildResumoGeral(PlanoCorteResultado r) {
    final Map<double, List<BarraUsadaModel>> porTamanho = {};
    for (final b in r.barrasUsadas) {
      porTamanho.putIfAbsent(b.comprimentoTotal, () => []).add(b);
    }

    final tamanhos = porTamanho.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Matéria Prima', style: AppCss.minimumBold.setColor(Colors.grey[700]!))),
                Expanded(flex: 1, child: Text('Barras Usadas', style: AppCss.minimumBold.setColor(Colors.grey[700]!), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Sobra (cm)', style: AppCss.minimumBold.setColor(Colors.grey[700]!), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Aproveitamento', style: AppCss.minimumBold.setColor(Colors.grey[700]!), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Itens
          for (final size in tamanhos) ...[
            Builder(builder: (_) {
              final barras = porTamanho[size]!;
              final qtde = barras.length;
              final sobra = barras.fold(0.0, (s, b) => s + b.sobra);
              final usado = barras.fold(0.0, (s, b) => s + b.comprimentoUsado);
              final total = barras.fold(0.0, (s, b) => s + b.comprimentoTotal);
              final aproveitamento = total > 0 ? (usado / total) * 100 : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('Barra ${size.toStringAsFixed(0)}', style: AppCss.minimumRegular)),
                    Expanded(flex: 1, child: Text('$qtde', style: AppCss.minimumRegular, textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text(sobra.toStringAsFixed(1), style: AppCss.minimumRegular, textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text('${aproveitamento.toStringAsFixed(1)}%', style: AppCss.minimumBold.setColor(Colors.green[700]!), textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
          ],
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('TOTAL GERAL', style: AppCss.minimumBold.setColor(AppColors.primaryMain))),
                Expanded(flex: 1, child: Text('${r.totalBarrasUsadas}', style: AppCss.mediumBold.setColor(AppColors.primaryMain), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text(r.totalSobra.toStringAsFixed(1), style: AppCss.mediumBold.setColor(AppColors.primaryMain), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('${r.percentualAproveitamento.toStringAsFixed(1)}%', style: AppCss.mediumBold.setColor(Colors.green[700]!), textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraCard(BarraUsadaModel barra, int numero, int repeticoes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('${numero.toString().padLeft(2, '0')}',
                      style: AppCss.minimumBold.setColor(Colors.white).setSize(11)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Layout ${numero.toString().padLeft(2, '0')} — Comprimento ${barra.comprimentoTotal.toStringAsFixed(1)} — Repetir $repeticoes vez${repeticoes > 1 ? 'es' : ''}',
                    style: AppCss.smallBold.setSize(13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _corAproveitamento(barra.percentualUso)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${barra.percentualUso.toStringAsFixed(1)}% uso',
                    style: AppCss.minimumBold
                        .setColor(_corAproveitamento(barra.percentualUso)),
                  ),
                ),
              ],
            ),
          ),
          // Barra visual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildBarraVisual(barra),
          ),
          // Cortes listados
          ...barra.cortes.map((c) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.content_cut,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${c.peca.pedidoLocalizador} · ${c.peca.elementoNome} · OS ${c.peca.numeroOs}',
                        style: AppCss.minimumRegular.setSize(12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(c.comprCorte.toStringAsFixed(1),
                        style: AppCss.minimumBold),
                  ],
                ),
              )),
          // Sobra
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(Icons.recycling, size: 14, color: Colors.orange[400]),
                const SizedBox(width: 6),
                Text('Sobra: ${barra.sobra.toStringAsFixed(1)}',
                    style: AppCss.minimumRegular
                        .setColor(Colors.orange[700]!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraVisual(BarraUsadaModel barra) {
    if (barra.comprimentoTotal <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            ...barra.cortes.asMap().entries.map((e) {
              final frac = e.value.comprCorte / barra.comprimentoTotal;
              final cores = [
                Colors.blue[400]!,
                Colors.teal[400]!,
                Colors.indigo[400]!,
                Colors.cyan[400]!,
                Colors.purple[300]!,
              ];
              return Flexible(
                flex: (frac * 1000).round().clamp(1, 1000),
                child: Container(
                  color: cores[e.key % cores.length],
                  height: 24,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        e.value.comprCorte.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (barra.sobra > 0)
              Flexible(
                flex: ((barra.sobra / barra.comprimentoTotal) * 1000)
                    .round()
                    .clamp(1, 1000),
                child: Container(
                  color: Colors.grey[200],
                  height: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaltaCard(List<PecaDemandaModel> naoAlocadas) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text('Peças não alocadas (${naoAlocadas.length})',
                style: AppCss.smallBold.setColor(Colors.red[700]!)),
          ]),
          const H(8),
          ...naoAlocadas.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        '${p.elementoNome} → ${p.posicaoNome}  (${p.comprCorte.toStringAsFixed(1)})',
                        style: AppCss.minimumRegular,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _corAproveitamento(double pct) {
    if (pct >= 90) return Colors.green[700]!;
    if (pct >= 70) return Colors.blue[600]!;
    if (pct >= 50) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  /// Agrupa barras com layout de corte idêntico (mesmo comprimento e mesmos cortes).
  List<_LayoutAgrupado> _agruparLayouts(List<BarraUsadaModel> barras) {
    final List<_LayoutAgrupado> layouts = [];
    for (final barra in barras) {
      final chave = _chaveLayout(barra);
      final existente = layouts.where((l) => l.chave == chave).firstOrNull;
      if (existente != null) {
        existente.quantidade++;
      } else {
        layouts.add(_LayoutAgrupado(barra: barra, chave: chave));
      }
    }
    return layouts;
  }

  String _chaveLayout(BarraUsadaModel barra) {
    final cortes = barra.cortes.map((c) => c.comprCorte.toStringAsFixed(2)).join('|');
    return '${barra.comprimentoTotal.toStringAsFixed(2)}_$cortes';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LÓGICA
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _carregarElementosOrdem(OrdemModel ordem) async {
    setState(() => _carregando = true);
    try {
      // Pega todos os pedidoIds dessa ordem
      final pedidoIds = ordem.idPedidosProdutosRefs
          .map((ref) => ref['pedidoId'] ?? ref['pedido_id'] ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (pedidoIds.isEmpty) {
        _elementosOrdem = [];
        setState(() => _carregando = false);
        return;
      }

      // Busca elementos desses pedidos
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .filter('pedido_id', 'in', pedidoIds);

      if (elementosRaw.isEmpty) {
        _elementosOrdem = [];
        setState(() => _carregando = false);
        return;
      }

      final eIds = elementosRaw.map((e) => e['id'].toString()).toList();

      final posicoesRaw = await SupabaseService.client
          .from('elemento_posicoes')
          .select()
          .filter('elemento_id', 'in', eIds);

      // Filtra posições pela bitola da ordem
      final bitolaId = ordem.produto.id;
      final posicoesFiltradas = List<Map<String, dynamic>>.from(posicoesRaw)
          .where((p) => p['produto_id'].toString() == bitolaId)
          .toList();

      _elementosOrdem = elementosRaw.map((e) {
        final eId = e['id'].toString();
        return ElementoModel.fromSupabaseMap(
          e,
          posicoesRaw: posicoesFiltradas
              .where((p) => p['elemento_id'].toString() == eId)
              .toList(),
        );
      }).toList();

      // Remover elementos sem posições relevantes
      _elementosOrdem!.removeWhere((e) => e.posicoes.isEmpty);
    } catch (e) {
      _elementosOrdem = [];
    }
    setState(() => _carregando = false);
  }

  void _gerarPlanoCorte() {
    if (_elementosOrdem == null || _elementosOrdem!.isEmpty) return;

    // Montar demandas
    final List<PecaDemandaModel> demandas = [];
    for (final elem in _elementosOrdem!) {
      for (final pos in elem.posicoes) {
        if (pos.comprCorte <= 0) continue;
        // Pega localizador do pedido se possível
        String localizador = '';
        try {
          final pedido = FirestoreClient.pedidos.getById(elem.pedidoId);
          localizador = pedido.localizador;
        } catch (_) {}

        demandas.add(PecaDemandaModel(
          elementoNome: elem.nome,
          posicaoNome: pos.nome,
          numeroOs: pos.numeroOs,
          pedidoLocalizador: localizador,
          comprCorte: pos.comprCorte,
          quantidade: elem.qtde,
        ));
      }
    }

    if (demandas.isEmpty) {
      NotificationService.showNegative(
        'Sem posições',
        'Nenhuma posição com comprimento de corte encontrada.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    // Montar estoque
    final List<MateriaPrimaBarraModel> estoque = [];
    for (final item in _materiaPrima) {
      final comprStr =
          item.comprimentoCtrl.text.replaceAll(',', '.').trim();
      final compr = double.tryParse(comprStr);
      if (compr == null || compr <= 0) continue;

      int? qtde;
      if (!item.isIlimitado) {
        qtde = int.tryParse(item.quantidadeCtrl.text.trim());
        if (qtde == null || qtde <= 0) continue;
      }

      estoque.add(MateriaPrimaBarraModel(
        comprimento: compr,
        quantidade: qtde,
      ));
    }

    if (estoque.isEmpty) {
      NotificationService.showNegative(
        'Matéria prima inválida',
        'Informe ao menos uma barra de matéria prima válida.',
        position: NotificationPosition.bottom,
      );
      return;
    }

    // Calcular
    final resultado = PlanoCorteEngine.calcular(
      demandas: demandas,
      estoque: estoque,
    );

    setState(() => _resultado = resultado);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SALVAR NO SUPABASE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _salvarPlanoCorte() async {
    if (_resultado == null || _ordemSelecionada == null) return;
    setState(() => _salvando = true);

    try {
      final r = _resultado!;
      final ordem = _ordemSelecionada!;

      // Serializar resultado
      final resultadoJson = {
        'barras_usadas': r.barrasUsadas
            .map((b) => {
                  'comprimento_total': b.comprimentoTotal,
                  'cortes': b.cortes
                      .map((c) => {
                            'compr_corte': c.comprCorte,
                            'elemento_nome': c.peca.elementoNome,
                            'posicao_nome': c.peca.posicaoNome,
                            'numero_os': c.peca.numeroOs,
                            'pedido_localizador': c.peca.pedidoLocalizador,
                          })
                      .toList(),
                })
            .toList(),
        'pecas_nao_alocadas': r.pecasNaoAlocadas
            .map((p) => {
                  'elemento_nome': p.elementoNome,
                  'posicao_nome': p.posicaoNome,
                  'numero_os': p.numeroOs,
                  'pedido_localizador': p.pedidoLocalizador,
                  'compr_corte': p.comprCorte,
                })
            .toList(),
      };

      // Serializar matéria prima usada
      final materiaPrimaJson = _materiaPrima
          .map((m) => {
                'comprimento': double.tryParse(
                        m.comprimentoCtrl.text.replaceAll(',', '.').trim()) ??
                    0,
                'quantidade': m.isIlimitado
                    ? null
                    : int.tryParse(m.quantidadeCtrl.text.trim()),
                'ilimitado': m.isIlimitado,
                if (m.isPonta) 'ponta_id': m.pontaOrigem!.id,
                if (m.isPonta) 'ponta_quantidade_original': m.pontaOrigem!.quantidade,
              })
          .toList();

      // Contar elementos e posições
      final totalElementos = _elementosOrdem?.length ?? 0;
      final totalPosicoes =
          _elementosOrdem?.fold(0, (sum, e) => sum + e.posicoes.length) ?? 0;

      if (_editando && _planoId != null) {
        // Update
        await SupabaseService.client.from('planos_corte').update({
          'bitola_descricao': ordem.produto.descricao,
          'descricao': _descricaoCtrl.text.trim(),
          'total_barras_usadas': r.totalBarrasUsadas,
          'percentual_aproveitamento': r.percentualAproveitamento,
          'total_sobra': r.totalSobra,
          'total_elementos': totalElementos,
          'total_posicoes': totalPosicoes,
          'resultado_json': resultadoJson,
          'materia_prima_json': materiaPrimaJson,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _planoId!);
      } else {
        // Insert
        await SupabaseService.client.from('planos_corte').insert({
          'ordem_id': ordem.id,
          'ordem_localizator': ordem.localizator,
          'bitola_descricao': ordem.produto.descricao,
          'descricao': _descricaoCtrl.text.trim(),
          'total_barras_usadas': r.totalBarrasUsadas,
          'percentual_aproveitamento': r.percentualAproveitamento,
          'total_sobra': r.totalSobra,
          'total_elementos': totalElementos,
          'total_posicoes': totalPosicoes,
          'resultado_json': resultadoJson,
          'materia_prima_json': materiaPrimaJson,
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showNegative(
          'Erro ao salvar',
          e.toString(),
          position: NotificationPosition.bottom,
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXECUTAR PLANO — marca como executado e cadastra sobras nas Pontas
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _executarPlano() async {
    if (_resultado == null || _ordemSelecionada == null || _planoId == null) return;

    // Verificar se a ordem já tem algum plano executado
    try {
      final planosExistentes = await SupabaseService.client
          .from('planos_corte')
          .select('id')
          .eq('ordem_id', _ordemSelecionada!.id)
          .eq('status', 'executado');
      if (planosExistentes.isNotEmpty) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
              title: const Text('Ordem já possui plano executado'),
              content: const Text(
                  'Esta ordem de produção já possui um plano de corte executado.\n\nCancele a execução do plano existente antes de executar outro.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (_) {}

    // Confirmar ação
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Executar Plano de Corte?'),
        content: const Text(
            'Ao executar, o plano será marcado como concluído e as sobras de cada barra serão cadastradas automaticamente no módulo de Pontas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Executar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _executando = true);
    try {
      final r = _resultado!;
      final ordem = _ordemSelecionada!;
      final bitolaId = ordem.produto.id;
      final bitolaDescricao = '${ordem.produto.nome} - ${ordem.produto.descricao}';

      // 1) Atualizar status do plano para 'executado'
      await SupabaseService.client.from('planos_corte').update({
        'status': 'executado',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _planoId!);

      // 1.5) Baixar pontas consumidas do estoque
      for (final item in _materiaPrima) {
        if (!item.isPonta) continue;
        final ponta = item.pontaOrigem!;
        final qtdeUsada = int.tryParse(item.quantidadeCtrl.text.trim()) ?? 0;
        if (qtdeUsada <= 0) continue;

        if (qtdeUsada >= ponta.quantidade) {
          // Consumiu tudo → deleta a ponta do cadastro
          await SupabaseService.client
              .from('pontas')
              .delete()
              .eq('id', ponta.id);
        } else {
          // Consumiu parcialmente → decrementa a quantidade
          await SupabaseService.client.from('pontas').update({
            'quantidade': ponta.quantidade - qtdeUsada,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', ponta.id);
        }
      }

      // 2) Cadastrar sobras como pontas com rastreio de origem
      // Agrupar sobras iguais (mesmo comprimento) somando a quantidade
      final Map<double, int> sobrasAgrupadas = {};
      for (final barra in r.barrasUsadas) {
        if (barra.sobra > 0) {
          final chave = double.parse(barra.sobra.toStringAsFixed(2));
          sobrasAgrupadas[chave] = (sobrasAgrupadas[chave] ?? 0) + 1;
        }
      }

      final pontasParaInserir = <Map<String, dynamic>>[];
      final pedidosLocalizadores = ordem.pedidos.map((e) => e.localizador).join(', ');
      final localizadorPonta = pedidosLocalizadores.isNotEmpty ? pedidosLocalizadores : 'Plano ${ordem.localizator}';

      for (final entry in sobrasAgrupadas.entries) {
        pontasParaInserir.add({
          'bitola_id': bitolaId,
          'bitola_descricao': bitolaDescricao,
          'tamanho': entry.key,
          'quantidade': entry.value,
          'localizador': localizadorPonta,
          'plano_corte_id': _planoId,
          'ordem_id': ordem.id,
        });
      }

      if (pontasParaInserir.isNotEmpty) {
        await SupabaseService.client.from('pontas').insert(pontasParaInserir);
      }

      final totalPontas = sobrasAgrupadas.values.fold(0, (s, v) => s + v);
      if (mounted) {
        NotificationService.showPositive(
          'Plano Executado',
          '$totalPontas ponta${totalPontas != 1 ? 's' : ''} cadastrada${totalPontas != 1 ? 's' : ''} (${pontasParaInserir.length} tamanho${pontasParaInserir.length != 1 ? 's' : ''}).',
          position: NotificationPosition.bottom,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showNegative(
          'Erro ao executar',
          e.toString(),
          position: NotificationPosition.bottom,
        );
      }
    } finally {
      if (mounted) setState(() => _executando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCELAR EXECUÇÃO — volta para pendente e remove pontas geradas
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _cancelarExecucao() async {
    if (_planoId == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Execução?'),
        content: const Text(
            'Ao cancelar, o plano voltará ao status pendente e todas as pontas geradas por esta execução serão removidas do cadastro de Pontas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar Execução'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _executando = true);
    try {
      // 1) Remover pontas geradas por este plano
      await SupabaseService.client
          .from('pontas')
          .delete()
          .eq('plano_corte_id', _planoId!);

      // 1.5) Restaurar pontas consumidas durante a execução
      final planoData = await SupabaseService.client
          .from('planos_corte')
          .select('materia_prima_json')
          .eq('id', _planoId!)
          .single();
      final mpJson = planoData['materia_prima_json'] as List<dynamic>? ?? [];
      for (final mp in mpJson) {
        final pontaId = mp['ponta_id']?.toString();
        final qtdeOriginal = mp['ponta_quantidade_original'] as int?;
        final qtdeUsada = mp['quantidade'] as int?;
        if (pontaId == null || qtdeOriginal == null || qtdeUsada == null) continue;

        // Verificar se a ponta ainda existe (consumo parcial)
        final existente = await SupabaseService.client
            .from('pontas')
            .select('id, quantidade')
            .eq('id', pontaId);

        if (existente.isNotEmpty) {
          // Ponta existe → somar de volta a quantidade usada
          final qtdeAtual = existente.first['quantidade'] as int;
          await SupabaseService.client.from('pontas').update({
            'quantidade': qtdeAtual + qtdeUsada,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', pontaId);
        } else {
          // Ponta foi deletada (consumo total) → recriar
          final bitolaId = _ordemSelecionada?.produto.id ?? '';
          final bitolaDescricao = _ordemSelecionada != null
              ? '${_ordemSelecionada!.produto.nome} - ${_ordemSelecionada!.produto.descricao}'
              : '';
          await SupabaseService.client.from('pontas').insert({
            'id': pontaId,
            'bitola_id': bitolaId,
            'bitola_descricao': bitolaDescricao,
            'tamanho': mp['comprimento'] ?? 0,
            'quantidade': qtdeOriginal,
            'localizador': '',
          });
        }
      }

      // 2) Voltar status do plano para 'pendente'
      await SupabaseService.client.from('planos_corte').update({
        'status': 'pendente',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _planoId!);

      if (mounted) {
        NotificationService.showPositive(
          'Execução Cancelada',
          'Pontas geradas foram removidas do cadastro.',
          position: NotificationPosition.bottom,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showNegative(
          'Erro ao cancelar',
          e.toString(),
          position: NotificationPosition.bottom,
        );
      }
    } finally {
      if (mounted) setState(() => _executando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORTAR PDF
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _exportarPdf() async {
    if (_resultado == null || _ordemSelecionada == null) return;
    setState(() => _exportandoPdf = true);
    try {
      final r = _resultado!;
      final ordem = _ordemSelecionada!;
      final logoBytes = await LogoHelper.logoBytesForPdf();

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      header: (ctx) => _pdfHeader(logoBytes, ordem),
      footer: (ctx) => _pdfFooter(ctx),
      build: (ctx) {
        final widgets = <pw.Widget>[];

        // KPIs
        widgets.add(pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            border: pw.Border.all(color: PdfColors.blueGrey200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            _pdfKpi('Barras', '${r.totalBarrasUsadas}'),
            _pdfKpi('Aproveit.', '${r.percentualAproveitamento.toStringAsFixed(1)}%'),
            _pdfKpi('Sobra Total', r.totalSobra.toStringAsFixed(1)),
            if (r.temFalta) _pdfKpi('Faltaram', '${r.pecasNaoAlocadas.length} pç', cor: PdfColors.red700),
          ]),
        ));
        widgets.add(pw.SizedBox(height: 10));

        // Barras agrupadas por layout
        final layouts = _agruparLayouts(r.barrasUsadas);
        for (int i = 0; i < layouts.length; i++) {
          final layout = layouts[i];
          widgets.add(_pdfBarraBloco(layout.barra, i + 1, layout.quantidade));
          widgets.add(pw.SizedBox(height: 6));
        }

        // Peças não alocadas
        if (r.temFalta) {
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PEÇAS NÃO ALOCADAS (${r.pecasNaoAlocadas.length})',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                pw.SizedBox(height: 4),
                ...r.pecasNaoAlocadas.map((p) => pw.Text(
                      '${p.pedidoLocalizador} · ${p.elementoNome} · OS ${p.numeroOs} — ${p.comprCorte.toStringAsFixed(1)}',
                      style: const pw.TextStyle(fontSize: 7),
                    )),
              ],
            ),
          ));
        }

        return widgets;
      },
    ));

    final bytes = await pdf.save();
    final nome = 'plano_corte_${ordem.localizator.toLowerCase()}_${DateTime.now().toFileName()}.pdf';
    await downloadPDF(nome, '/relatorio/plano_corte/', bytes);
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  pw.Widget _pdfHeader(Uint8List logoBytes, OrdemModel ordem) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            pw.Image(pw.MemoryImage(logoBytes), width: 36, height: 36),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PLANO DE CORTE',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                pw.Text('${ordem.localizator} — ${ordem.produto.descricao}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ]),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento gerado eletronicamente',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfKpi(String label, String valor, {PdfColor cor = PdfColors.blueGrey800}) {
    return pw.Expanded(
      child: pw.Column(children: [
        pw.Text(valor, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: cor)),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ]),
    );
  }

  pw.Widget _pdfBarraBloco(BarraUsadaModel barra, int numero, int repeticoes) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(children: [
        // Header da barra
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: PdfColors.blueGrey800,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LAYOUT ${numero.toString().padLeft(2, '0')} — Compr. ${barra.comprimentoTotal.toStringAsFixed(1)} — Repetir $repeticoes vez${repeticoes > 1 ? 'es' : ''}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('Uso: ${barra.percentualUso.toStringAsFixed(1)}%  |  Sobra: ${barra.sobra.toStringAsFixed(1)}',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ],
          ),
        ),
        // Tabela de cortes zebrada
        pw.TableHelper.fromTextArray(
          headers: ['Localizador', 'Elemento', 'OS', 'Compr. Corte'],
          data: barra.cortes.map((c) => [
            c.peca.pedidoLocalizador,
            c.peca.elementoNome,
            c.peca.numeroOs,
            c.comprCorte.toStringAsFixed(1),
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerLeft,
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.2),
          },
        ),
      ]),
    );
  }
}

// ─── Classe auxiliar para o formulário ────────────────────────────────────────
class _MateriaPrimaItem {
  final TextEditingController comprimentoCtrl;
  final TextEditingController quantidadeCtrl;
  bool isIlimitado;
  PontaModel? pontaOrigem; // se veio do cadastro de pontas

  _MateriaPrimaItem()
      : comprimentoCtrl = TextEditingController(),
        quantidadeCtrl = TextEditingController(),
        isIlimitado = false,
        pontaOrigem = null;

  _MateriaPrimaItem.padrao()
      : comprimentoCtrl = TextEditingController(text: '1200'),
        quantidadeCtrl = TextEditingController(),
        isIlimitado = true,
        pontaOrigem = null;

  _MateriaPrimaItem.dePonta(PontaModel ponta)
      : comprimentoCtrl =
            TextEditingController(text: ponta.tamanho.toStringAsFixed(0)),
        quantidadeCtrl =
            TextEditingController(text: ponta.quantidade.toString()),
        isIlimitado = false,
        pontaOrigem = ponta;

  bool get isPonta => pontaOrigem != null;
}

// ─── Agrupamento de layouts idênticos ────────────────────────────────────────
class _LayoutAgrupado {
  final BarraUsadaModel barra;
  final String chave;
  int quantidade;

  _LayoutAgrupado({
    required this.barra,
    required this.chave,
    this.quantidade = 1,
  });
}

// ─── Dialog de seleção individual de pontas ──────────────────────────────────
class _DialogSelecionarPontas extends StatefulWidget {
  final List<PontaModel> pontas;
  const _DialogSelecionarPontas({required this.pontas});

  @override
  State<_DialogSelecionarPontas> createState() =>
      _DialogSelecionarPontasState();
}

class _DialogSelecionarPontasState extends State<_DialogSelecionarPontas> {
  final Set<String> _selecionados = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Pontas'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selecionar/desmarcar todas
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_selecionados.length == widget.pontas.length) {
                        _selecionados.clear();
                      } else {
                        _selecionados
                            .addAll(widget.pontas.map((p) => p.id));
                      }
                    });
                  },
                  icon: Icon(
                    _selecionados.length == widget.pontas.length
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                  ),
                  label: Text(
                      _selecionados.length == widget.pontas.length
                          ? 'Desmarcar todas'
                          : 'Selecionar todas',
                      style: const TextStyle(fontSize: 13)),
                ),
                const Spacer(),
                Text('${_selecionados.length} selecionada${_selecionados.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const Divider(),
            // Lista de pontas
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.pontas.length,
                itemBuilder: (ctx, i) {
                  final p = widget.pontas[i];
                  final selecionada = _selecionados.contains(p.id);
                  return CheckboxListTile(
                    dense: true,
                    value: selecionada,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selecionados.add(p.id);
                        } else {
                          _selecionados.remove(p.id);
                        }
                      });
                    },
                    title: Text(
                        '${p.tamanho.toStringAsFixed(0)} cm  ×  ${p.quantidade}',
                        style: const TextStyle(fontSize: 14)),
                    subtitle: p.localizador.isNotEmpty
                        ? Text(p.localizador,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]))
                        : null,
                    secondary: Icon(Icons.recycling,
                        size: 18, color: Colors.amber[700]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selecionados.isEmpty
              ? null
              : () {
                  final resultado = widget.pontas
                      .where((p) => _selecionados.contains(p.id))
                      .toList();
                  Navigator.of(context).pop(resultado);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('Importar Selecionadas'),
        ),
      ],
    );
  }
}
