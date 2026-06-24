import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:flutter/foundation.dart';

class ElementoSupabaseCollection {
  static final ElementoSupabaseCollection _instance =
      ElementoSupabaseCollection._();
  ElementoSupabaseCollection._() {
    dataStream = AppStream.seed(<ElementoModel>[]);
  }
  factory ElementoSupabaseCollection() => _instance;

  /// Flag global: bloqueia re-fetches automáticos durante importação SPE
  static bool isImportando = false;

  /// Callback chamado após atualização dos elementos via Realtime.
  /// Usado pelo PedidoSupabaseCollection para re-mapear pedidos
  /// com os elementos atualizados e evitar a race condition.
  VoidCallback? onUpdated;

  final String name = 'elementos';
  late final AppStream<List<ElementoModel>> dataStream;
  List<ElementoModel> get data => dataStream.value;

  bool _isStarted = false;

  Future<void> fetch() async {
    _isStarted = false;
    await start();
    _isStarted = true;
  }

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    try {
      // 1. Buscar tabela principal
      final elementosRaw =
          await SupabaseService.client.from(name).select().order('nome');

      if (elementosRaw.isEmpty) {
        dataStream.add(<ElementoModel>[]);
        return;
      }

      final List<String> eIds =
          elementosRaw.map((e) => e['id'].toString()).toList();

      // 2. Buscar tabelas auxiliares em lotes PARALELOS (evita URL too long)
      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          const batchSize = 50;
          const parallelLimit = 10; // Executa 10 batches em paralelo
          final resultados = <Map<String, dynamic>>[];

          // Monta todos os batches de IDs
          final batches = <List<String>>[];
          for (int i = 0; i < eIds.length; i += batchSize) {
            batches.add(eIds.sublist(
                i, i + batchSize > eIds.length ? eIds.length : i + batchSize));
          }

          // Executa em blocos de parallelLimit
          for (int i = 0; i < batches.length; i += parallelLimit) {
            final chunk = batches.sublist(
                i, i + parallelLimit > batches.length ? batches.length : i + parallelLimit);
            final futures = chunk.map((batch) => SupabaseService.client
                .from(table)
                .select()
                .filter('elemento_id', 'in', batch));
            final results = await Future.wait(futures);
            for (final res in results) {
              resultados.addAll(List<Map<String, dynamic>>.from(res));
            }
          }
          return resultados;
        } catch (_) {
          return [];
        }
      }

      final results = await Future.wait([
        safeFetch('elemento_posicoes'),
        safeFetch('elemento_arquivos'),
      ]);

      final allPosicoes = results[0];
      final allArquivos = results[1];

      // 3. Montar modelos
      final elementos = elementosRaw.map((eMap) {
        final eId = eMap['id'].toString();
        return ElementoModel.fromSupabaseMap(
          eMap,
          posicoesRaw: allPosicoes
              .where((p) => p['elemento_id'].toString() == eId)
              .toList(),
          arquivosRaw: allArquivos
              .where((a) => a['elemento_id'].toString() == eId)
              .toList(),
        );
      }).toList();

      dataStream.add(elementos);
    } catch (e) {
      log('Supabase Error (Elemento.start): $e');
    }
  }

  /// Atualiza os dados locais de forma reativa a partir de mudanças em outros módulos (Ex: PC -> Tablet)
  void updateLocalData(List<ElementoModel> newData) {
    if (newData.isEmpty) return;

    final currentData = data.toList();
    for (final newItem in newData) {
      final idx = currentData.indexWhere((e) => e.id == newItem.id);
      if (idx != -1) {
        currentData[idx] = newItem;
      } else {
        currentData.add(newItem);
      }
    }

    data.clear();
    data.addAll(currentData);
    dataStream.add(data);
  }

  bool _isListen = false;
  void listen() {
    if (_isListen) return;
    _isListen = true;

    // Listener simplificado: qualquer mudança na tabela elementos dispara um re-fetch
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id']).listen((_) => _updateStreams());
  }

  Timer? _streamDebounce;
  void _updateStreams() {
    _streamDebounce?.cancel();
    // Debounce alto (1.5s): esta operação faz ~8 rodadas de queries paralelas
    // para 11k+ posições. Não faz sentido executar a cada mudança individual.
    _streamDebounce = Timer(const Duration(milliseconds: 1500), () async {
      if (isImportando) {
        log('Supabase Realtime: Elementos ignorado (importação em andamento).');
        return;
      }
      _isStarted = false;
      await start();
      log('Supabase Realtime: Elementos e Arquivos reatualizados.');
      // Notifica o PedidoSupabaseCollection para re-mapear pedidos
      // com os elementos recém-atualizados (corrige race condition).
      onUpdated?.call();
    });
  }
}
