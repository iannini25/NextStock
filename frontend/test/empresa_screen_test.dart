import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/empresa_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

// preenche o formulario da configuracao inicial com dados validos
Future<void> preencherSetup(WidgetTester tester, {String senha = 'senhaforte123', String? confirmacao}) async {
  await preencher(tester, 'Razão social *', 'Mercado Bom Preço LTDA');
  await preencher(tester, 'CNPJ', '12345678000190');
  await preencher(tester, 'Seu nome *', 'Ana Admin');
  await preencher(tester, 'E-mail de acesso *', 'ana@bompreco.com');
  await preencher(tester, 'Senha (mínimo 8 caracteres) *', senha);
  await preencher(tester, 'Confirmar senha *', confirmacao ?? senha);
}

void main() {
  setUp(prepararSessao);

  testWidgets('sem empresa mostra a configuração inicial e cadastra empresa e admin', (tester) async {
    usarTelaAlta(tester);
    var configurado = false;
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/setup/status': (_) => respostaJson({'configurado': configurado}),
      '/setup': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        configurado = true;
        return respostaJson({
          'empresa': empresaJson(),
          'admin': usuarioJson(id: 1, nome: 'Ana Admin', perfil: 'admin'),
        }, status: 201);
      },
      '/empresa': (_) => respostaJson(empresaJson()),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Configuração inicial'), findsOneWidget);

      await preencherSetup(tester);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {
      'empresa': {
        'nome': 'Mercado Bom Preço LTDA',
        'nome_fantasia': null,
        'cnpj': '12345678000190',
        'email': null,
        'telefone': null,
      },
      'admin': {
        'nome': 'Ana Admin',
        'email': 'ana@bompreco.com',
        'perfil': 'admin',
        'ativo': true,
        'senha': 'senhaforte123',
      },
    });
    // depois de configurar, a tela recarrega e mostra os dados da empresa
    expect(find.text('Configuração inicial'), findsNothing);
    expect(find.text('Empresa configurada'), findsOneWidget);
    expect(find.text('Mercado Bom Preço LTDA'), findsOneWidget);
    expect(find.text('Bom Preço'), findsOneWidget);
  });

  testWidgets('senha curta é barrada no app, sem chamar a API', (tester) async {
    usarTelaAlta(tester);
    final api = ApiFalsa({'/setup/status': (_) => respostaJson({'configurado': false})});

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
      await preencherSetup(tester, senha: '1234');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'a senha tem que ter pelo menos 8 caracteres'), findsOneWidget);
    expect(api.chamadas('/setup'), isEmpty);
  });

  testWidgets('senhas diferentes são barradas no app', (tester) async {
    usarTelaAlta(tester);
    final api = ApiFalsa({'/setup/status': (_) => respostaJson({'configurado': false})});

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
      await preencherSetup(tester, confirmacao: 'outrasenha123');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'as senhas não conferem'), findsOneWidget);
    expect(api.chamadas('/setup'), isEmpty);
  });

  testWidgets('erro da API na configuração aparece num SnackBar', (tester) async {
    usarTelaAlta(tester);
    final api = ApiFalsa({
      '/setup/status': (_) => respostaJson({'configurado': false}),
      '/setup': (_) => respostaJson({'erro': 'a empresa já foi configurada'}, status: 409),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
      await preencherSetup(tester);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'a empresa já foi configurada'), findsOneWidget);
    expect(find.text('Configuração inicial'), findsOneWidget);
  });

  testWidgets('com empresa mostra os dados e o admin salva as alterações', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'admin');
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/setup/status': (_) => respostaJson({'configurado': true}),
      '/empresa': (req) {
        if (req.method == 'PUT') {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(empresaJson(fantasia: 'Bom Preço Centro'));
        }
        return respostaJson(empresaJson());
      },
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Mercado Bom Preço LTDA'), findsOneWidget);
      expect(find.text('12345678000190'), findsOneWidget);

      await preencher(tester, 'Nome fantasia', 'Bom Preço Centro');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {
      'nome': 'Mercado Bom Preço LTDA',
      'nome_fantasia': 'Bom Preço Centro',
      'cnpj': '12345678000190',
      'email': 'contato@bompreco.com',
      'telefone': '(11) 99999-0000',
    });
    expect(find.text('Dados da empresa salvos'), findsOneWidget);
  });

  testWidgets('API fora do ar não mostra a configuração inicial por engano', (tester) async {
    final api = ApiFalsa({
      '/setup/status': (_) => respostaJson({'erro': 'erro interno'}, status: 500),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: EmpresaScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.text('Configuração inicial'), findsNothing);
    expect(find.text('Não foi possível carregar os dados da empresa.'), findsOneWidget);
    expect(find.widgetWithText(SnackBar, 'erro interno'), findsOneWidget);
  });
}
