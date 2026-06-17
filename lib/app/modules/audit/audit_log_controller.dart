import 'dart:developer';

import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:flutter/material.dart';

final auditLogCtrl = AuditLogController();

class AuditLogController {
  static final AuditLogController _instance = AuditLogController._();
  AuditLogController._();
  factory AuditLogController() => _instance;

  final AppStream<List<AuditLogEntry>> logsStream =
      AppStream<List<AuditLogEntry>>.seed([]);
  List<AuditLogEntry> get logs => logsStream.value;

  final AppStream<bool> carregandoStream = AppStream<bool>.seed(false);

  // Filtros
  String? filtroUsuarioId;
  String? filtroAcao;
  String? filtroBusca;
  String? filtroDispositivo;
  DateTimeRange? filtroData;

  // Paginação
  int _offset = 0;
  static const _pageSize = 50;
  bool temMais = true;

  Future<void> onInit() async {
    resetFiltros();
    await buscar();
  }

  void resetFiltros() {
    filtroUsuarioId = null;
    filtroAcao = null;
    filtroBusca = null;
    filtroDispositivo = null;
    // Padrão: últimos 30 dias
    final hoje = DateTime.now();
    filtroData = DateTimeRange(
      start: hoje.subtract(const Duration(days: 30)),
      end: hoje,
    );
    _offset = 0;
    temMais = true;
    logsStream.add([]);
  }

  Future<void> buscar({bool maisResultados = false}) async {
    if (!maisResultados) {
      _offset = 0;
      temMais = true;
    }

    carregandoStream.add(true);

    try {
      var query = SupabaseService.client
          .from('audit_logs')
          .select();

      // Aplicar filtros ANTES de order/range
      if (filtroUsuarioId != null && filtroUsuarioId!.isNotEmpty) {
        query = query.eq('usuario_id', filtroUsuarioId!);
      }
      if (filtroAcao != null && filtroAcao!.isNotEmpty) {
        query = query.eq('acao', filtroAcao!);
      }
      if (filtroBusca != null && filtroBusca!.isNotEmpty) {
        query = query.or(
          'entidade_label.ilike.%$filtroBusca%,entidade_id.ilike.%$filtroBusca%',
        );
      }
      if (filtroDispositivo != null && filtroDispositivo!.isNotEmpty) {
        query = query.eq('dispositivo', filtroDispositivo!);
      }
      if (filtroData != null) {
        final inicio = filtroData!.start.copyWith(
            hour: 0, minute: 0, second: 0, millisecond: 0);
        final fim = filtroData!.end.copyWith(
            hour: 23, minute: 59, second: 59, millisecond: 999);
        query = query
            .gte('created_at', inicio.toIso8601String())
            .lte('created_at', fim.toIso8601String());
      }

      final List<dynamic> rows = await query
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);
      final novasEntradas = rows
          .cast<Map<String, dynamic>>()
          .map((r) => AuditLogEntry.fromMap(r))
          .toList();

      if (novasEntradas.length < _pageSize) {
        temMais = false;
      }

      if (maisResultados) {
        logsStream.add([...logs, ...novasEntradas]);
      } else {
        logsStream.add(novasEntradas);
      }

      _offset += novasEntradas.length;
    } catch (e) {
      log('AuditLogController.buscar erro: $e');
    }

    carregandoStream.add(false);
  }

  Future<void> carregarMais() async {
    if (!temMais) return;
    await buscar(maisResultados: true);
  }

  /// Retorna lista de dispositivos únicos para o filtro.
  Future<List<String>> obterDispositivos() async {
    try {
      final rows = await SupabaseService.client
          .from('audit_logs')
          .select('dispositivo')
          .not('dispositivo', 'is', null)
          .order('dispositivo');
      final Set<String> unicos = {};
      for (final r in rows) {
        final d = r['dispositivo']?.toString();
        if (d != null && d.isNotEmpty) unicos.add(d);
      }
      return unicos.toList();
    } catch (_) {
      return [];
    }
  }

  /// Retorna lista de usuários únicos para o filtro.
  Future<List<Map<String, String>>> obterUsuarios() async {
    try {
      final rows = await SupabaseService.client
          .from('audit_logs')
          .select('usuario_id, usuario_nome')
          .order('usuario_nome');
      final Map<String, String> unicos = {};
      for (final r in rows) {
        final id = r['usuario_id']?.toString() ?? '';
        final nome = r['usuario_nome']?.toString() ?? '';
        if (id.isNotEmpty) unicos[id] = nome;
      }
      return unicos.entries
          .map((e) => {'id': e.key, 'nome': e.value})
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ─── MODELO ──────────────────────────────────────────────────────────────────
class AuditLogEntry {
  final String id;
  final DateTime createdAt;
  final String usuarioId;
  final String usuarioNome;
  final String acao;
  final String modulo;
  final String? entidadeId;
  final String? entidadeLabel;
  final Map<String, dynamic> detalhes;
  final String? dispositivo;

  AuditLogEntry({
    required this.id,
    required this.createdAt,
    required this.usuarioId,
    required this.usuarioNome,
    required this.acao,
    required this.modulo,
    this.entidadeId,
    this.entidadeLabel,
    required this.detalhes,
    this.dispositivo,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> m) {
    return AuditLogEntry(
      id: m['id']?.toString() ?? '',
      createdAt: (DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now()).toLocal(),
      usuarioId: m['usuario_id']?.toString() ?? '',
      usuarioNome: m['usuario_nome']?.toString() ?? '',
      acao: m['acao']?.toString() ?? '',
      modulo: m['modulo']?.toString() ?? '',
      entidadeId: m['entidade_id']?.toString(),
      entidadeLabel: m['entidade_label']?.toString(),
      detalhes: (m['detalhes'] is Map)
          ? Map<String, dynamic>.from(m['detalhes'])
          : {},
      dispositivo: m['dispositivo']?.toString(),
    );
  }

  String get acaoFormatada => AuditService.acaoLabel(acao);
}
