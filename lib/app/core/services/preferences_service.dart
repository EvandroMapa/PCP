import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService implements Service {
  static late SharedPreferences instance;
  
  // AppStream permite que a UI seja reativa a qualquer mudança de largura instantaneamente
  static final AppStream<double> kanbanColumnWidth = AppStream<double>.seed(300.0);

  @override
  Future<void> initialize() async {
    instance = await SharedPreferences.getInstance();
    
    // Recupera o valor salvo ou inicia com 300.0 (padrão antigo)
    final savedWidth = instance.getDouble('kanbanColumnWidth');
    if (savedWidth != null) {
      kanbanColumnWidth.add(savedWidth);
    }

    // Escuta mudanças no stream e salva no dispositivo automaticamente
    kanbanColumnWidth.listen.listen((value) {
      instance.setDouble('kanbanColumnWidth', value);
    });
  }
}
