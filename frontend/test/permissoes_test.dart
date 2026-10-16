import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/categorias_screen.dart';
import 'package:nextstock/screens/empresa_screen.dart';
import 'package:nextstock/screens/eventos_screen.dart';
import 'package:nextstock/screens/produtos_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';

// o app esconde o que o perfil nao pode fazer (a API tambem barra com 403)
void main() {
  setUp(prepararSessao);

  final api = ApiFalsa({
    '/produtos': (_) => respostaJson([produtoJson(id: 1, nome: 'Leite')]),
    '/categorias': (_) => respostaJson([
          {'id_categoria': 1, 'nome': 'Laticínios', 'descricao': null},
        ]),
    '/eventos': (_) => respostaJson([
          {'id_evento': 1, 'nome': 'Feira', 'data_inicio': '2026-11-01', 'data_fim': '2026-11-02', 'impacto_percentual': 20},
        ]),
    '/setup/status': (_) => respostaJson({'configurado': true}),
    '/empresa': (_) => respostaJson(empresaJson()),
  });

  Future<void> abrir(WidgetTester tester, Widget tela) async {
    await api.usar(() async {
      await tester.pumpWidget(MaterialApp(home: tela));
      await tester.pumpAndSettle();
    });
  }

  final telasComExcluir = <String, Widget>{
    'Produtos': const ProdutosScreen(),
    'Categorias': const CategoriasScreen(),
    'Eventos': const EventosScreen(),
  };

  for (final entrada in telasComExcluir.entries) {
    testWidgets('${entrada.key}: usuário comum não vê o botão de excluir', (tester) async {
      logarComo(perfil: 'usuario');
      await abrir(tester, entrada.value);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('${entrada.key}: admin vê o botão de excluir', (tester) async {
      logarComo(perfil: 'admin');
      await abrir(tester, entrada.value);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  }

  testWidgets('Produtos: usuário comum continua podendo editar e cadastrar', (tester) async {
    logarComo(perfil: 'usuario');
    await abrir(tester, const ProdutosScreen());
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Empresa: usuário comum vê os dados só pra leitura', (tester) async {
    logarComo(perfil: 'usuario');
    await abrir(tester, const EmpresaScreen());

    expect(find.text('Mercado Bom Preço LTDA'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);
    expect(find.text('Só administradores alteram os dados da empresa.'), findsOneWidget);
    final campos = tester.widgetList<TextField>(find.byType(TextField));
    expect(campos, isNotEmpty);
    expect(campos.every((c) => c.readOnly), isTrue);
  });

  testWidgets('Empresa: admin pode editar', (tester) async {
    logarComo(perfil: 'admin');
    await abrir(tester, const EmpresaScreen());

    expect(find.text('Salvar'), findsOneWidget);
    expect(tester.widgetList<TextField>(find.byType(TextField)).any((c) => c.readOnly), isFalse);
  });
}
