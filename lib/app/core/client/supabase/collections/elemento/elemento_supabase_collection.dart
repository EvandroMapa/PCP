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

  bool _isListen = false;
  void listen() {
    if (_isListen) return;
    _isListen = true;
    
    // Listener simplificado: qualquer mudança na tabela elementos dispara um re-fetch
    // O Supabase streams envia row-level events, mas para garantir integridade das 
    // relações (posições/arquivos), re-buscamos o estado atualizado debounced.
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          _updateStreams();
        });
  }

  Timer? _streamDebounce;
  void _updateStreams() {
    _streamDebounce?.cancel();
    _streamDebounce = Timer(const Duration(milliseconds: 500), () {
      _isStarted = false;
      start();
    });
  }
}
