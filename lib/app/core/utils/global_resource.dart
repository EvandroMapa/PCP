import 'package:aco_plus/app/app_controller.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const String empty = '';

BuildContext get contextGlobal => AppController().context;

dynamic push([a, b]) async {
  Widget? widget;
  BuildContext? context;
  if (a != null) {
    if (a is Widget) {
      widget = a;
    } else if (a is BuildContext) {
      context = a;
    }
  }
  if (b != null) {
    if (b is Widget) {
      widget = b;
    } else if (b is BuildContext) {
      context = b;
    }
  }
  var result = await Navigator.push(
    context ?? contextGlobal,
    MaterialPageRoute(builder: (_) => widget ?? Container()),
  );
  return result;
}

void pop([BuildContext? context]) => Navigator.pop(context ?? contextGlobal);

pops(BuildContext context, int length) {
  for (var i = 0; i < length; i++) {
    Navigator.pop(context);
  }
}

void showDialogAndPush(context, Widget dialog, Widget page) async {
  await showDialog(context: context, builder: (_) => dialog);
  push(context, page);
}

bool kIsLayoutMobile = true;

Future<bool> onDeleteProcess({
  required String deleteTitle,
  required String deleteMessage,
  required String infoMessage,
  required bool conditional,
}) async {
  if (conditional) {
    await showInfoDialog(infoMessage);
    return false;
  } else {
    return await showConfirmDialog(deleteTitle, deleteMessage);
  }
}

void setWebTitle(String title) {
  SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(label: title),
  );
}

void openInNewTab(String path) {
  html.window.open(path, '_blank');
}
