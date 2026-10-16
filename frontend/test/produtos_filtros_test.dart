import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/produtos_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

final leite = produtoJson(id: 1, nome: 'Leite Integral', categoria: 'Laticínios');
final banana = produtoJson(id: 2, nome: 'Banana', categoria: 'Hortifruti');

// API falsa que filtra de verdade pela busca, pra lista da tela mudar conforme o filtro
ApiFalsa montarApi({bool categoriasFalham = false}) {
  return ApiFalsa({
    '/produtos': (req) {
      final busca = (req.url.queryParameters['busca'] ?? '').toLowerCase();
      final lista = [leite, banana].where((p) => (p['nome'] as String).toLowerCase().contains(busca)).toList();
      return respostaJson(lista);
    },
    '/categorias': (_) => categoriasFalham
        ? respostaJson({'erro': 'falhou'}, status: 500)
        : respostaJson([
            {'id_categoria': 1, 'nome': 'Laticínios', 'descricao': null},
            {'id_categoria': 2, 'nome': 'Hortifruti', 'descricao': null},
          ]),
  });
}

Map<String, String> filtrosDa(ApiFalsa api) => api.chamadas('/produtos').last.url.queryParameters;

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  Future<void> abrir(WidgetTester tester, ApiFalsa api) async {
    usarTelaAlta(tester, largura: 1000);
    await tester.pumpWidget(const MaterialApp(home: ProdutosScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('busca espera parar de digitar e manda o texto pra API', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester, api);
      await tester.enterText(find.byType(TextField), 'le');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'leite');
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.chamadas('/produtos'), hasLength(1)); // ainda nao buscou: a pessoa esta digitando
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/produtos'), hasLength(2)); // a inicial + uma so pela busca
    expect(filtrosDa(api), {'busca': 'leite'});
    expect(find.text('Leite Integral'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);
  });

  testWidgets('chip de situação filtra e tocar de novo tira o filtro', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester, api);
      await tester.tap(find.text('Baixo estoque'));
      await tester.pumpAndSettle();
      expect(filtrosDa(api), {'situacao': 'baixo_estoque'});

      await tester.tap(find.text('Vencidos')); // troca de situacao (so uma por vez)
      await tester.pumpAndSettle();
      expect(filtrosDa(api), {'situacao': 'vencido'});

      await tester.tap(find.text('Vencidos'));
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api), isEmpty);
  });

  testWidgets('filtro de categoria manda o id da categoria', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester, api);
      await tester.tap(find.text('Todas as categorias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hortifruti').last);
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api), {'id_categoria': '2'});
  });

  testWidgets('filtros combinados vão juntos', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester, api);
      await tester.tap(find.text('Sem estoque'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api), {'busca': 'ban', 'situacao': 'sem_estoque'});
  });

  testWidgets('sem resultado mostra a mensagem certa e limpar filtros volta tudo', (tester) async {
    final api = montarApi();
    await api.usar(() async {
      await abrir(tester, api);
      expect(find.text('Limpar filtros'), findsNothing);

      await tester.enterText(find.byType(TextField), 'chocolate');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto encontrado com esses filtros.'), findsOneWidget);
      expect(find.text('Nenhum produto cadastrado.'), findsNothing);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api), isEmpty);
    expect(find.text('Leite Integral'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('se as categorias não carregarem, a lista de produtos funciona igual', (tester) async {
    final api = montarApi(categoriasFalham: true);
    await api.usar(() => abrir(tester, api));

    expect(find.text('Leite Integral'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
