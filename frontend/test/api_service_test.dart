import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nextstock/models/empresa.dart';
import 'package:nextstock/models/usuario.dart';
import 'package:nextstock/services/api_service.dart';
import 'package:nextstock/services/sessao.dart';

import 'apoio/api_falsa.dart';
import 'apoio/sessao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(prepararSessao);

  test('todo tipo de chamada leva o token de quem está logado', () async {
    Sessao.token = 'tok-123';
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson([]),
      '/importar/modelo': (_) => http.Response.bytes([0x50, 0x4B, 0x03, 0x04], 200),
      '/importar': (_) => respostaJson({'importados': 1, 'ignorados': 0, 'erros': []}),
      '/empresa': (_) => respostaJson({}),
      '/usuarios/5': (_) => respostaVazia(),
    });

    await api.usar(() async {
      await ApiService.listarProdutos(); // GET
      await ApiService.baixarModelo('produtos'); // download do xlsx
      await ApiService.importarPlanilha('produtos', 'p.csv', utf8.encode('nome,preco_venda\nX,1\n')); // upload
      await ApiService.atualizarEmpresa(Empresa(nome: 'Loja')); // PUT com JSON
      await ApiService.desativarUsuario(5); // DELETE
    });

    expect(api.requisicoes, hasLength(5));
    for (final r in api.requisicoes) {
      expect(r.headers['Authorization'], 'Bearer tok-123', reason: '${r.method} ${r.url.path}');
    }
  });

  test('sem login as chamadas vão sem token', () async {
    final api = ApiFalsa({'/setup/status': (_) => respostaJson({'configurado': true})});
    await api.usar(() => ApiService.setupConfigurado());
    expect(api.requisicoes.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 com alguém logado limpa a sessão e deixa o aviso pro login', () async {
    await Sessao.entrar('tok-123', Usuario(id: 1, nome: 'Ana', email: 'ana@loja.com'));
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson({'erro': 'sua sessão expirou, entre de novo'}, status: 401),
    });

    await expectLater(api.usar(() => ApiService.listarProdutos()), throwsException);
    await pumpEventQueue();

    expect(Sessao.token, isNull);
    expect(Sessao.usuario.value, isNull);
    expect(Sessao.aviso, 'Sua sessão expirou. Entre de novo.');
    expect(await tokenGuardado(), isNull);
  });

  test('login errado (ninguém logado) não vira aviso de sessão expirada', () async {
    final api = ApiFalsa({
      '/auth/login': (_) => respostaJson({'erro': 'e-mail ou senha inválidos'}, status: 401),
    });

    await expectLater(
      api.usar(() => ApiService.login('ana@loja.com', 'errada')),
      throwsA(predicate((e) => e.toString().contains('e-mail ou senha inválidos'))),
    );
    expect(Sessao.aviso, isNull);
  });
}
