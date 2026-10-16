import 'package:nextstock/models/usuario.dart';
import 'package:nextstock/services/sessao.dart';
import 'package:shared_preferences/shared_preferences.dart';

// cada teste comeca deslogado. tokenSalvo simula um login feito numa vez anterior
void prepararSessao({String? tokenSalvo}) {
  SharedPreferences.setMockInitialValues(tokenSalvo == null ? {} : {Sessao.chaveToken: tokenSalvo});
  Sessao.token = null;
  Sessao.usuario.value = null;
  Sessao.aviso = null;
}

// simula alguem ja logado (sem passar pela tela de login)
void logarComo({String perfil = 'admin', int id = 99, String nome = 'Quem Está Logado'}) {
  Sessao.token = 'tok-teste';
  Sessao.usuario.value = Usuario(id: id, nome: nome, email: 'logado@loja.com', perfil: perfil);
}

Future<String?> tokenGuardado() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(Sessao.chaveToken);
}
