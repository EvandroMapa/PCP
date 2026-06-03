import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase isolado para acessar o banco do SPE.
/// Totalmente separado do Supabase principal (PCP).
/// Para remover o módulo SPE, basta deletar este arquivo e suas referências.
class SpeSupabaseClient {
  static SpeSupabaseClient? _instance;

  /// URL e anon key do projeto SPE no Supabase
  static const String _url = 'https://kyatsdowjljkhivvdvzo.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5YXRzZG93amxqa2hpdnZkdnpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzIyODcsImV4cCI6MjA5MjU0ODI4N30.l21LY_n5zwn-vt8mi0KpxCXN7PYplR7pI-G589InwY0';

  late final SupabaseClient _client;

  SpeSupabaseClient._() {
    _client = SupabaseClient(_url, _anonKey);
  }

  factory SpeSupabaseClient() {
    _instance ??= SpeSupabaseClient._();
    return _instance!;
  }

  SupabaseClient get client => _client;

  // ── Pedidos Técnicos ──────────────────────────────────────────────────────

  /// Busca todos os pedidos técnicos abertos do SPE, com seus elementos.
  Future<List<Map<String, dynamic>>> buscarPedidosTecnicosAbertos() async {
    try {
      final response = await _client
          .from('pedidos_tecnicos')
          .select()
          .eq('status', 'aberto')
          .order('codigo', ascending: false);

      final pedidos = List<Map<String, dynamic>>.from(response);
      final result = <Map<String, dynamic>>[];

      for (final p in pedidos) {
        final pedidoId = p['id'] as String;
        final elementosRaw = List<Map<String, dynamic>>.from(
          await _client
              .from('pedido_tecnico_elementos')
              .select()
              .eq('pedido_id', pedidoId),
        );

        result.add({
          ...p,
          'elementos': elementosRaw,
        });
      }

      return result;
    } catch (e) {
      log('SpeSupabaseClient.buscarPedidosTecnicosAbertos erro: $e');
      return [];
    }
  }

  // ── Posições do Detalhamento ──────────────────────────────────────────────

  /// Busca posições do detalhamento do SPE para uma lista de IDs de elementos.
  /// Essas posições contêm as bitolas e dados de corte necessários.
  Future<List<Map<String, dynamic>>> buscarPosicoesPorElementoIds(
      List<String> elementoIds) async {
    if (elementoIds.isEmpty) return [];
    try {
      final result = <Map<String, dynamic>>[];

      // Busca em lotes para evitar URL muito longa
      const batchSize = 50;
      for (var i = 0; i < elementoIds.length; i += batchSize) {
        final end = (i + batchSize < elementoIds.length)
            ? i + batchSize
            : elementoIds.length;
        final batch = elementoIds.sublist(i, end);

        final response = List<Map<String, dynamic>>.from(
          await _client
              .from('posicoes')
              .select()
              .inFilter('elemento_id', batch),
        );
        result.addAll(response);
      }

      return result;
    } catch (e) {
      log('SpeSupabaseClient.buscarPosicoesPorElementoIds erro: $e');
      return [];
    }
  }

  /// Busca os elementos de um detalhamento específico no SPE.
  Future<List<Map<String, dynamic>>> buscarElementosDoDetalhamento(
      String detalhamentoId) async {
    try {
      final response = List<Map<String, dynamic>>.from(
        await _client
            .from('elementos')
            .select()
            .eq('detalhamento_id', detalhamentoId),
      );
      return response;
    } catch (e) {
      log('SpeSupabaseClient.buscarElementosDoDetalhamento erro: $e');
      return [];
    }
  }

  // ── Bitolas ───────────────────────────────────────────────────────────────

  /// Busca todas as bitolas cadastradas no SPE.
  Future<List<Map<String, dynamic>>> buscarBitolas() async {
    try {
      final response = List<Map<String, dynamic>>.from(
        await _client.from('bitolas').select(),
      );
      return response;
    } catch (e) {
      log('SpeSupabaseClient.buscarBitolas erro: $e');
      return [];
    }
  }
}
