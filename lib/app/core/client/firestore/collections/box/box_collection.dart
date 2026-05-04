import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoxCollection {
  static final BoxCollection _instance = BoxCollection._();
  BoxCollection._();
  BoxCollection.base();
  factory BoxCollection() => _instance;

  String name = 'boxes';
  String get tableName => name;

  AppStream<List<BoxModel>> dataStream = AppStream<List<BoxModel>>.seed([]);
  List<BoxModel> get data => dataStream.value;

  CollectionReference<Map<String, dynamic>> get collection =>
      FirebaseFirestore.instance.collection(name);

  bool _isStarted = false;

  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    final data = await FirebaseFirestore.instance.collection(name).get();
    final boxes = data.docs.map((e) => BoxModel.fromMap(e.data())).toList();
    boxes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    dataStream.add(boxes);
  }

  Future<void> listen() async {}

  BoxModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => BoxModel.empty());

  List<BoxModel> getByPatioId(String patioId) =>
      data.where((e) => e.patioId == patioId).toList();

  Future<BoxModel?> add(BoxModel model) async {
    await collection.doc(model.id).set(model.toMap());
    return model;
  }

  Future<BoxModel?> update(BoxModel model) async {
    await collection.doc(model.id).update(model.toMap());
    return model;
  }

  Future<void> delete(BoxModel model) async {
    await collection.doc(model.id).delete();
  }
}
