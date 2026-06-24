import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EquipamentoCollection {
  static final EquipamentoCollection _instance = EquipamentoCollection._();

  EquipamentoCollection._();
  EquipamentoCollection.base();

  factory EquipamentoCollection() => _instance;
  String name = 'equipamentos';

  AppStream<List<EquipamentoModel>> dataStream =
      AppStream<List<EquipamentoModel>>.seed([]);
  List<EquipamentoModel> get data => dataStream.value;

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
    final items =
        data.docs.map((e) => EquipamentoModel.fromMap(e.data())).toList();
    dataStream.add(items);
  }

  bool _isListen = false;
  Future<void> listen({
    Object? field,
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) async {
    if (_isListen) return;
    _isListen = true;
    (field != null
            ? collection.where(
                field,
                isEqualTo: isEqualTo,
                isNotEqualTo: isNotEqualTo,
                isLessThan: isLessThan,
                isLessThanOrEqualTo: isLessThanOrEqualTo,
                isGreaterThan: isGreaterThan,
                isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
                arrayContains: arrayContains,
                arrayContainsAny: arrayContainsAny,
                whereIn: whereIn,
                whereNotIn: whereNotIn,
                isNull: isNull,
              )
            : collection)
        .snapshots()
        .listen((e) {
      final items =
          e.docs.map((e) => EquipamentoModel.fromMap(e.data())).toList();
      dataStream.add(items);
    });
  }

  EquipamentoModel getById(String id) => data.firstWhere(
        (e) => e.id == id,
        orElse: () => EquipamentoModel.empty(),
      );

  Future<EquipamentoModel?> add(EquipamentoModel model) async {
    await collection.doc(model.id).set(model.toMap());
    return model;
  }

  Future<EquipamentoModel?> update(EquipamentoModel model) async {
    await collection.doc(model.id).update(model.toMap());
    return model;
  }

  Future<void> delete(EquipamentoModel model) async {
    await collection.doc(model.id).delete();
  }
}
