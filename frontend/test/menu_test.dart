import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/empresa_screen.dart';
import 'package:nextstock/screens/produtos_screen.dart';
import 'package:nextstock/screens/usuarios_screen.dart';
import 'package:nextstock/shell/app_shell.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

// o menu escolhe a tela pelo id do item e mostra so o que o perfil pode ver.
// usa o layout de celular (menu no drawer)
void main() {
  setUp(prepararSessao);

  ApiFalsa montarApi() => ApiFalsa({
        '/produtos': (_) => respostaJson([]),
        '/setup/status': (_) => respostaJson({'configurado': true}),
        '/empresa': (_) => respostaJson(empresaJson()),
        '/usuarios': (_) => respostaJson([]),
      });

  Future<void> abrirMenu(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  Future<void> abrirPeloMenu(WidgetTester tester, ApiFalsa api, String item) async {
    await api.usar(() async {
      await abrirMenu(tester);
      await tester.tap(find.widgetWithText(ListTile, item));
      await tester.pumpAndSettle();
    });
  }

  Finder itemDoMenu(String titulo) => find.widgetWithText(ListTile, titulo);

  test('só Importar e Usuários são itens de administrador', () {
    expect(modulosNav.where((m) => m.soAdmin).map((m) => m.titulo), ['Importar', 'Usuários']);
    expect(modulosNav.map((m) => m.id).toSet(), hasLength(modulosNav.length)); // ids nao repetem
  });

  testWidgets('admin vê todos os itens do menu', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'admin');
    await montarApi().usar(() => abrirMenu(tester));

    for (final m in modulosNav) {
      expect(itemDoMenu(m.titulo), findsOneWidget, reason: m.titulo);
    }
  });

  testWidgets('usuário comum não vê Importar nem Usuários (nem nos cartões do início)', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'usuario');
    await montarApi().usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();
    });

    // cartoes da tela inicial
    expect(find.text('Importar'), findsNothing);
    expect(find.text('Usuários'), findsNothing);
    expect(find.text('Produtos'), findsOneWidget);
    expect(find.text('Empresa'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(itemDoMenu('Importar'), findsNothing);
    expect(itemDoMenu('Usuários'), findsNothing);
    expect(itemDoMenu('Relatórios'), findsOneWidget);
    expect(itemDoMenu('Empresa'), findsOneWidget);
  });

  testWidgets('item Produtos continua abrindo a tela de produtos', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'usuario');
    await abrirPeloMenu(tester, montarApi(), 'Produtos');
    expect(find.byType(ProdutosScreen), findsOneWidget);
  });

  testWidgets('item Empresa abre a tela da empresa (mesmo pro usuário comum)', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'usuario');
    await abrirPeloMenu(tester, montarApi(), 'Empresa');
    expect(find.byType(EmpresaScreen), findsOneWidget);
  });

  testWidgets('item Usuários abre a tela de usuários pro admin', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'admin');
    await abrirPeloMenu(tester, montarApi(), 'Usuários');
    expect(find.byType(UsuariosScreen), findsOneWidget);
  });

  testWidgets('cartão da tela inicial abre o módulo certo', (tester) async {
    usarTelaAlta(tester);
    logarComo(perfil: 'admin');
    await montarApi().usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuários'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(UsuariosScreen), findsOneWidget);
  });
}
