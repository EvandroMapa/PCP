import 'dart:developer';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._();
  RealtimeSyncService._();
  factory RealtimeSyncService() => _instance;

  RealtimeChannel? _channel;
  bool _isSubscribed = false;

  void init() {
    if (_isSubscribed) return;
    try {
      _channel = SupabaseService.client.channel('pcp_sync_channel');
      
      _channel!.onBroadcast(
        event: 'sync_event',
        callback: (payload) {
          log('Sync Event Received: ${payload['table']}');
          final table = payload['table']?.toString();
          if (table == 'pedidos' || table == 'ordens') {
            _onSyncReceived?.call(table!);
          }
        },
      ).subscribe((status, [error]) {
        _isSubscribed = status == 'SUBSCRIBED';
        log('Sync Channel Status: $status');
        if (error != null) log('Sync Channel Error: $error');
      });
    } catch (e) {
      log('Sync Channel Exception: $e');
    }
  }

  Function(String table)? _onSyncReceived;
  void listen(Function(String table) onSync) {
    _onSyncReceived = onSync;
  }

  Future<void> broadcast(String table) async {
    if (_channel == null || !_isSubscribed) {
      init();
    }
    try {
      await _channel?.sendBroadcast(
        event: 'sync_event',
        payload: {'table': table},
      );
      log('Sync Event Broadcasted: $table');
    } catch (e) {
      log('Sync Broadcast Error: $e');
    }
  }
}

final syncService = RealtimeSyncService();
