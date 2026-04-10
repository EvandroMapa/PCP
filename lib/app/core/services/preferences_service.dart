import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
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

    // Recupera limite de produção
    final savedMax = instance.getInt('maxElementosProducao');
    if (savedMax != null) {
      maxElementosProducao.add(savedMax);
    }

    // Listeners para salvamento automático
    kanbanColumnWidth.listen.listen((value) {
      instance.setDouble('kanbanColumnWidth', value);
    });

    maxElementosProducao.listen.listen((value) {
      instance.setInt('maxElementosProducao', value);
    });
  }
}
