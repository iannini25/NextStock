import 'package:nextstock/services/sessao.dart';
import 'package:shared_preferences/shared_preferences.dart';

// cada teste comeca deslogado. tokenSalvo simula um login feito numa vez anterior
void prepararSessao({String? tokenSalvo}) {
  SharedPreferences.setMockInitialValues(tokenSalvo == null ? {} : {Sessao.chaveToken: tokenSalvo});
  Sessao.token = null;
  Sessao.usuario.value = null;
  Sessao.aviso = null;
}

Future<String?> tokenGuardado() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(Sessao.chaveToken);
}
