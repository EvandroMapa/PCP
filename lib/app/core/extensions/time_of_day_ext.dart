import 'package:aco_plus/app/core/extensions/int_ext.dart';
import 'package:flutter/material.dart';

extension TimeOfDayExt on TimeOfDay {
  String get time => '${hour.toTime()}:${minute.toTime()}';
}
