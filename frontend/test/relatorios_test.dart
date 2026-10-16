import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/relatorios_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> itemAbc(int posicao, String nome, String classe, double faturamento, int qtd, double perc, double acum) => {
      'posicao': posicao, 'id_produto': posicao, 'produto_nome': nome, 'categoria_nome': null,
      'quantidade_vendida': qtd, 'faturamento': faturamento, 'valor': faturamento, 'percentual': perc,
      'percentual_acumulado': acum, 'classe': classe,
    };

Map<String, dynamic> curvaJson(String criterio) => {
      'dias': 30, 'criterio': criterio, 'total': 1000.0, 'limites': {'A': 80, 'B': 95},
      'resumo': {
        'A': {'produtos': 2, 'valor': 750.0, 'percentual_valor': 75.0},
        'B': {'produtos': 1, 'valor': 200.0, 'percentual_valor': 20.0},
        'C': {'produtos': 1, 'valor': 50.0, 'percentual_valor': 5.0},
      },
      'itens': [
        itemAbc(1, 'Arroz', 'A', 500.0, 50, 50.0, 50.0),
        itemAbc(2, 'Feijão', 'A', 250.0, 40, 25.0, 75.0),
        itemAbc(3, 'Café', 'B', 200.0, 10, 20.0, 95.0),
        itemAbc(4, 'Parado', 'C', 50.0, 1, 5.0, 100.0),
      ],
    };

ApiFalsa montarApi() => ApiFalsa({
      '/relatorios/consumo': (_) => respostaJson({'dias': 30, 'total_vendido': 3, 'faturamento_total': 15.0, 'itens': [
            {'id_produto': 1, 'produto_nome': 'Leite', 'categoria_nome': null, 'quantidade_vendida': 3,
             'faturamento': 15.0, 'percentual_do_total': 100.0},
          ]}),
      '/relatorios/curva-abc': (req) => respostaJson(curvaJson(req.url.queryParameters['criterio'] ?? 'faturamento')),
    });

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  Future<void> abrir(WidgetTester tester) async {
    usarTelaAlta(tester, largura: 1000);
    await tester.pumpWidget(const MaterialApp(home: RelatoriosScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> escolherRelatorio(WidgetTester tester, String atual, String novo) async {
    await tester.tap(find.text(atual));
    await tester.pumpAndSettle();
    await tester.tap(find.text(novo).last);
    await tester.pumpAndSettle();
  }

  testWidgets('curva ABC mostra o resumo por classe e o selo de cada produto', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester);
      await escolherRelatorio(tester, 'Consumo', 'Curva ABC');
    });

    expect(api.chamadas('/relatorios/curva-abc').single.url.queryParameters, {'dias': '30', 'criterio': 'faturamento'});
    expect(find.text('2 produto(s) • 75.0% do faturamento'), findsOneWidget);
    expect(find.text('1 produto(s) • 20.0% do faturamento'), findsOneWidget);
    expect(find.text('1º  Arroz'), findsOneWidget);
    expect(find.text('R\$ 500.00  •  50.0% do total  •  acumulado 50.0%'), findsOneWidget);
    // selo da classe de cada produto (nos itens da lista)
    Finder seloDo(String produto, String classe) => find.descendant(
        of: find.widgetWithText(ListTile, produto), matching: find.text(classe));
    expect(seloDo('1º  Arroz', 'A'), findsOneWidget);
    expect(seloDo('3º  Café', 'B'), findsOneWidget);
    expect(seloDo('4º  Parado', 'C'), findsOneWidget);
  });

  testWidgets('trocar o critério pra quantidade busca de novo e mostra as unidades', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester);
      await escolherRelatorio(tester, 'Consumo', 'Curva ABC');
      await tester.tap(find.text('Faturamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quantidade').last);
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/relatorios/curva-abc').last.url.queryParameters['criterio'], 'quantidade');
    expect(find.text('2 produto(s) • 75.0% do volume'), findsOneWidget);
    expect(find.textContaining('50 vendidos'), findsOneWidget);
  });

  testWidgets('o seletor de critério só aparece na curva ABC e os outros relatórios continuam', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester);
      expect(find.text('Por:'), findsNothing);
      expect(find.textContaining('total vendido: 3'), findsOneWidget); // consumo, o padrao

      await escolherRelatorio(tester, 'Consumo', 'Curva ABC');
      expect(find.text('Por:'), findsOneWidget);

      await escolherRelatorio(tester, 'Curva ABC', 'Consumo');
    });

    expect(find.text('Por:'), findsNothing);
    expect(find.textContaining('total vendido: 3'), findsOneWidget);
    expect(api.chamadas('/relatorios/consumo'), hasLength(2));
  });
}
