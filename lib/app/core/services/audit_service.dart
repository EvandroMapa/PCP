import 'dart:developer';
import 'dart:html' as html;

import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';

/// Service centralizado de log de auditoria (fire-and-forget).
///
/// Registra ações críticas na tabela `audit_logs` do Supabase
/// sem bloquear o fluxo principal do app.
class AuditService {
  AuditService._();

  /// Registra uma ação no log de auditoria.
  ///
  /// [acao] — identificador da ação (ex: 'excluir_pedido', 'login')
  /// [modulo] — módulo do sistema (ex: 'pedido', 'ordem', 'sessao')
  /// [entidadeId] — ID da entidade afetada (opcional)
  /// [entidadeLabel] — nome legível da entidade (opcional)
  /// [detalhes] — dados extras em JSON (opcional)
  static Future<void> registrar({
    required String acao,
    required String modulo,
    String? entidadeId,
    String? entidadeLabel,
    Map<String, dynamic>? detalhes,
  }) async {
    try {
      final user = usuarioCtrl.usuario;
      final dispositivo = _obterDispositivo();

      await SupabaseService.client.from('audit_logs').insert({
        'usuario_id': user?.id ?? 'desconhecido',
        'usuario_nome': user?.nome ?? 'desconhecido',
        'acao': acao,
        'modulo': modulo,
        'entidade_id': entidadeId,
        'entidade_label': entidadeLabel,
        'detalhes': detalhes ?? {},
        'dispositivo': dispositivo,
      });
    } catch (e) {
      // Fire-and-forget: nunca bloqueia o fluxo principal
      log('AuditService erro: $e');
    }
  }

  /// Registra login com dados do usuário que acabou de autenticar.
  /// Chamado antes do `usuarioCtrl.usuario` estar setado.
  static Future<void> registrarLogin({
    required String usuarioId,
    required String usuarioNome,
  }) async {
    try {
      final dispositivo = _obterDispositivo();

      await SupabaseService.client.from('audit_logs').insert({
        'usuario_id': usuarioId,
        'usuario_nome': usuarioNome,
        'acao': 'login',
        'modulo': 'sessao',
        'detalhes': {},
        'dispositivo': dispositivo,
      });
    } catch (e) {
      log('AuditService erro (login): $e');
    }
  }

  /// Simplifica o user-agent para um nome legível.
  static String _obterDispositivo() {
    try {
      final ua = html.window.navigator.userAgent;
      // Extrair navegador e SO de forma legível
      String navegador = 'Desconhecido';
      String so = 'Desconhecido';

      if (ua.contains('Edg/')) {
        navegador = 'Edge';
      } else if (ua.contains('Chrome/')) {
        navegador = 'Chrome';
      } else if (ua.contains('Firefox/')) {
        navegador = 'Firefox';
      } else if (ua.contains('Safari/')) {
        navegador = 'Safari';
      }

      if (ua.contains('Windows')) {
        so = 'Windows';
      } else if (ua.contains('Macintosh')) {
        so = 'macOS';
      } else if (ua.contains('Linux')) {
        so = 'Linux';
      } else if (ua.contains('Android')) {
        so = 'Android';
      } else if (ua.contains('iPhone') || ua.contains('iPad')) {
        so = 'iOS';
      }

      return '$navegador / $so';
    } catch (_) {
      return 'Desconhecido';
    }
  }

  /// Labels legíveis para os tipos de ação.
  static const acaoLabels = {
    'login': 'Login',
    'logout': 'Logout',
    'excluir_pedido': 'Excluir Pedido',
    'arquivar_pedido': 'Arquivar Pedido',
    'desarquivar_pedido': 'Desarquivar Pedido',
    'criar_pedido': 'Criar Pedido',
    'editar_pedido': 'Editar Pedido',
    'mover_etapa': 'Mover Etapa',
    'excluir_ordem': 'Excluir Ordem',
    'arquivar_ordem': 'Arquivar Ordem',
    'desarquivar_ordem': 'Desarquivar Ordem',
    'congelar_ordem': 'Congelar Ordem',
    'descongelar_ordem': 'Descongelar Ordem',
    'criar_ordem': 'Criar Ordem',
    'editar_ordem': 'Editar Ordem',
    'alterar_status_bitola': 'Alterar Status Bitola',
    'excluir_cliente': 'Excluir Cliente',
    'excluir_bitola': 'Excluir Bitola',
    'excluir_etapa': 'Excluir Etapa',
    'excluir_obra': 'Excluir Obra',
    'excluir_perfil': 'Excluir Perfil',
    'restaurar_pedido': 'Restaurar Pedido (Backup)',
    'restaurar_backup_completo': 'Restaurar Backup Completo',
    'ajuste_estoque': 'Ajuste de Estoque',
  };

  static String acaoLabel(String acao) => acaoLabels[acao] ?? acao;
}
