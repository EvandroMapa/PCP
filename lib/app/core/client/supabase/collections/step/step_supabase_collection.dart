import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:aco_plus/app/core/client/firestore/collections/step/step_collection.dart';

class StepSupabaseCollection extends StepCollection {
  static final StepSupabaseCollection _instance = StepSupabaseCollection._();
  StepSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory StepSupabaseCollection() => _instance;

  @override
  final String tableName = 'steps';

  @override
  List<StepModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .order('index', ascending: true);
      final steps = List<Map<String, dynamic>>.from(response)
          .map((e) => StepModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(steps);
    } catch (e) {
      print('Supabase Error (Step.start): $e');
    }
  }

  bool _isListen = false;
  @override
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
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((_) => start(lock: false));
  }

  StepModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => StepModel.notFound);
}
