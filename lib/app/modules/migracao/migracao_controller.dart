import 'dart:convert';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';

/// Projeto Firebase legado — acesso via REST API (sem SDK, sem WebSocket)
const _kProjectId = 'aco-plus-fa455';
const _kApiKey = 'AIzaSyArDF3DcSwhocSFg0R_9U2y2YTS7NTzCXA';

class MigracaoController {
  static final MigracaoController _instance = MigracaoController._();
  MigracaoController._();
  factory MigracaoController() => _instance;

  final AppStream<bool> isLoading = AppStream<bool>.seed(false);
  final AppStream<double> progress = AppStream<double>.seed(0);
  final AppStream<String> statusText = AppStream<String>.seed('');
  final AppStream<bool> importacaoConcluida = AppStream<bool>.seed(false);

  final AppStream<List<PedidoModel>> pedidosLegados =
      AppStream<List<PedidoModel>>.seed([]);
  final AppStream<List<PedidoModel>> pedidosSelecionados =
      AppStream<List<PedidoModel>>.seed([]);
  final AppStream<String> logMatchIds = AppStream<String>.seed('');
  final AppStream<List<StepModel>> etapasLegadas =
      AppStream<List<StepModel>>.seed([]);

  StepModel? etapaOrigemSelecionada;
  StepModel? etapaDestinoSelecionada;

  void init() {
    pedidosLegados.add(<PedidoModel>[]);
    pedidosSelecionados.add(<PedidoModel>[]);
    logMatchIds.add('');
    progress.add(0);
    statusText.add('');
    importacaoConcluida.add(false);
  }

  // ─── Busca etapas via REST ────────────────────────────────────────────────

  Future<void> buscarEtapasLegadas() async {
    try {
      isLoading.add(true);
      statusText.add('Conectando ao Firebase via REST API...');

      final docs = await _fetchCollection('steps');

      final steps = docs.map((doc) {
        final fields = doc['fields'] as Map<String, dynamic>? ?? {};
        final data = _fieldsToMap(fields);
        data['id'] = _docId(doc);
        return StepModel.fromMap(data);
      }).toList();

      steps.sort((a, b) => a.index.compareTo(b.index));
      etapasLegadas.add(steps);
      statusText.add('${steps.length} etapas carregadas.');
    } catch (e) {
      statusText.add('Erro ao buscar etapas: $e');
      debugPrint('[Migracao] Erro buscarEtapasLegadas: $e');
    } finally {
      isLoading.add(false);
    }
  }

  // ─── Busca pedidos por etapa via RunQuery (server-side filter) ─────────────

  Future<void> buscarPedidosLegados(StepModel etapaOrigem) async {
    try {
      isLoading.add(true);
      pedidosLegados.add(<PedidoModel>[]);
      pedidosSelecionados.add(<PedidoModel>[]);
      statusText.add('Buscando pedidos da etapa ${etapaOrigem.name}...');

      // RunQuery filtra server-side — evita baixar 3000 docs de uma vez
      final docs = await _runQueryByStep(etapaOrigem.id);

      debugPrint('[Migracao] docs retornados da etapa: ${docs.length}');

      final encontrados = <PedidoModel>[];
      int i = 0;
      for (final doc in docs) {
        try {
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final data = _fieldsToMap(fields);
          data['id'] = _docId(doc);
          encontrados.add(PedidoModel.fromMap(data));
        } catch (e) {
          debugPrint('[Migracao] Erro parse doc: $e');
        }
        // Yield a cada 20 docs para não travar o event loop / Supabase heartbeat
        i++;
        if (i % 20 == 0) await Future.delayed(Duration.zero);
      }

      encontrados.sort((a, b) => a.localizador.compareTo(b.localizador));
      pedidosLegados.add(encontrados);
      statusText.add('${encontrados.length} pedidos encontrados.');
      _verificarIntegridade(encontrados);
    } catch (e) {
      toast('Erro ao buscar pedidos: $e');
      debugPrint('[Migracao] Erro buscarPedidosLegados: $e');
    } finally {
      isLoading.add(false);
    }
  }

  // ─── Compatibilidade ──────────────────────────────────────────────────────

  void togglePedido(PedidoModel pedido) {}
  void toggleTodos() {}

  // ─── Integridade e duplicatas ─────────────────────────────────────────────

  void _verificarIntegridade(List<PedidoModel> legados) {
    int produtosSemId = 0;
    int clientesSemId = 0;
    for (var pedido in legados) {
      final clienteNoSupabase =
          BackendClient.clientes.getById(pedido.cliente.id);
      if (clienteNoSupabase.id.isEmpty) clientesSemId++;
      for (var p in pedido.produtos) {
        final prodSupabase = BackendClient.produtos.getById(p.produto.id);
        if (prodSupabase.id == 'NOTFOUND' || prodSupabase.id.isEmpty) {
          produtosSemId++;
        }
      }
    }
    if (produtosSemId == 0 && clientesSemId == 0) {
      logMatchIds.add(
          '✅ As chaves de Produtos e Clientes são IDÊNTICAS entre Firebase e Supabase.');
    } else {
      logMatchIds.add(
          '⚠️ AVISO: $clientesSemId clientes e $produtosSemId produtos não encontrados no Supabase pelos IDs.');
    }
  }

  String _normalizarLocalizador(String loc) =>
      loc.toLowerCase().replaceAll(RegExp(r'[\s.\-_]+'), '');

  PedidoModel? _buscarDuplicata(String localizador) {
    final normalizado = _normalizarLocalizador(localizador);
    try {
      return BackendClient.pedidos.data.firstWhere(
          (p) => _normalizarLocalizador(p.localizador) == normalizado);
    } catch (_) {
      return null;
    }
  }

  // ─── Importação individual ────────────────────────────────────────────────

  Future<void> importarPedidoUnico(
      PedidoModel pedido, StepModel etapaDestino, BuildContext context) async {
    final duplicata = _buscarDuplicata(pedido.localizador);
    if (duplicata != null) {
      final importarMesmoAssim = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('⚠️ Localizador já existe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'O pedido "${pedido.localizador}" parece já estar no PCP:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '"${duplicata.localizador}" — ${duplicata.cliente.nome}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Deseja importar mesmo assim?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Importar mesmo assim'),
                ),
              ],
            ),
          ) ??
          false;

      if (!importarMesmoAssim) return;
    }

    try {
      isLoading.add(true);
      statusText.add('Importando ${pedido.localizador}...');

      pedido.isImportado = true;
      pedido.steps.add(PedidoStepModel.create(etapaDestino));

      // Remove arquivos legados (links Firebase Storage inválidos no novo sistema)
      pedido.archives.clear();

      await BackendClient.pedidos.add(pedido);

      // Pequena pausa para não sobrecarregar o Supabase com múltiplos imports seguidos
      await Future.delayed(const Duration(milliseconds: 800));

      pedidosLegados.value.remove(pedido);
      pedidosLegados.update();

      final msg = '✅ "${pedido.localizador}" importado com sucesso!';
      toast(msg);
      statusText.add(msg);

      if (pedidosLegados.value.isEmpty) {
        importacaoConcluida.add(true);
      }
    } catch (e) {
      toast('Erro ao importar pedido: $e');
      debugPrint('[Migracao] Erro importarPedidoUnico: $e');
    } finally {
      isLoading.add(false);
    }
  }

  // mantido para compatibilidade
  Future<void> importarPedidosSelecionados(
      StepModel etapaDestino, BuildContext context) async {
    toast('Use o botão de importar individual em cada pedido.');
  }

  // ─── REST API helpers ─────────────────────────────────────────────────────

  /// Filtra pedidos server-side via Firestore RunQuery (Structured Query API).
  /// Busca apenas pedidos não-arquivados e filtra pelo último stepId client-side.
  Future<List<Map<String, dynamic>>> _runQueryByStep(String etapaId) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_kProjectId/databases/(default)/documents:runQuery?key=$_kApiKey',
    );

    final body = jsonEncode({
      'structuredQuery': {
        'from': [
          {'collectionId': 'pedidos'}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'isArchived'},
            'op': 'EQUAL',
            'value': {'booleanValue': false},
          }
        },
        'limit': 2000,
      }
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'RunQuery error ${response.statusCode}: ${response.body}');
    }

    final List<dynamic> results = jsonDecode(response.body);

    final docs = <Map<String, dynamic>>[];
    int i = 0;
    for (final result in results) {
      final doc = result['document'];
      if (doc == null) continue;
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};
      final stepsRaw = _convertValue(fields['steps']);
      if (stepsRaw is List && stepsRaw.isNotEmpty) {
        final ultimoStep = stepsRaw.last;
        if (ultimoStep is Map) {
          final stepId = ultimoStep['step']?.toString() ?? '';
          if (stepId == etapaId) {
            docs.add(doc as Map<String, dynamic>);
          }
        }
      }
      // Yield a cada 50 docs durante a filtragem
      i++;
      if (i % 50 == 0) await Future.delayed(Duration.zero);
    }
    return docs;
  }

  /// Busca todos os docs de uma collection via REST paginada (para etapas/steps).
  Future<List<Map<String, dynamic>>> _fetchCollection(String collection,
      {int pageSize = 300}) async {
    final List<Map<String, dynamic>> allDocs = [];
    String? nextPageToken;

    do {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_kProjectId/databases/(default)/documents/$collection?key=$_kApiKey&pageSize=$pageSize${nextPageToken != null ? '&pageToken=$nextPageToken' : ''}',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Firestore REST error ${response.statusCode}: ${response.body}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final documents = body['documents'] as List<dynamic>? ?? [];
      allDocs.addAll(documents.cast<Map<String, dynamic>>());
      nextPageToken = body['nextPageToken'] as String?;
    } while (nextPageToken != null);

    return allDocs;
  }

  // ─── Conversão de formato Firestore REST ──────────────────────────────────

  /// Extrai o ID do documento a partir do campo `name`.
  String _docId(Map<String, dynamic> doc) {
    final name = doc['name'] as String? ?? '';
    return name.split('/').last;
  }

  /// Converte typed fields do Firestore REST para Map simples.
  Map<String, dynamic> _fieldsToMap(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      result[entry.key] = _convertValue(entry.value);
    }
    return result;
  }

  dynamic _convertValue(dynamic value) {
    if (value is! Map) return value;
    final map = value as Map<String, dynamic>;
    if (map.containsKey('stringValue')) return map['stringValue'];
    if (map.containsKey('integerValue')) {
      return int.tryParse(map['integerValue'].toString()) ?? 0;
    }
    if (map.containsKey('doubleValue')) {
      return (map['doubleValue'] as num).toDouble();
    }
    if (map.containsKey('booleanValue')) return map['booleanValue'] as bool;
    if (map.containsKey('timestampValue')) {
      return DateTime.tryParse(map['timestampValue'].toString())
              ?.millisecondsSinceEpoch ??
          0;
    }
    if (map.containsKey('nullValue')) return null;
    if (map.containsKey('arrayValue')) {
      final values = (map['arrayValue']['values'] as List<dynamic>? ?? []);
      return values.map((v) => _convertValue(v)).toList();
    }
    if (map.containsKey('mapValue')) {
      final innerFields =
          map['mapValue']['fields'] as Map<String, dynamic>? ?? {};
      return _fieldsToMap(innerFields);
    }
    return null;
  }
}
