import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfDivisor {
  static pw.Widget build({Color? color, double height = 0.5}) {
    return pw.Container(
      width: double.maxFinite,
      height: height,
      color: PdfColor.fromInt((color ?? AppColors.neutralLight).value),
    );
  }
}
