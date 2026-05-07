import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRepository {
  static Future<bool> add(UsuarioModel usuario) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.setString('usuario', usuario.toJson());
    return true;
  }

  static Future<UsuarioModel?> get() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final usuario = sharedPrefs.getString('usuario');
    if (usuario == null) return null;
    final map = jsonDecode(usuario);
    return UsuarioModel.fromMap(map);
  }

  static Future<void> removeUser() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.remove('usuario');
  }

  static Future<void> clear() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    sharedPrefs.clear();
  }

  // ── Credenciais para "Manter conectado" ──

  static Future<void> saveCredentials(String email, String senha) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('saved_email', email);
    prefs.setString('saved_senha', senha);
  }

  static Future<({String email, String senha})?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final senha = prefs.getString('saved_senha');
    if (email == null || senha == null) return null;
    return (email: email, senha: senha);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('saved_email');
    prefs.remove('saved_senha');
  }
}
