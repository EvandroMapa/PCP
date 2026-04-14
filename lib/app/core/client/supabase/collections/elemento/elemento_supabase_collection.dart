import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';

class ElementoSupabaseCollection {
  static final ElementoSupabaseCollection _instance = ElementoSupabaseCollection._();
  ElementoSupabaseCollection._() {
    dataStream = AppStream.seed(<ElementoModel>[]);
  }
  factory ElementoSupabaseCollection() => _instance;

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
      final elementosRaw = await SupabaseService.client
          .from(name)
          .select()
          .order('nome');

      if (elementosRaw.isEmpty) {
        dataStream.add(<ElementoModel>[]);
        return;
      }

      final List<String> eIds = elementosRaw.map((e) => e['id'].toString()).toList();

      // 2. Buscar tabelas auxiliares em paralelo para todos os elementos
      Future<List<Map<String, dynamic>>> safeFetch(String table) async {
        try {
          final res = await SupabaseService.client
              .from(table)
              .select()
              .filter('elemento_id', 'in', eIds);
          return List<Map<String, dynamic>>.from(res);
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
          posicoesRaw: allPosicoes.where((p) => p['elemento_id'].toString() == eId).toList(),
          arquivosRaw: allArquivos.where((a) => a['elemento_id'].toString() == eId).toList(),
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
        .stream(primaryKey: ['id'])
        .listen((_) => _updateStreams());

    // NOVO: Escuta mudanças na tabela de posições para atualizar pesos/OS
    SupabaseService.client
        .from('elemento_posicoes')
        .stream(primaryKey: ['id'])
        .listen((_) => _updateStreams());

    // NOVO: Escuta mudanças na tabela de arquivos para atualizar os desenhos em tempo real
    SupabaseService.client
        .from('elemento_arquivos')
        .stream(primaryKey: ['id'])
        .listen((_) => _updateStreams());
  }

  Timer? _streamDebounce;
  void _updateStreams() {
    _streamDebounce?.cancel();
    _streamDebounce = Timer(const Duration(milliseconds: 500), () {
      _isStarted = false; // Forçar que o start() ignore o cache anterior
      start();
      log('Supabase Realtime: Elementos e Arquivos reatualizados.');
    });
  }
}
