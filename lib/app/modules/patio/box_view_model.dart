import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:flutter/material.dart';

class BoxCreateModel {
  final String id;
  TextController nome = TextController();
  Color cor;
  late bool isEdit;

  BoxCreateModel({this.cor = const Color(0xFF3B82F6)})
      : id = HashService.get,
        isEdit = false;

  BoxCreateModel.edit(BoxModel box)
      : id = box.id,
        cor = box.color,
        isEdit = true {
    nome.text = box.nome;
  }
}

// Paleta de cores para boxes
const List<Color> boxPaleta = [
  Color(0xFF3B82F6), // azul
  Color(0xFF10B981), // verde
  Color(0xFFF59E0B), // âmbar
  Color(0xFFEF4444), // vermelho
  Color(0xFF8B5CF6), // roxo
  Color(0xFFF97316), // laranja
  Color(0xFFEC4899), // rosa
  Color(0xFF06B6D4), // ciano
];
