import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automacao_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class AutomacoesCollection {
  static final AutomacoesCollection _instance = AutomacoesCollection._();

  AutomacoesCollection._();

  factory AutomacoesCollection() => _instance;
  String name = 'automacoes';

  AppStream<List<AutomacaoModel>> dataStream =
      AppStream<List<AutomacaoModel>>.seed([]);
  List<AutomacaoModel> get data => dataStream.value;

  CollectionReference<Map<String, dynamic>> get collection =>
      FirebaseFirestore.instance.collection(name);

  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  bool _isStarted = false;
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    final data = await FirebaseFirestore.instance.collection(name).get();
    final automacoes = data.docs
        .map((e) => AutomacaoModel.fromMap(e.data()))
        .toList();
    automacoes.sort((a, b) => a.index.compareTo(b.index));
    dataStream.add(automacoes);
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    collection.snapshots().listen((e) {
      final automacoes = e.docs
          .map((e) => AutomacaoModel.fromMap(e.data()))
          .toList();
      automacoes.sort((a, b) => a.index.compareTo(b.index));
      dataStream.add(automacoes);
    });
  }

  AutomacaoModel getById(String id) {
    if (!dataStream.controller.hasValue) return AutomacaoModel.empty();
    final automacao = data.firstWhereOrNull((e) => e.id == id);
    return automacao ?? AutomacaoModel.empty();
  }

  Future<AutomacaoModel?> add(AutomacaoModel model) async {
    await collection.doc(model.id).set(model.toMap());
    return model;
  }

  Future<AutomacaoModel?> update(AutomacaoModel model) async {
    await collection.doc(model.id).update(model.toMap());
    return model;
  }

  Future<void> delete(String id) async {
    await collection.doc(id).delete();
  }
}
