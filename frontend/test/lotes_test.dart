import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/models/produto.dart';
import 'package:nextstock/screens/alertas_screen.dart';
import 'package:nextstock/screens/lotes_screen.dart';
import 'package:nextstock/screens/produto_form.dart';
import 'package:nextstock/screens/produtos_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> loteJson({
  required int id,
  int idProduto = 1,
  String? codigo,
  int atual = 10,
  int inicial = 10,
  int? dias,
  String origem = 'entrada',
}) =>
    {
      'id_lote': id,
      'id_produto': idProduto,
      'produto_nome': 'Leite',
      'unidade': 'UN',
      'codigo_lote': codigo,
      'data_entrada': '2026-10-01',
      'data_validade': dias == null ? null : dataDaqui(dias),
      'dias_para_vencer': dias,
      'vencido': dias != null && dias < 0,
      'quantidade_inicial': inicial,
      'quantidade_atual': atual,
      'custo_unitario': 3.2,
      'origem': origem,
      'usuario': 'Ana',
    };

final leiteJson = produtoJson(id: 1, nome: 'Leite', quantidade: 15, validade: dataDaqui(2));
final leite = Produto.fromJson(leiteJson);

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  Future<void> abrirLotes(WidgetTester tester) async {
    usarTelaAlta(tester);
    await tester.pumpWidget(MaterialApp(home: LotesScreen(produto: leite)));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os lotes com saldo, validade e origem', (tester) async {
    final api = ApiFalsa({
      '/produtos/1/lotes': (req) => respostaJson({
            'produto': leiteJson,
            'lotes': [
              loteJson(id: 2, codigo: 'L-778', atual: 5, inicial: 12, dias: 2),
              loteJson(id: 1, atual: 10, dias: null, origem: 'inicial'),
            ],
          }),
    });

    await api.usar(() => abrirLotes(tester));

    expect(find.text('Lotes — Leite'), findsOneWidget);
    expect(find.text('Estoque: 15 UN'), findsOneWidget);
    expect(find.text('Lote L-778  •  5 de 12 UN'), findsOneWidget);
    expect(find.textContaining('vence em 2 dia(s)'), findsOneWidget);
    expect(find.text('Lote #1  •  10 de 10 UN'), findsOneWidget);
    expect(find.textContaining('sem validade'), findsOneWidget);
    expect(find.textContaining('estoque inicial'), findsOneWidget);
    expect(api.chamadas('/produtos/1/lotes').single.url.queryParameters, isEmpty);
  });

  testWidgets('mostrar esgotados pede todos os lotes', (tester) async {
    final api = ApiFalsa({
      '/produtos/1/lotes': (req) => respostaJson({
            'produto': leiteJson,
            'lotes': [
              loteJson(id: 1, atual: 15, dias: 2),
              if (req.url.queryParameters['todos'] == '1') loteJson(id: 9, atual: 0, inicial: 4, dias: 1),
            ],
          }),
    });

    await api.usar(() async {
      await abrirLotes(tester);
      await tester.tap(find.text('Mostrar lotes esgotados'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/produtos/1/lotes').last.url.queryParameters, {'todos': '1'});
    expect(find.textContaining('ESGOTADO'), findsOneWidget);
  });

  testWidgets('nova entrada manda a mercadoria pra API e recarrega os lotes', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/produtos/1/lotes': (_) => respostaJson({'produto': leiteJson, 'lotes': []}),
      '/lotes': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson({'lote': loteJson(id: 3), 'produto': leiteJson}, status: 201);
      },
    });

    await api.usar(() async {
      await abrirLotes(tester);
      expect(find.text('Nenhum lote com estoque. Use "Nova entrada".'), findsOneWidget);
      await tester.tap(find.text('Nova entrada'));
      await tester.pumpAndSettle();
      expect(find.text('Nova entrada — Leite'), findsOneWidget);
      expect(find.text('3.0'), findsOneWidget); // custo ja vem com o custo do produto

      await preencher(tester, 'Quantidade *', '24');
      await preencher(tester, 'Validade (aaaa-mm-dd, vazio = sem validade)', '2026-11-30');
      await preencher(tester, 'Código do lote (opcional)', 'L-900');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {
      'id_produto': 1,
      'quantidade': 24,
      'data_validade': '2026-11-30',
      'codigo_lote': 'L-900',
      'custo_unitario': 3.0,
      'data_entrada': null,
    });
    expect(find.text('Lotes — Leite'), findsOneWidget); // voltou
    expect(api.chamadas('/produtos/1/lotes'), hasLength(2)); // e recarregou
  });

  testWidgets('entrada sem quantidade é barrada no app', (tester) async {
    final api = ApiFalsa({'/produtos/1/lotes': (_) => respostaJson({'produto': leiteJson, 'lotes': []})});

    await api.usar(() async {
      await abrirLotes(tester);
      await tester.tap(find.text('Nova entrada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'informe uma quantidade maior que zero'), findsOneWidget);
    expect(api.chamadas('/lotes'), isEmpty);
  });

  testWidgets('corrigir lote manda só código e validade', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/produtos/1/lotes': (_) => respostaJson({'produto': leiteJson, 'lotes': [loteJson(id: 2, codigo: 'L1', dias: 5)]}),
      '/lotes/2': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson({'lote': loteJson(id: 2), 'produto': leiteJson});
      },
    });

    await api.usar(() async {
      await abrirLotes(tester);
      await tester.tap(find.byTooltip('Corrigir código ou validade'));
      await tester.pumpAndSettle();
      expect(find.text('Corrigir Lote L1'), findsOneWidget);
      expect(find.text('Quantidade *'), findsNothing); // quantidade nao se corrige
      await preencher(tester, 'Validade (aaaa-mm-dd, vazio = sem validade)', '2026-12-24');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/lotes/2').single.method, 'PUT');
    expect(enviado, {'codigo_lote': 'L1', 'data_validade': '2026-12-24'});
  });

  testWidgets('botão de lotes na lista de produtos abre os lotes e recarrega na volta', (tester) async {
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson([leiteJson]),
      '/categorias': (_) => respostaJson([]),
      '/produtos/1/lotes': (_) => respostaJson({'produto': leiteJson, 'lotes': [loteJson(id: 1)]}),
    });

    await api.usar(() async {
      usarTelaAlta(tester, largura: 1000);
      await tester.pumpWidget(const MaterialApp(home: ProdutosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lotes'));
      await tester.pumpAndSettle();
      expect(find.byType(LotesScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/produtos'), hasLength(2));
  });

  testWidgets('editar produto: quantidade e validade só de leitura e não vão pra API', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/categorias': (_) => respostaJson([]),
      '/produtos/1': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(leiteJson);
      },
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(MaterialApp(home: ProdutoForm(produto: leite)));
      await tester.pumpAndSettle();
      final qtd = tester.widget<TextField>(find.widgetWithText(TextField, 'Quantidade em estoque'));
      expect(qtd.enabled, isFalse);
      expect(find.text('Gerenciar lotes (entradas e validades)'), findsOneWidget);

      await preencher(tester, 'Nome *', 'Leite Integral');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado!['nome'], 'Leite Integral');
    expect(enviado!['quantidade_estoque'], isNull); // a API mantem o estoque dos lotes
    expect(enviado!['data_validade'], isNull);
  });

  testWidgets('cadastrar produto novo continua mandando quantidade e validade', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/categorias': (_) => respostaJson([]),
      '/produtos': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(leiteJson, status: 201);
      },
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: ProdutoForm()));
      await tester.pumpAndSettle();
      await preencher(tester, 'Nome *', 'Queijo');
      await preencher(tester, 'Preço de venda *', '20');
      await preencher(tester, 'Quantidade em estoque', '8');
      await preencher(tester, 'Validade (aaaa-mm-dd)', '2026-12-01');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    });

    expect(enviado!['quantidade_estoque'], 8);
    expect(enviado!['data_validade'], '2026-12-01');
  });

  testWidgets('alertas: vencendo mostra os lotes de cada produto', (tester) async {
    final api = ApiFalsa({
      '/produtos/vencendo': (_) => respostaJson([leiteJson]),
      '/lotes/vencendo': (_) => respostaJson([loteJson(id: 4, codigo: 'L-12', atual: 6, dias: 2)]),
      '/clima': (_) => respostaJson(climaJson()),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('Lote L-12: 6 UN — vence em 2 dia(s)'), findsOneWidget);
    expect(api.chamadas('/lotes/vencendo').single.url.queryParameters['dias'], '7');
  });
}
