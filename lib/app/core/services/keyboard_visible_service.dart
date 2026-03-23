import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class KeyboardVisibleService implements Service {
  static AppStream<bool> isVisible = AppStream<bool>();

  @override
  Future<void> initialize() async {
    isVisible.add(false);
    KeyboardVisibilityController().onChange.listen((e) async {
      if (e) {
        isVisible.add(true);
      } else {
        await Future.delayed(const Duration(seconds: 1));
        isVisible.add(false);
      }
    });
  }
}
