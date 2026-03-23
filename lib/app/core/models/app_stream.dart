import 'package:rxdart/rxdart.dart';

class AppStream<T> {
  late final T t;
  AppStream() {
    controller = BehaviorSubject<T>();
  }

  AppStream.seed(this.t) {
    controller = BehaviorSubject<T>.seeded(t);
  }

  late final BehaviorSubject<T> controller;
  void add(e) => controller.sink.add(e);
  Stream<T> get listen => controller.stream;
  T get value => controller.stream.value;
  T? get valueOrNull => controller.stream.valueOrNull;
  bool get hasValue => controller.stream.hasValue;
  void update() => controller.sink.add(controller.value);
}
