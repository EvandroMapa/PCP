import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class ElementoSupabaseCollection {
  static final ElementoSupabaseCollection _instance =
      ElementoSupabaseCollection._();
  ElementoSupabaseCollection._() {
    dataStream = AppStream.seed(<ElementoModel>[]);
  }
  factory ElementoSupabaseCollection() => _instance;

  /// Flag global: bloqueia re-fetches automáticos durante importação SPE
  static bool isImportando = false;

  /// Flag global: bloqueia mutações diretas do Realtime no cache enquanto
  /// um dialog de OS está ativamente trocando status de posição.
  /// Sem esse guard, o _handlePosicaoRealtime contamina o cache com o
  /// estado ANTERIOR (ainda não confirmado) mesmo com o lock do dialog ativo,
  /// causando os cards voltarem para aguardando sozinhos.
  static bool isStatusChanging = false;

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
      // 1. Elementos e posições em PARALELO, cada um numa única consulta.
      // Como todos os elementos são carregados, não é preciso filtrar as
      // posições por elemento_id — antes eram ~140 requisições "in" em lotes
      // de 50 (≈8 s na abertura); agora são 2 (≈3,5 s). Posições órfãs são
      // simplesmente ignoradas pelo índice abaixo.
      final resultados = await Future.wait([
        SupabaseService.client.from(name).select().order('nome'),
        SupabaseService.client.from('elemento_posicoes').select(),
      ]);
      final elementosRaw = resultados[0];
      final allPosicoes = resultados[1];

      if (elementosRaw.isEmpty) {
        dataStream.add(<ElementoModel>[]);
        return;
      }

      // 3. Indexar posições por elemento_id — evita O(n×m)
      final posicoesIndex = <String, List<Map<String, dynamic>>>{};
      for (final p in allPosicoes) {
        final eId = p['elemento_id'].toString();
        (posicoesIndex[eId] ??= []).add(p);
      }

      // Preserva arquivos existentes no cache local caso já tenham sido carregados
      final existingArquivosMap = <String, List<ElementoArquivoModel>>{};
      for (final existing in data) {
        if (existing.arquivos.isNotEmpty) {
          existingArquivosMap[existing.id] = existing.arquivos;
        }
      }

      // 4. Montar modelos com lookup O(1)
      final elementos = elementosRaw.map((eMap) {
        final eId = eMap['id'].toString();
        final elem = ElementoModel.fromSupabaseMap(
          eMap,
          posicoesRaw: posicoesIndex[eId] ?? [],
          arquivosRaw: null,
        );
        if (existingArquivosMap.containsKey(eId)) {
          elem.arquivos
            ..clear()
            ..addAll(existingArquivosMap[eId]!);
        }
        return elem;
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

  /// Busca elementos de um pedido específico do Supabase e atualiza o cache local.
  /// Usado como fallback quando o cache local não tem os elementos carregados.
  Future<void> fetchByPedidoId(String pedidoId) async {
    try {
      final elementosRaw = await SupabaseService.client
          .from(name)
          .select()
          .eq('pedido_id', pedidoId)
          .order('nome');

      if (elementosRaw.isEmpty) return;

      final eIds = elementosRaw.map((e) => e['id'].toString()).toList();

      // Busca posições e arquivos desses elementos
      final results = await Future.wait([
        SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .filter('elemento_id', 'in', eIds),
        SupabaseService.client
            .from('elemento_arquivos')
            .select()
            .filter('elemento_id', 'in', eIds),
      ]);

      final posicoesIndex = <String, List<Map<String, dynamic>>>{};
      for (final p in List<Map<String, dynamic>>.from(results[0])) {
        final eId = p['elemento_id'].toString();
        (posicoesIndex[eId] ??= []).add(p);
      }
      final arquivosIndex = <String, List<Map<String, dynamic>>>{};
      for (final a in List<Map<String, dynamic>>.from(results[1])) {
        final eId = a['elemento_id'].toString();
        (arquivosIndex[eId] ??= []).add(a);
      }

      final novosElementos = elementosRaw.map((eMap) {
        final eId = eMap['id'].toString();
        return ElementoModel.fromSupabaseMap(
          eMap,
          posicoesRaw: posicoesIndex[eId] ?? [],
          arquivosRaw: arquivosIndex[eId] ?? [],
        );
      }).toList();

      // Merge no cache local
      updateLocalData(novosElementos);
    } catch (e) {
      log('Supabase Error (Elemento.fetchByPedidoId): $e');
    }
  }

  bool _isListen = false;
  void listen() {
    if (_isListen) return;
    _isListen = true;

    // Listener: qualquer mudança na tabela elementos via channel cirúrgico.
    // Substituído de .stream() (que baixava TODA a tabela a cada mudança)
    // para channel listener (recebe só o registro alterado — muito mais rápido).
    SupabaseService.client
        .channel('elementos_realtime')
        .onPostgresChanges(
          event: sf.PostgresChangeEvent.all,
          schema: 'public',
          table: 'elementos',
          callback: _handleElementoRealtime,
        )
        .subscribe();

    // Listener: mudanças na tabela elemento_posicoes (ex: operador muda status no tablet)
    // Usa channel em vez de .stream() porque a tabela tem 11k+ linhas —
    // o .stream() faria download de TODA a tabela no subscribe, o channel
    // só recebe o evento de mudança (leve e rápido).
    SupabaseService.client
        .channel('elemento_posicoes_realtime')
        .onPostgresChanges(
          event: sf.PostgresChangeEvent.all,
          schema: 'public',
          table: 'elemento_posicoes',
          callback: _handlePosicaoRealtime,
        )
        .subscribe();
  }

  /// Atualiza cirurgicamente o elemento alterado no cache local (UPDATE de status).
  /// Evita o re-fetch completo de todos os elementos e garante propagação
  /// rápida entre dispositivos (~300ms vs ~3-4s do .stream() anterior).
  void _handleElementoRealtime(sf.PostgresChangePayload payload) {
    // Bloqueia mutação do cache enquanto este dispositivo está trocando status.
    // (No dispositivo REMOTO, isStatusChanging=false → processa normalmente)
    if (isStatusChanging) {
      log('Supabase Realtime: elemento ignorado (isStatusChanging=true)');
      return;
    }

    if (payload.eventType == sf.PostgresChangeEvent.update) {
      final newRecord = payload.newRecord;
      final elementoId = newRecord['id']?.toString();
      if (elementoId == null) {
        _updateStreams();
        return;
      }

      final idx = data.indexWhere((e) => e.id == elementoId);
      if (idx == -1) {
        // Elemento não encontrado no cache: fallback para re-fetch
        _updateStreams();
        return;
      }

      // Campos que mudam em operações de armação e OS
      final statusStr = newRecord['status']?.toString();
      final qtdePronto = int.tryParse(newRecord['qtde_pronto']?.toString() ?? '') ?? data[idx].qtdePronto;
      final qtdeArmando = int.tryParse(newRecord['qtde_armando']?.toString() ?? '') ?? data[idx].qtdeArmando;

      final newStatus = statusStr != null
          ? ElementoStatus.values
              .cast<ElementoStatus?>()
              .firstWhere((e) => e!.name == statusStr, orElse: () => null)
          : null;

      data[idx] = data[idx].copyWith(
        status: newStatus ?? data[idx].status,
        qtdePronto: qtdePronto,
        qtdeArmando: qtdeArmando,
      );

      dataStream.add(data);
      onUpdated?.call();
      log('Supabase Realtime: elemento $elementoId → ${newStatus?.name ?? statusStr} (cache cirúrgico)');
      return;
    }

    // INSERT ou DELETE: re-fetch completo (menos frequente, mais complexo)
    _updateStreams();
  }

  /// Atualiza apenas a posição alterada no cache local (UPDATE de status).
  /// Evita o re-fetch completo de 11k+ posições e garante propagação
  /// instantânea entre dispositivos via Supabase Realtime.
  void _handlePosicaoRealtime(sf.PostgresChangePayload payload) {
    // Se um dialog de OS está ativamente trocando status, bloqueia qualquer
    // mutação do cache para evitar que o estado intermediário/anterior do
    // Realtime sobrescreva a UI otimista. O dialog faz sua própria atualização
    // de cache via _updateGlobalElementosCache e re-sincroniza no unlock.
    if (isStatusChanging) {
      log('Supabase Realtime: posição ignorada (isStatusChanging=true)');
      return;
    }
    if (payload.eventType == sf.PostgresChangeEvent.update) {
      final newRecord = payload.newRecord;
      final posicaoId = newRecord['id']?.toString();
      final statusStr = newRecord['status']?.toString();

      if (posicaoId != null && statusStr != null) {
        bool updated = false;
        for (final elemento in data) {
          for (final posicao in elemento.posicoes) {
            if (posicao.id == posicaoId) {
              final newStatus = PosicaoStatus.values
                  .cast<PosicaoStatus?>()
                  .firstWhere(
                    (e) => e!.name == statusStr,
                    orElse: () => null,
                  );
              if (newStatus != null && newStatus != posicao.status) {
                posicao.status = newStatus;
                updated = true;
              }
              break;
            }
          }
          if (updated) break;
        }

        if (updated) {
          // Emite stream atualizado sem re-fetch — propagação instantânea
          dataStream.add(data);
          onUpdated?.call();
          log('Supabase Realtime: posição $posicaoId → $statusStr (cache cirúrgico)');
          return;
        }
      }
    }
    // Fallback: INSERT, DELETE ou posição não encontrada no cache
    _updateStreams();
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
      // Bloqueia re-fetch completo durante troca de status (armação ou OS).
      // Sem esse guard, o fetch terminava APÓS o lock local expirar e
      // sobrescrevia o elementosStream com o estado anterior do banco.
      if (isStatusChanging) {
        log('Supabase Realtime: re-fetch ignorado (isStatusChanging=true).');
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
