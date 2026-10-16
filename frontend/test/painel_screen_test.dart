import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/painel_screen.dart';

import 'apoio/api_falsa.dart';

void main() {
  // tela alta pra caber os 11 indicadores sem precisar rolar
  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('mostra os indicadores que vieram da API', (tester) async {
    telaAlta(tester);
    final api = ApiFalsa({
      '/painel': (_) => respostaJson({
            'total_produtos': 12,
            'itens_em_estoque': 340,
            'valor_estoque': 150.5,
            'produtos_vencidos': 2,
            'valor_vencido': 18.25,
            'produtos_vencendo': 3,
            'produtos_em_risco': 4,
            'vendas_30_dias': 77,
            'faturamento_30_dias': 999.9,
            'percentual_desperdicio': 3.25,
            'giro_estoque': 0.4,
          }),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: PainelScreen()));
      await tester.pumpAndSettle();
    });

    void confere(String nome, String valor) {
      expect(find.widgetWithText(ListTile, nome), findsOneWidget);
      expect(
        find.descendant(of: find.widgetWithText(ListTile, nome), matching: find.text(valor)),
        findsOneWidget,
        reason: '$nome deveria mostrar $valor',
      );
    }

    confere('Produtos cadastrados', '12');
    confere('Itens em estoque', '340');
    confere('Valor em estoque', r'R$ 150.50');
    confere('Produtos vencidos', '2');
    confere('Valor perdido com vencidos', r'R$ 18.25');
    confere('Vencendo em 7 dias', '3');
    confere('Em risco de faltar', '4');
    confere('Vendas em 30 dias', '77');
    confere('Faturamento em 30 dias', r'R$ 999.90');
    confere('Desperdício', '3.25%');
    confere('Giro de estoque', '0.40');
    expect(api.chamadas('/painel'), hasLength(1));
  });

  testWidgets('erro da API mostra SnackBar e a mensagem de painel indisponível', (tester) async {
    final api = ApiFalsa({
      '/painel': (_) => respostaJson({'erro': 'falha ao montar o painel'}, status: 500),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: PainelScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'falha ao montar o painel'), findsOneWidget);
    expect(find.text('Não foi possível carregar o painel.'), findsOneWidget);
  });
}
