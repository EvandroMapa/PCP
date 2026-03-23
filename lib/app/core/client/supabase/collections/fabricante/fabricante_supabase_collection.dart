import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FabricanteSupabaseCollection extends FabricanteCollection {
  static final FabricanteSupabaseCollection _instance = FabricanteSupabaseCollection._();
  FabricanteSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory FabricanteSupabaseCollection() => _instance;

  @override
  final String tableName = 'fabricantes';

  @override
  List<FabricanteModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select();
      final fabricantes = List<Map<String, dynamic>>.from(response)
          .map((e) => FabricanteModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(fabricantes);
    } catch (e) {
      print('Supabase Error (Fabricante.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<FabricanteModel?> add(FabricanteModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      return model;
    } catch (e) {
      print('Supabase Error (Fabricante.add): $e');
      return null;
    }
  }

  @override
  Future<FabricanteModel?> update(FabricanteModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      return model;
    } catch (e) {
      print('Supabase Error (Fabricante.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(FabricanteModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
    } catch (e) {
      print('Supabase Error (Fabricante.delete): $e');
    }
  }
}
