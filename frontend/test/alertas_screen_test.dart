import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/alertas_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';

ApiFalsa montarApi() {
  return ApiFalsa({
    '/produtos/vencendo': (_) => respostaJson([
          produtoJson(id: 1, nome: 'Iogurte', validade: dataDaqui(-2)),
          produtoJson(id: 2, nome: 'Banana', validade: dataDaqui(3)),
        ]),
    '/produtos/risco-ruptura': (_) => respostaJson([
          produtoJson(id: 3, nome: 'Alface', quantidade: 1, minimo: 15, motivo: 'estoque no mínimo'),
        ]),
    '/clima': (_) => respostaJson(climaJson(dias: [
          {'data': dataDaqui(1), 'temperatura': 20.0, 'chuva_mm': 5.0, 'condicao': 'chuva'},
        ])),
  });
}

void main() {
  testWidgets('abre no modo vencendo com 7 dias e mostra o clima', (tester) async {
    final api = montarApi();

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('VENCIDO há 2 dia(s)'), findsOneWidget);
    expect(find.textContaining('vence em 3 dia(s)'), findsOneWidget);
    expect(find.text('Clima em Sao Paulo'), findsOneWidget);
    expect(find.textContaining('chuva  5.0 mm'), findsOneWidget);
    expect(api.chamadas('/produtos/vencendo').single.url.queryParameters['dias'], '7');
    expect(api.chamadas('/clima'), hasLength(1));
  });

  testWidgets('trocar o filtro de dias busca de novo com o novo prazo', (tester) async {
    final api = montarApi();

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 dias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 dias').last);
      await tester.pumpAndSettle();
    });

    final dias = api.chamadas('/produtos/vencendo').map((r) => r.url.queryParameters['dias']);
    expect(dias, ['7', '15']);
  });

  testWidgets('botão Vai faltar mostra o risco de ruptura com o motivo', (tester) async {
    final api = montarApi();

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vai faltar'));
      await tester.pumpAndSettle();
    });

    expect(find.text('Alface'), findsOneWidget);
    expect(find.textContaining('estoque: 1 UN'), findsOneWidget);
    expect(find.textContaining('estoque no mínimo'), findsOneWidget);
    expect(find.text('Iogurte'), findsNothing);
    expect(api.chamadas('/produtos/risco-ruptura'), hasLength(1));
  });

  testWidgets('erro da API aparece num SnackBar', (tester) async {
    final api = ApiFalsa({
      '/produtos/vencendo': (_) => respostaJson({'erro': 'dias tem que ser entre 0 e 365'}, status: 400),
      '/clima': (_) => respostaJson(climaJson()),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'dias tem que ser entre 0 e 365'), findsOneWidget);
  });
}
