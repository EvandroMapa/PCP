import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/services/supabase_service.dart';

/// Serviço de keep-alive para o Supabase.
///
/// **Problema:** O WebSocket do Supabase Realtime pode ser encerrado por:
///   - Inatividade prolongada (browser suspende conexões WebSocket)
///   - Timeout de rede / proxy / firewall
///   - Aba minimizada ou foco perdido por muitos minutos
///
/// **Solução:** Ping periódico ao banco para manter a sessão HTTP viva.
/// Se o ping falhar, re-subscribe em todos os canais para reconectar.
///
/// Uso: chamar `SupabaseKeepAliveService.instance.start()` após
/// `AppSupabaseClient.init()` no fluxo de inicialização.
class SupabaseKeepAliveService {
  SupabaseKeepAliveService._();
  static final SupabaseKeepAliveService instance = SupabaseKeepAliveService._();

  /// Intervalo de ping ao banco — suficientemente curto para evitar timeout.
  static const Duration _pingInterval = Duration(seconds: 25);

  /// Número de pings com falha consecutivos antes de re-subscribir os canais.
  static const int _maxFalhasConsecutivas = 2;

  Timer? _pingTimer;
  int _falhasConsecutivas = 0;
  bool _isRunning = false;

  /// Inicia o serviço de keep-alive.
  /// Idempotente: chamar múltiplas vezes não cria múltiplos timers.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _falhasConsecutivas = 0;

    log('SupabaseKeepAliveService: iniciado '
        '(ping a cada ${_pingInterval.inSeconds}s)');

    _pingTimer = Timer.periodic(_pingInterval, (_) => _ping());
  }

  /// Para o serviço (útil para testes ou logout).
  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _isRunning = false;
    log('SupabaseKeepAliveService: parado');
  }

  /// Executa uma query mínima para manter o socket e a sessão ativos.
  /// Em caso de falha consecutiva, força re-subscribe de todos os canais.
  Future<void> _ping() async {
    try {
      await SupabaseService.client
          .from('pedidos')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (_falhasConsecutivas > 0) {
        log('SupabaseKeepAliveService: conexão restaurada após '
            '$_falhasConsecutivas falha(s)');
      } else {
        log('SupabaseKeepAliveService: ping OK ✓');
      }
      _falhasConsecutivas = 0;
    } catch (e) {
      _falhasConsecutivas++;
      log('SupabaseKeepAliveService: ping falhou '
          '($_falhasConsecutivas/$_maxFalhasConsecutivas) → $e');

      if (_falhasConsecutivas >= _maxFalhasConsecutivas) {
        log('SupabaseKeepAliveService: reconectando canais Realtime...');
        _reconectarCanais();
        _falhasConsecutivas = 0;
      }
    }
  }

  /// Re-subscribe em todos os canais Realtime registrados.
  /// O SDK do supabase_flutter trata o [subscribe()] de forma idempotente:
  /// se o canal já está ativo, a chamada é ignorada silenciosamente.
  void _reconectarCanais() {
    try {
      final channels = SupabaseService.client.getChannels();

      if (channels.isEmpty) {
        log('SupabaseKeepAliveService: nenhum canal para reconectar');
        return;
      }

      for (final channel in channels) {
        channel.subscribe();
      }

      log('SupabaseKeepAliveService: ${channels.length} canais '
          're-subscribed com sucesso');
    } catch (e) {
      log('SupabaseKeepAliveService: erro ao reconectar canais → $e');
    }
  }
}
