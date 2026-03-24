import 'dart:developer';
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
      // 1. Fetch main steps
      final stepsResponse = await SupabaseService.client
          .from(tableName)
          .select()
          .order('index', ascending: true);
      
      // 2. Fetch relationships
      final fromStepsResponse = await SupabaseService.client
          .from('step_from_steps')
          .select();
      
      final rolesResponse = await SupabaseService.client
          .from('step_roles')
          .select();

      final rows = List<Map<String, dynamic>>.from(stepsResponse);
      final fromStepsRows = List<Map<String, dynamic>>.from(fromStepsResponse);
      final rolesRows = List<Map<String, dynamic>>.from(rolesResponse);

      final steps = rows.map((row) {
        // Find links for this step
        final fromIds = fromStepsRows
            .where((r) => r['step_id'] == row['id'])
            .map((r) => r['from_step_id'].toString())
            .toList();
        
        final roles = rolesRows
            .where((r) => r['step_id'] == row['id'])
            .map((r) => r['role_index'] as int)
            .toList();

        // Inject into map for model factory
        row['de_etapas'] = fromIds;
        row['perfis_movimentacao'] = roles;

        return StepModel.fromSupabaseMap(row);
      }).toList();

      dataStream.add(steps);
      log('Supabase (Step.start): Found ${steps.length} steps.');
      NotificationService.showPositive('Carga Supabase', 'Etapas carregadas: ${steps.length}');
    } catch (e) {
      log('Supabase Error (Step.start): $e');
      NotificationService.showNegative('Erro ao Carregar Etapas', e.toString());
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

  @override
  Future<StepModel?> add(StepModel model) async {
    try {
      final map = model.toSupabaseMap();
      await SupabaseService.client.from(tableName).insert(map);
      await _syncRelationships(model);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Step.add): $e');
      return null;
    }
  }

  @override
  Future<StepModel?> update(StepModel model) async {
    try {
      final map = model.toSupabaseMap();
      await SupabaseService.client.from(tableName).update(map).eq('id', model.id);
      await _syncRelationships(model);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Step.update): $e');
      return null;
    }
  }

  Future<void> _syncRelationships(StepModel model) async {
    // 1. Delete old
    await SupabaseService.client.from('step_from_steps').delete().eq('step_id', model.id);
    await SupabaseService.client.from('step_roles').delete().eq('step_id', model.id);

    // 2. Insert new "from steps"
    if (model.fromStepsIds.isNotEmpty) {
      final fromMapped = model.fromStepsIds.map((fromId) => {
        'step_id': model.id,
        'from_step_id': fromId,
      }).toList();
      await SupabaseService.client.from('step_from_steps').insert(fromMapped);
    }

    // 3. Insert new roles
    if (model.moveRoles.isNotEmpty) {
      final rolesMapped = model.moveRoles.map((role) => {
        'step_id': model.id,
        'role_index': role.index,
      }).toList();
      await SupabaseService.client.from('step_roles').insert(rolesMapped);
    }
  }

  @override
  Future<void> delete(StepModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Step.delete): $e');
    }
  }
}
