import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

// quem esta logado. o token fica salvo no aparelho pra nao precisar entrar toda vez que abre o app.
class Sessao {
  static const chaveToken = 'token_login';

  static String? token;

  // a tela de entrada escuta isso: null = mostra o login
  static final ValueNotifier<Usuario?> usuario = ValueNotifier(null);

  // recado pra tela de login (ex.: sessao expirada)
  static String? aviso;

  // le o token salvo da ultima vez (ainda precisa conferir na API se ele vale)
  static Future<void> restaurarToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(chaveToken);
  }

  static Future<void> entrar(String novoToken, Usuario u) async {
    token = novoToken;
    aviso = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chaveToken, novoToken);
    usuario.value = u;
  }

  static Future<void> sair({String? motivo}) async {
    token = null;
    aviso = motivo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(chaveToken);
    usuario.value = null;
  }

  // a API respondeu 401 com alguem logado: o token venceu ou o usuario foi desativado
  static void expirou() {
    if (token == null) return;
    sair(motivo: 'Sua sessão expirou. Entre de novo.');
  }
}
