import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/empresa_screen.dart';
import 'package:nextstock/screens/produtos_screen.dart';
import 'package:nextstock/screens/usuarios_screen.dart';
import 'package:nextstock/shell/app_shell.dart';

import 'apoio/api_falsa.dart';
import 'apoio/tela.dart';

// o menu escolhe a tela pela posicao do item: cada item tem que abrir a tela certa.
// usa o layout de celular (menu no drawer)
void main() {
  Future<void> abrirPeloMenu(WidgetTester tester, ApiFalsa api, String item) async {
    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, item));
      await tester.pumpAndSettle();
    });
  }

  ApiFalsa montarApi() => ApiFalsa({
        '/produtos': (_) => respostaJson([]),
        '/setup/status': (_) => respostaJson({'configurado': false}),
        '/usuarios': (_) => respostaJson([]),
      });

  testWidgets('menu tem os itens novos de Empresa e Usuários no fim', (tester) async {
    expect(modulosNav.map((m) => m.titulo).toList().sublist(modulosNav.length - 2), ['Empresa', 'Usuários']);
  });

  testWidgets('item Produtos continua abrindo a tela de produtos', (tester) async {
    usarTelaAlta(tester);
    await abrirPeloMenu(tester, montarApi(), 'Produtos');
    expect(find.byType(ProdutosScreen), findsOneWidget);
  });

  testWidgets('item Empresa abre a tela da empresa', (tester) async {
    usarTelaAlta(tester);
    await abrirPeloMenu(tester, montarApi(), 'Empresa');
    expect(find.byType(EmpresaScreen), findsOneWidget);
    expect(find.text('Configuração inicial'), findsOneWidget);
  });

  testWidgets('item Usuários abre a tela de usuários', (tester) async {
    usarTelaAlta(tester);
    await abrirPeloMenu(tester, montarApi(), 'Usuários');
    expect(find.byType(UsuariosScreen), findsOneWidget);
  });
}
