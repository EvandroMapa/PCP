import 'dart:convert';
import 'dart:developer';

import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final backupExplorerCtrl = BackupExplorerController();

class BackupExplorerController {
  static final BackupExplorerController _instance =
      BackupExplorerController._();
  BackupExplorerController._();
  factory BackupExplorerController() => _instance;

  Map<String, dynamic> _rawData = {};

  final AppStream<List<BackupPedidoResumo>> pedidosStream =
      AppStream<List<BackupPedidoResumo>>.seed([]);
  List<BackupPedidoResumo> get pedidos => pedidosStream.value;

  final AppStream<String> buscaStream = AppStream<String>.seed('');

  // ─── CARREGAR JSON ──────────────────────────────────────────────────────
  void carregarJson(List<int> bytes) {
    try {
      _rawData = jsonDecode(utf8.decode(bytes));
      _extrairPedidos();
    } catch (e) {
      log('BackupExplorer: Erro ao decodificar JSON — $e');
      NotificationService.showNegative(
        'Erro ao ler backup',
        'O arquivo não é um JSON de backup válido.',
        position: NotificationPosition.bottom,
      );
    }
  }

  void _extrairPedidos() {
    final pedidosRaw =
        (_rawData['pedidos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final produtosRaw =
        (_rawData['pedido_bitolas'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final statusRaw = (_rawData['pedido_status_history'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final stepsRaw = (_rawData['pedido_steps_history'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final tagsRaw =
        (_rawData['pedido_tags'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final checksRaw =
        (_rawData['pedido_checks'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final commentsRaw =
        (_rawData['pedido_comments'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final elementosRaw =
        (_rawData['elementos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final posicoesRaw = (_rawData['elemento_posicoes'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    // Lookup de cliente por id
    final clientesRaw =
        (_rawData['clientes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final clientesMap = {for (var c in clientesRaw) c['id']: c['nome'] ?? ''};

    // Lookup de step por id
    final stepsDefRaw =
        (_rawData['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final stepsDefMap = {for (var s in stepsDefRaw) s['id']: s['nome'] ?? ''};

    // Lookup de tags por id
    final tagsDefRaw =
        (_rawData['tags'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final tagsDefMap = {for (var t in tagsDefRaw) t['id']: t['nome'] ?? ''};

    // Lookup de produtos (bitolas) por id
    final produtosDefRaw =
        (_rawData['produtos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final produtosDefMap = {
      for (var p in produtosDefRaw) p['id']: p['descricao'] ?? p['nome'] ?? ''
    };

    final List<BackupPedidoResumo> resultado = [];

    for (final p in pedidosRaw) {
      final id = p['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final produtos = produtosRaw.where((r) => r['pedido_id'] == id).toList();
      final status = statusRaw.where((r) => r['pedido_id'] == id).toList();
      final steps = stepsRaw.where((r) => r['pedido_id'] == id).toList();
      final tags = tagsRaw.where((r) => r['pedido_id'] == id).toList();
      final checks = checksRaw.where((r) => r['pedido_id'] == id).toList();
      final comments = commentsRaw.where((r) => r['pedido_id'] == id).toList();
      final elementos =
          elementosRaw.where((r) => r['pedido_id'] == id).toList();
      final elementoIds = elementos.map((e) => e['id']).toSet();
      final posicoes = posicoesRaw
          .where((r) => elementoIds.contains(r['elemento_id']))
          .toList();

      resultado.add(BackupPedidoResumo(
        id: id,
        localizador: p['localizador']?.toString() ?? '(sem localizador)',
        clienteNome: clientesMap[p['cliente_id']] ?? '(cliente não encontrado)',
        tipo: p['tipo']?.toString() ?? '',
        status: p['status']?.toString() ?? '',
        isArchived: p['is_archived'] == true,
        createdAt: p['created_at']?.toString() ?? '',
        pedidoRaw: p,
        produtosRaw: produtos,
        statusRaw: status,
        stepsRaw: steps,
        tagsRaw: tags,
        checksRaw: checks,
        commentsRaw: comments,
        elementosRaw: elementos,
        posicoesRaw: posicoes,
        stepsDefMap: stepsDefMap,
        tagsDefMap: tagsDefMap,
        produtosDefMap: produtosDefMap,
      ));
    }

    resultado.sort((a, b) => a.localizador.compareTo(b.localizador));
    pedidosStream.add(resultado);
  }

  // ─── FILTRAR ────────────────────────────────────────────────────────────
  List<BackupPedidoResumo> filtrar(String busca) {
    if (busca.length < 2) return pedidos;
    final termo = busca.toLowerCase();
    return pedidos.where((p) {
      return p.localizador.toLowerCase().contains(termo) ||
          p.clienteNome.toLowerCase().contains(termo) ||
          p.id.toLowerCase().contains(termo);
    }).toList();
  }

  // ─── RESTAURAR PEDIDO ──────────────────────────────────────────────────
  Future<void> restaurarPedido(
      BuildContext context, BackupPedidoResumo pedido) async {
    // Verificar se já existe no banco
    try {
      final existe = await SupabaseService.client
          .from('pedidos')
          .select('id')
          .eq('id', pedido.id)
          .maybeSingle();

      if (existe != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
            title: const Text('Pedido já existe'),
            content: Text(
              'O pedido "${pedido.localizador}" já existe no banco de dados.\n\n'
              'A restauração é permitida apenas para pedidos que foram excluídos.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      log('BackupExplorer: Erro ao verificar existência — $e');
    }

    // Confirmar restauração
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar Pedido?'),
        content: Text(
          'O pedido "${pedido.localizador}" será restaurado com:\n\n'
          '• ${pedido.produtosRaw.length} produto(s)\n'
          '• ${pedido.statusRaw.length} registro(s) de status\n'
          '• ${pedido.stepsRaw.length} registro(s) de etapa\n'
          '• ${pedido.tagsRaw.length} tag(s)\n'
          '• ${pedido.elementosRaw.length} elemento(s)\n'
          '• ${pedido.commentsRaw.length} comentário(s)\n\n'
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    showLoadingDialog();

    try {
      // 1. Inserir pedido
      await SupabaseService.client.from('pedidos').upsert(pedido.pedidoRaw);

      // 2. Inserir sub-tabelas
      if (pedido.produtosRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_bitolas')
            .upsert(pedido.produtosRaw);
      }
      if (pedido.statusRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_status_history')
            .upsert(pedido.statusRaw);
      }
      if (pedido.stepsRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_steps_history')
            .upsert(pedido.stepsRaw);
      }
      if (pedido.tagsRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_tags')
            .upsert(pedido.tagsRaw);
      }
      if (pedido.checksRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_checks')
            .upsert(pedido.checksRaw);
      }
      if (pedido.commentsRaw.isNotEmpty) {
        await SupabaseService.client
            .from('pedido_comments')
            .upsert(pedido.commentsRaw);
      }
      if (pedido.elementosRaw.isNotEmpty) {
        await SupabaseService.client
            .from('elementos')
            .upsert(pedido.elementosRaw);
      }
      if (pedido.posicoesRaw.isNotEmpty) {
        await SupabaseService.client
            .from('elemento_posicoes')
            .upsert(pedido.posicoesRaw);
      }

      if (contextGlobal.mounted) Navigator.pop(contextGlobal);

      NotificationService.showPositive(
        'Pedido Restaurado!',
        '"${pedido.localizador}" foi importado com sucesso.',
        position: NotificationPosition.bottom,
      );

      // Audit
      AuditService.registrar(
        acao: 'restaurar_pedido',
        modulo: 'backup',
        entidadeId: pedido.id,
        entidadeLabel: pedido.localizador,
        detalhes: {
          'produtos': pedido.produtosRaw.length,
          'elementos': pedido.elementosRaw.length,
        },
      );
    } catch (e) {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal);
      log('BackupExplorer: Erro ao restaurar — $e');
      NotificationService.showNegative(
        'Erro ao restaurar',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  // ─── DIAGNOSTICAR PEDIDO ───────────────────────────────────────────────
  Future<DiagnosticoResult> diagnosticarPedido(BackupPedidoResumo pedido) async {
    final tabelas = [
      'pedidos',
      'pedido_bitolas',
      'pedido_status_history',
      'pedido_steps_history',
      'pedido_tags',
      'pedido_checks',
      'pedido_comments',
      'elementos',
      'ordem_produtos',
    ];

    final Map<String, int> banco = {};
    final Map<String, int> backup = {};
    final Map<String, List<Map<String, dynamic>>> bancoDetalhes = {};

    for (final tabela in tabelas) {
      // Contagem no backup
      if (tabela == 'pedidos') {
        backup[tabela] = 1; // o próprio pedido
      } else if (tabela == 'ordem_produtos') {
        backup[tabela] = 0; // não está no backup do pedido
      } else if (tabela == 'pedido_bitolas') {
        backup[tabela] = pedido.produtosRaw.length;
      } else if (tabela == 'pedido_status_history') {
        backup[tabela] = pedido.statusRaw.length;
      } else if (tabela == 'pedido_steps_history') {
        backup[tabela] = pedido.stepsRaw.length;
      } else if (tabela == 'pedido_tags') {
        backup[tabela] = pedido.tagsRaw.length;
      } else if (tabela == 'pedido_checks') {
        backup[tabela] = pedido.checksRaw.length;
      } else if (tabela == 'pedido_comments') {
        backup[tabela] = pedido.commentsRaw.length;
      } else if (tabela == 'elementos') {
        backup[tabela] = pedido.elementosRaw.length;
      }

      // Contagem no banco
      try {
        List<dynamic> rows;
        if (tabela == 'pedidos') {
          rows = await SupabaseService.client
              .from(tabela)
              .select('id')
              .eq('id', pedido.id);
        } else if (tabela == 'ordem_produtos') {
          rows = await SupabaseService.client
              .from(tabela)
              .select('id, ordem_id')
              .eq('pedido_id', pedido.id);
        } else {
          rows = await SupabaseService.client
              .from(tabela)
              .select('id')
              .eq('pedido_id', pedido.id);
        }
        banco[tabela] = rows.length;
        if (rows.isNotEmpty) {
          bancoDetalhes[tabela] = rows.cast<Map<String, dynamic>>();
        }
      } catch (_) {
        banco[tabela] = -1; // erro ao consultar
      }
    }

    // Verificar elemento_posicoes (via elemento_id)
    int posicoesNoBanco = 0;
    try {
      final elementoIds = pedido.elementosRaw.map((e) => e['id']).toList();
      if (elementoIds.isNotEmpty) {
        final rows = await SupabaseService.client
            .from('elemento_posicoes')
            .select('id')
            .inFilter('elemento_id', elementoIds);
        posicoesNoBanco = rows.length;
      }
    } catch (_) {
      posicoesNoBanco = -1;
    }
    banco['elemento_posicoes'] = posicoesNoBanco;
    backup['elemento_posicoes'] = pedido.posicoesRaw.length;

    return DiagnosticoResult(
      banco: banco,
      backup: backup,
      bancoDetalhes: bancoDetalhes,
    );
  }
}

// ─── MODELO ──────────────────────────────────────────────────────────────────
class BackupPedidoResumo {
  final String id;
  final String localizador;
  final String clienteNome;
  final String tipo;
  final String status;
  final bool isArchived;
  final String createdAt;

  final Map<String, dynamic> pedidoRaw;
  final List<Map<String, dynamic>> produtosRaw;
  final List<Map<String, dynamic>> statusRaw;
  final List<Map<String, dynamic>> stepsRaw;
  final List<Map<String, dynamic>> tagsRaw;
  final List<Map<String, dynamic>> checksRaw;
  final List<Map<String, dynamic>> commentsRaw;
  final List<Map<String, dynamic>> elementosRaw;
  final List<Map<String, dynamic>> posicoesRaw;

  // Lookups para exibir nomes
  final Map<dynamic, dynamic> stepsDefMap;
  final Map<dynamic, dynamic> tagsDefMap;
  final Map<dynamic, dynamic> produtosDefMap;

  BackupPedidoResumo({
    required this.id,
    required this.localizador,
    required this.clienteNome,
    required this.tipo,
    required this.status,
    required this.isArchived,
    required this.createdAt,
    required this.pedidoRaw,
    required this.produtosRaw,
    required this.statusRaw,
    required this.stepsRaw,
    required this.tagsRaw,
    required this.checksRaw,
    required this.commentsRaw,
    required this.elementosRaw,
    required this.posicoesRaw,
    required this.stepsDefMap,
    required this.tagsDefMap,
    required this.produtosDefMap,
  });

  int get totalSubRegistros =>
      produtosRaw.length +
      statusRaw.length +
      stepsRaw.length +
      tagsRaw.length +
      elementosRaw.length +
      commentsRaw.length;
}

// ─── RESULTADO DO DIAGNÓSTICO ────────────────────────────────────────────────
class DiagnosticoResult {
  final Map<String, int> banco;
  final Map<String, int> backup;
  final Map<String, List<Map<String, dynamic>>> bancoDetalhes;

  DiagnosticoResult({
    required this.banco,
    required this.backup,
    required this.bancoDetalhes,
  });

  static const _labels = {
    'pedidos': 'Pedido',
    'pedido_bitolas': 'Bitolas',
    'pedido_status_history': 'Histórico Status',
    'pedido_steps_history': 'Histórico Etapas',
    'pedido_tags': 'Tags',
    'pedido_checks': 'Checklists',
    'pedido_comments': 'Comentários',
    'elementos': 'Elementos',
    'elemento_posicoes': 'Posições',
    'ordem_produtos': 'Ordens (referência)',
  };

  String label(String tabela) => _labels[tabela] ?? tabela;

  List<String> get tabelas =>
      {...banco.keys, ...backup.keys}.toList();

  bool get temOrfaos => banco.entries.any(
        (e) => e.value > 0 && e.key != 'pedidos',
      );
}
