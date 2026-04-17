import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService implements Service {
  static late SharedPreferences instance;

  // AppStream permite que a UI seja reativa a qualquer mudança de largura instantaneamente
  static final AppStream<double> kanbanColumnWidth =
      AppStream<double>.seed(300.0);
  static final AppStream<int> maxElementosProducao = AppStream<int>.seed(10);
  static final AppStream<int> pdfOptimizationLevel = AppStream<int>.seed(5);
  static final AppStream<String> apontamentoProducaoCD =
      AppStream<String>.seed('por_pedido');
  static final AppStream<String> logoUrl = AppStream<String>.seed('');
  static final AppStream<List<String>> stepsAcompanhamento =
      AppStream<List<String>>.seed([]);
  static final AppStream<String> whatsappSuporte = AppStream<String>.seed('');

  @override
  Future<void> initialize() async {
    instance = await SharedPreferences.getInstance();

    // Recupera largura do Kanban
    final savedWidth = instance.getDouble('kanbanColumnWidth');
    if (savedWidth != null) {
      kanbanColumnWidth.add(savedWidth);
    }

    // Recupera limite de produção (Agora Global no Supabase)
    try {
      final configRaw = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'max_elementos_producao')
          .maybeSingle();

      if (configRaw != null) {
        final val = int.tryParse(configRaw['value'].toString());
        if (val != null) {
          maxElementosProducao.add(val);
        }
      }

      // Recupera nível de otimização de PDF
      final pdfConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'pdf_optimization_level')
          .maybeSingle();
      if (pdfConfig != null) {
        final val = int.tryParse(pdfConfig['value'].toString());
        if (val != null) {
          pdfOptimizationLevel.add(val.clamp(0, 10));
        }
      }
    } catch (e) {
      log('Erro ao carregar limite global: $e');
      // Fallback para local se DB falhar no init
      final savedMax = instance.getInt('maxElementosProducao');
      if (savedMax != null) {
        maxElementosProducao.add(savedMax);
      }
    }

    // Recupera modo de apontamento de produção CD
    try {
      final apontConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'apontamento_producao_cd')
          .maybeSingle();
      if (apontConfig != null) {
        final val = apontConfig['value'].toString();
        if (val == 'por_pedido' || val == 'por_os') {
          apontamentoProducaoCD.add(val);
        }
      }
    } catch (e) {
      log('Erro ao carregar apontamento CD: $e');
    }

    // Listeners para salvamento automático
    kanbanColumnWidth.listen.listen((value) {
      instance.setDouble('kanbanColumnWidth', value);
    });

    maxElementosProducao.listen.listen((value) async {
      instance.setInt('maxElementosProducao', value);
      try {
        await SupabaseService.client.from('configs').upsert(
            {'key': 'max_elementos_producao', 'value': value},
            onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar limite global: $e');
      }
    });

    pdfOptimizationLevel.listen.skip(1).listen((value) async {
      try {
        await SupabaseService.client.from('configs').upsert(
            {'key': 'pdf_optimization_level', 'value': value},
            onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar nível de otimização PDF: $e');
      }
    });

    apontamentoProducaoCD.listen.skip(1).listen((value) async {
      try {
        await SupabaseService.client.from('configs').upsert(
            {'key': 'apontamento_producao_cd', 'value': value},
            onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar apontamento CD: $e');
      }
    });

    // Recupera logo customizada
    try {
      final logoConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'logo_url')
          .maybeSingle();
      if (logoConfig != null) {
        final val = logoConfig['value']?.toString() ?? '';
        if (val.isNotEmpty) {
          logoUrl.add(val);
        }
      }
    } catch (e) {
      log('Erro ao carregar logo customizada: $e');
    }

    logoUrl.listen.skip(1).listen((value) async {
      try {
        await SupabaseService.client
            .from('configs')
            .upsert({'key': 'logo_url', 'value': value}, onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar logo URL: $e');
      }
    });

    // Recupera etapas de acompanhamento e WhatsApp suporte
    try {
      final stepsConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'steps_acompanhamento')
          .maybeSingle();
      if (stepsConfig != null) {
        final List<dynamic> val = json.decode(stepsConfig['value'].toString());
        stepsAcompanhamento.add(val.cast<String>());
      }

      final waConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'whatsapp_suporte')
          .maybeSingle();
      if (waConfig != null) {
        whatsappSuporte.add(waConfig['value'].toString());
      }
    } catch (e) {
      log('Erro ao carregar configs de acompanhamento: $e');
    }

    stepsAcompanhamento.listen.skip(1).listen((value) async {
      try {
        await SupabaseService.client.from('configs').upsert(
            {'key': 'steps_acompanhamento', 'value': json.encode(value)},
            onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar etapas acompanhamento: $e');
      }
    });

    whatsappSuporte.listen.skip(1).listen((value) async {
      try {
        await SupabaseService.client.from('configs').upsert(
            {'key': 'whatsapp_suporte', 'value': value},
            onConflict: 'key');
      } catch (e) {
        log('Erro ao salvar WhatsApp suporte: $e');
      }
    });
  }

  /// Escala fixa em 2.5x para manter nitidez em todos os níveis.
  static double get pdfScale => 2.5;

  /// Converte o nível (0-10) em qualidade JPEG.
  /// 0 = máxima qualidade (95%), 10 = mínima qualidade (55%)
  static int get pdfQuality {
    return (95 - (pdfOptimizationLevel.value / 10.0) * 40).round();
  }

  /// Re-lê a configuração de apontamento de produção CD do Supabase.
  /// Deve ser chamado ao abrir uma ordem para garantir valor atualizado.
  static Future<void> refreshApontamentoCD() async {
    try {
      final apontConfig = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'apontamento_producao_cd')
          .maybeSingle();
      if (apontConfig != null) {
        final val = apontConfig['value'].toString();
        if (val == 'por_pedido' || val == 'por_os') {
          apontamentoProducaoCD.add(val);
        }
      }
    } catch (e) {
      log('Erro ao atualizar apontamento CD: $e');
    }
  }
}
