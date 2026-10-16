import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nextstock/screens/login_screen.dart';
import 'package:nextstock/screens/produto_form.dart';
import 'package:nextstock/screens/setup_screen.dart';
import 'package:nextstock/services/sessao.dart';
import 'package:nextstock/shell/app_shell.dart';
import 'package:nextstock/shell/entrada.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

final ana = usuarioJson(id: 1, nome: 'Ana Admin', email: 'ana@loja.com', perfil: 'admin');

// token que a API falsa aceita. trocar no meio do teste simula a sessao vencendo no servidor
var tokenAceito = 'tok-valido';

http.Response protegida(http.Request req, Object corpo) => req.headers['Authorization'] == 'Bearer $tokenAceito'
    ? respostaJson(corpo)
    : respostaJson({'erro': 'sua sessão expirou, entre de novo'}, status: 401);

// API falsa: so a senha 'senha1234' da Ana entra, e so o token aceito abre as rotas
ApiFalsa montarApi({bool configurado = true}) {
  return ApiFalsa({
    '/setup/status': (_) => respostaJson({'configurado': configurado}),
    '/auth/login': (req) {
      final dados = jsonDecode(req.body);
      if (dados['email'] == 'ana@loja.com' && dados['senha'] == 'senha1234') {
        return respostaJson({'token': 'tok-valido', 'usuario': ana, 'empresa': empresaJson()});
      }
      return respostaJson({'erro': 'e-mail ou senha inválidos'}, status: 401);
    },
    '/auth/me': (req) => protegida(req, {'usuario': ana, 'empresa': empresaJson()}),
    '/produtos': (req) => protegida(req, []),
    '/categorias': (req) => protegida(req, []),
  });
}

Future<void> abrirApp(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Entrada()));
  await tester.pumpAndSettle();
}

Future<void> abrirPeloMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, item));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    prepararSessao();
    tokenAceito = 'tok-valido';
  });

  testWidgets('sem empresa abre a configuração inicial', (tester) async {
    final api = montarApi(configurado: false);
    await api.usar(() => abrirApp(tester));

    expect(find.byType(SetupScreen), findsOneWidget);
    expect(api.chamadas('/auth/me'), isEmpty);
  });

  testWidgets('sem login abre a tela de login; entrar leva pro app e guarda o token', (tester) async {
    usarTelaAlta(tester);
    final api = montarApi();

    await api.usar(() async {
      await abrirApp(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      await preencher(tester, 'E-mail', 'ana@loja.com');
      await preencher(tester, 'Senha', 'senha1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Ana Admin'), findsOneWidget); // nome na barra de cima

      // as telas passam a mandar o token
      await abrirPeloMenu(tester, 'Produtos');
    });

    expect(api.chamadas('/produtos').single.headers['Authorization'], 'Bearer tok-valido');
    expect(await tokenGuardado(), 'tok-valido');
  });

  testWidgets('senha errada mostra o erro e continua no login', (tester) async {
    final api = montarApi();

    await api.usar(() async {
      await abrirApp(tester);
      await preencher(tester, 'E-mail', 'ana@loja.com');
      await preencher(tester, 'Senha', 'errada123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'e-mail ou senha inválidos'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('sessão expirou'), findsNothing);
    expect(await tokenGuardado(), isNull);
  });

  testWidgets('campos vazios são barrados no app', (tester) async {
    final api = montarApi();

    await api.usar(() async {
      await abrirApp(tester);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'informe o e-mail e a senha'), findsOneWidget);
    expect(api.chamadas('/auth/login'), isEmpty);
  });

  testWidgets('token salvo que ainda vale entra direto no app', (tester) async {
    prepararSessao(tokenSalvo: 'tok-valido');
    final api = montarApi();

    await api.usar(() => abrirApp(tester));

    expect(find.byType(AppShell), findsOneWidget);
    expect(api.chamadas('/auth/me').single.headers['Authorization'], 'Bearer tok-valido');
  });

  testWidgets('token salvo vencido volta pro login com aviso', (tester) async {
    prepararSessao(tokenSalvo: 'tok-vencido');
    final api = montarApi();

    await api.usar(() => abrirApp(tester));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);
    expect(await tokenGuardado(), isNull);
  });

  testWidgets('API fora do ar mostra o aviso e deixa tentar de novo', (tester) async {
    var noAr = false;
    final api = ApiFalsa({
      '/setup/status': (_) =>
          noAr ? respostaJson({'configurado': true}) : respostaJson({'erro': 'Erro na API'}, status: 502),
    });

    await api.usar(() async {
      await abrirApp(tester);
      expect(find.text('Não foi possível conectar à API.'), findsOneWidget);

      noAr = true;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
    });

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('sair volta pro login e apaga o token guardado', (tester) async {
    prepararSessao(tokenSalvo: 'tok-valido');
    final api = montarApi();

    await api.usar(() async {
      await abrirApp(tester);
      await tester.tap(find.byTooltip('Sair'));
      await tester.pumpAndSettle();
    });

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('sessão expirou'), findsNothing);
    expect(Sessao.token, isNull);
    expect(await tokenGuardado(), isNull);
  });

  testWidgets('sessão que expira no meio do uso fecha as telas abertas e volta pro login', (tester) async {
    usarTelaAlta(tester);
    prepararSessao(tokenSalvo: 'tok-valido');
    final api = montarApi();

    await api.usar(() async {
      await abrirApp(tester);
      await abrirPeloMenu(tester, 'Produtos');
      tokenAceito = 'outro'; // a sessao venceu no servidor
      // o formulario de produto busca as categorias e a API responde 401
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    });

    expect(find.byType(ProdutoForm), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);
  });
}
