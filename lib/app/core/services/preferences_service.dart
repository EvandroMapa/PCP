import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService implements Service {
  static late SharedPreferences instance;
  
  // AppStream permite que a UI seja reativa a qualquer mudança de largura instantaneamente
  static final AppStream<double> kanbanColumnWidth = AppStream<double>.seed(300.0);
  static final AppStream<int> maxElementosProducao = AppStream<int>.seed(10);

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
    } catch (e) {
      print('Erro ao carregar limite global: $e');
      // Fallback para local se DB falhar no init
      final savedMax = instance.getInt('maxElementosProducao');
      if (savedMax != null) {
        maxElementosProducao.add(savedMax);
      }
    }

    // Listeners para salvamento automático
    kanbanColumnWidth.listen.listen((value) {
      instance.setDouble('kanbanColumnWidth', value);
    });

    maxElementosProducao.listen.listen((value) async {
      instance.setInt('maxElementosProducao', value);
      try {
        await SupabaseService.client
            .from('configs')
            .upsert({'key': 'max_elementos_producao', 'value': value}, onConflict: 'key');
      } catch (e) {
        print('Erro ao salvar limite global: $e');
      }
    });
  }
}
