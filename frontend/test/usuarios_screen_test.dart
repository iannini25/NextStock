import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/usuarios_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Finder iconeNoUsuario(String nome, IconData icone) {
  return find.descendant(of: find.widgetWithText(ListTile, nome), matching: find.byIcon(icone));
}

void main() {
  // tela de admin: os testes entram como um admin (id 99) que nao aparece nas listas
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'admin', id: 99);
  });

  testWidgets('admin não vê o botão de desativar a si mesmo', (tester) async {
    logarComo(perfil: 'admin', id: 1, nome: 'Ana');
    final api = ApiFalsa({
      '/usuarios': (_) => respostaJson([
            usuarioJson(id: 1, nome: 'Ana', perfil: 'admin'),
            usuarioJson(id: 2, nome: 'João'),
          ]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
    });

    expect(iconeNoUsuario('Ana', Icons.person_off), findsNothing);
    expect(iconeNoUsuario('João', Icons.person_off), findsOneWidget);
  });

  testWidgets('editando a si mesmo, perfil e ativo ficam travados', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'admin', id: 1, nome: 'Ana');
    final api = ApiFalsa({
      '/usuarios': (_) => respostaJson([usuarioJson(id: 1, nome: 'Ana', perfil: 'admin')]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(iconeNoUsuario('Ana', Icons.edit));
      await tester.pumpAndSettle();
    });

    expect(find.text('você não pode mudar o seu próprio perfil'), findsOneWidget);
    expect(find.text('você não pode desativar o seu próprio usuário'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
  });

  testWidgets('lista os usuários com perfil e situação', (tester) async {
    final api = ApiFalsa({
      '/usuarios': (_) => respostaJson([
            usuarioJson(id: 1, nome: 'Ana', perfil: 'admin'),
            usuarioJson(id: 2, nome: 'Maria', ativo: false),
          ]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.text('ana@loja.com  •  Administrador'), findsOneWidget);
    expect(find.text('maria@loja.com  •  Usuário  •  INATIVO'), findsOneWidget);
    // so usuario ativo tem o botao de desativar
    expect(iconeNoUsuario('Ana', Icons.person_off), findsOneWidget);
    expect(iconeNoUsuario('Maria', Icons.person_off), findsNothing);
  });

  testWidgets('desativar pede confirmação, chama a API e recarrega a lista', (tester) async {
    final api = ApiFalsa({
      '/usuarios': (_) => respostaJson([
            usuarioJson(id: 1, nome: 'Ana', perfil: 'admin'),
            usuarioJson(id: 2, nome: 'João'),
          ]),
      '/usuarios/2': (_) => respostaVazia(),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(iconeNoUsuario('João', Icons.person_off));
      await tester.pumpAndSettle();
      expect(find.textContaining('Desativar o usuário "João"?'), findsOneWidget);
      await tester.tap(find.text('Sim'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/usuarios/2').single.method, 'DELETE');
    expect(api.chamadas('/usuarios'), hasLength(2)); // carregou de novo depois de desativar
  });

  testWidgets('cria usuário novo pelo formulário', (tester) async {
    usarTelaAlta(tester);
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/usuarios': (req) {
        if (req.method == 'POST') {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(usuarioJson(id: 3, nome: 'Carlos'), status: 201);
        }
        return respostaJson([usuarioJson(id: 1, nome: 'Ana', perfil: 'admin')]);
      },
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();
      expect(find.text('Novo usuário'), findsOneWidget);

      await preencher(tester, 'Nome *', 'Carlos');
      await preencher(tester, 'E-mail *', 'carlos@loja.com');
      await preencher(tester, 'Senha (mínimo 8 caracteres) *', 'senha1234');
      await preencher(tester, 'Confirmar senha *', 'senha1234');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {
      'nome': 'Carlos',
      'email': 'carlos@loja.com',
      'perfil': 'usuario',
      'ativo': true,
      'senha': 'senha1234',
    });
    expect(find.text('Novo usuário'), findsNothing); // voltou pra lista
    expect(api.chamadas('/usuarios').where((r) => r.method == 'GET'), hasLength(2));
  });

  testWidgets('senha curta no cadastro é barrada no app', (tester) async {
    usarTelaAlta(tester);
    final api = ApiFalsa({'/usuarios': (_) => respostaJson([])});

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();
      await preencher(tester, 'Nome *', 'Carlos');
      await preencher(tester, 'E-mail *', 'carlos@loja.com');
      await preencher(tester, 'Senha (mínimo 8 caracteres) *', '123');
      await preencher(tester, 'Confirmar senha *', '123');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'a senha tem que ter pelo menos 8 caracteres'), findsOneWidget);
    expect(api.chamadas('/usuarios').where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('erro da API no cadastro aparece e o formulário continua aberto', (tester) async {
    usarTelaAlta(tester);
    final api = ApiFalsa({
      '/usuarios': (req) => req.method == 'POST'
          ? respostaJson({'erro': 'já existe usuário com esse e-mail'}, status: 400)
          : respostaJson([]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();
      await preencher(tester, 'Nome *', 'Carlos');
      await preencher(tester, 'E-mail *', 'ana@loja.com');
      await preencher(tester, 'Senha (mínimo 8 caracteres) *', 'senha1234');
      await preencher(tester, 'Confirmar senha *', 'senha1234');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'já existe usuário com esse e-mail'), findsOneWidget);
    expect(find.text('Novo usuário'), findsOneWidget);
  });

  testWidgets('editar sem preencher senha não manda senha', (tester) async {
    usarTelaAlta(tester);
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/usuarios': (_) => respostaJson([usuarioJson(id: 2, nome: 'João')]),
      '/usuarios/2': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(usuarioJson(id: 2, nome: 'João Silva'));
      },
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: UsuariosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(iconeNoUsuario('João', Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('Editar usuário'), findsOneWidget);
      expect(find.text('joão@loja.com'), findsOneWidget); // campo ja preenchido

      await preencher(tester, 'Nome *', 'João Silva');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/usuarios/2').single.method, 'PUT');
    expect(enviado, {'nome': 'João Silva', 'email': 'joão@loja.com', 'perfil': 'usuario', 'ativo': true});
  });
}
