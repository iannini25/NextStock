import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/produtos_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';

void main() {
  testWidgets('mostra o carregando e depois a lista vinda da API', (tester) async {
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson([
            produtoJson(id: 1, nome: 'Leite Integral 1L', categoria: 'Laticínios', quantidade: 10, minimo: 2),
            produtoJson(id: 2, nome: 'Pão Francês', validade: '2026-12-01'),
          ]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: ProdutosScreen()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Leite Integral 1L'), findsOneWidget);
    expect(find.text('Pão Francês'), findsOneWidget);
    expect(find.textContaining('Laticínios'), findsOneWidget);
    expect(find.textContaining('estoque: 10 UN (mín: 2)'), findsWidgets);
    expect(find.textContaining('validade: 2026-12-01'), findsOneWidget);

    final req = api.requisicoes.single;
    expect(req.method, 'GET');
    expect(req.url.toString(), 'http://127.0.0.1:8000/produtos');
  });

  testWidgets('lista vazia mostra a mensagem de nenhum produto', (tester) async {
    final api = ApiFalsa({'/produtos': (_) => respostaJson([])});

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: ProdutosScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.text('Nenhum produto cadastrado.'), findsOneWidget);
  });

  testWidgets('erro da API aparece num SnackBar', (tester) async {
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson({'erro': 'banco fora do ar'}, status: 500),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: ProdutosScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'banco fora do ar'), findsOneWidget);
    expect(find.text('Nenhum produto cadastrado.'), findsOneWidget);
  });
}
