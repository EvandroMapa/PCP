import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';

final armacaoCtrl = ArmacaoController();

class ArmacaoSummary {
  final int totalElementos;
  final double pesoTotal;
  final Map<String, double> pesoPorBitola;

  ArmacaoSummary({
    required this.totalElementos,
    required this.pesoTotal,
    required this.pesoPorBitola,
  });

  factory ArmacaoSummary.empty() => ArmacaoSummary(
        totalElementos: 0,
        pesoTotal: 0,
        pesoPorBitola: {},
      );
}

class ArmacaoController {
  static final ArmacaoController _instance = ArmacaoController._();
  ArmacaoController._();
  factory ArmacaoController() => _instance;

  final TextController search = TextController();
  final AppStream<List<PedidoModel>> pedidosStream = AppStream.seed([]);
  
  // Cache para evitar recarregar elementos desnecessariamente
  final Map<String, ArmacaoSummary> _summaries = {};

  void onInit() {
    AppSupabaseClient.pedidos.stream.listen((pedidos) {
      _syncSummariesAndFilter(pedidos);
    });
  }

  Future<void> _syncSummariesAndFilter(List<PedidoModel> all) async {
    final filtered = all.where((p) {
      final isVisible = p.step.isExibirArmacao;
      final matchesSearch = p.localizador.toLowerCase().contains(search.text.toLowerCase()) ||
          p.cliente.nome.toLowerCase().contains(search.text.toLowerCase());
      return isVisible && matchesSearch;
    }).toList();

    // Buscar sumários para os pedidos filtrados que ainda não temos
    for (final p in filtered) {
      if (!_summaries.containsKey(p.id)) {
        _summaries[p.id] = await _fetchSummary(p.id);
      }
    }

    // Ordenar por data de entrega ou criação
    filtered.sort((a, b) => (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));
    
    pedidosStream.add(filtered);
  }

  Future<ArmacaoSummary> _fetchSummary(String pedidoId) async {
    try {
      // Buscar elementos e suas posições
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedidoId);

      double pesoTotal = 0;
      int totalElementos = 0;
      final Map<String, double> pesoPorBitola = {};

      for (final e in elementosRaw) {
        final qtde = int.tryParse(e['qtde'].toString()) ?? 1;
        totalElementos += qtde;

        final posicoesRaw = await SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .eq('elemento_id', e['id'].toString());

        for (final pos in posicoesRaw) {
          final pesoPos = double.tryParse(pos['peso_kg'].toString()) ?? 0.0;
          final pesoTotalPos = pesoPos * qtde;
          
          final prodId = pos['produto_id'].toString();
          pesoPorBitola[prodId] = (pesoPorBitola[prodId] ?? 0) + pesoTotalPos;
          pesoTotal += pesoTotalPos;
        }
      }

      return ArmacaoSummary(
        totalElementos: totalElementos,
        pesoTotal: pesoTotal,
        pesoPorBitola: pesoPorBitola,
      );
    } catch (e) {
      print('Erro ao buscar sumário de armação: $e');
      return ArmacaoSummary.empty();
    }
  }

  ArmacaoSummary getSummary(String pedidoId) => _summaries[pedidoId] ?? ArmacaoSummary.empty();

  Future<void> onFetchElementos(PedidoModel pedido) async {
    try {
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedido.id);

      final List<ElementoModel> result = [];
      for (final e in elementosRaw) {
        final posicoesRaw = await SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .eq('elemento_id', e['id'].toString());
            
        final arquivosRaw = await SupabaseService.client
            .from('elemento_arquivos')
            .select()
            .eq('elemento_id', e['id'].toString());

        result.add(ElementoModel.fromSupabaseMap(
          e,
          posicoesRaw: List<Map<String, dynamic>>.from(posicoesRaw),
          arquivosRaw: List<Map<String, dynamic>>.from(arquivosRaw),
        ));
      }
      
      pedido.elementos.clear();
      pedido.elementos.addAll(result);
    } catch (e) {
      print('ArmacaoController.onFetchElementos erro: $e');
    }
  }

  void onSearch(String val) {
    _syncSummariesAndFilter(AppSupabaseClient.pedidos.data);
  }
}
