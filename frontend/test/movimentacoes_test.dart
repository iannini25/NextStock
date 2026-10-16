import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/models/produto.dart';
import 'package:nextstock/screens/lotes_screen.dart';
import 'package:nextstock/screens/movimentacoes_screen.dart';
import 'package:nextstock/shell/app_shell.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> movJson({
  required int id,
  String tipo = 'entrada',
  String nomeTipo = 'Entrada',
  int sinal = 1,
  int quantidade = 20,
  int? saldo = 25,
  String? lote = 'Lote L-1',
  String origem = 'manual',
  String nomeOrigem = 'Manual',
  String? usuario = 'Ana',
  String produto = 'Leite',
}) =>
    {
      'id_movimentacao': id,
      'id_produto': 1,
      'produto_nome': produto,
      'unidade': 'UN',
      'id_lote': 1,
      'lote': lote,
      'tipo': tipo,
      'nome_tipo': nomeTipo,
      'sinal': sinal,
      'quantidade': quantidade,
      'saldo_produto_apos': saldo,
      'custo_unitario': 3.0,
      'id_venda': null,
      'usuario': usuario,
      'origem': origem,
      'nome_origem': nomeOrigem,
      'observacao': null,
      'data_hora': '2026-10-16T14:30:00',
    };

Map<String, dynamic> paginaJson(List<Map<String, dynamic>> itens, {int? total, int pagina = 1}) => {
      'itens': itens,
      'total': total ?? itens.length,
      'pagina': pagina,
      'limite': 50,
      'tipos': {'entrada': 'Entrada', 'venda': 'Venda', 'ajuste_saida': 'Ajuste (saída)'},
      'origens': {'manual': 'Manual'},
    };

ApiFalsa montarApi(Map<String, dynamic> Function(Map<String, String> filtros) responder) {
  return ApiFalsa({
    '/movimentacoes': (req) => respostaJson(responder(req.url.queryParameters)),
    '/produtos': (_) => respostaJson([produtoJson(id: 1, nome: 'Leite'), produtoJson(id: 2, nome: 'Arroz')]),
  });
}

Map<String, String> filtrosDa(ApiFalsa api) => api.chamadas('/movimentacoes').last.url.queryParameters;

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  Future<void> abrir(WidgetTester tester, {Widget tela = const MovimentacoesScreen()}) async {
    usarTelaAlta(tester, largura: 1000);
    await tester.pumpWidget(MaterialApp(home: tela));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o histórico dos últimos 30 dias, com sinal, lote, saldo, origem e usuário', (tester) async {
    final api = montarApi((_) => paginaJson([
          movJson(id: 2, tipo: 'venda', nomeTipo: 'Venda', sinal: -1, quantidade: 3, saldo: 22),
          movJson(id: 1),
        ]));

    await api.usar(() => abrir(tester));

    expect(find.text('+20 UN  •  Leite'), findsOneWidget);
    expect(find.text('−3 UN  •  Leite'), findsOneWidget);
    expect(find.textContaining('Entrada  •  Lote L-1  •  saldo: 25'), findsOneWidget);
    expect(find.textContaining('16/10/2026 14:30  •  Manual  •  por Ana'), findsWidgets);
    expect(find.byIcon(Icons.add_circle), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle), findsOneWidget);

    final filtros = filtrosDa(api);
    expect(filtros['pagina'], '1');
    expect(filtros['limite'], '50');
    final inicio = DateTime.parse(filtros['inicio']!);
    expect(DateTime.now().difference(inicio).inDays, inInclusiveRange(29, 30));
  });

  testWidgets('filtros de tipo, produto e período vão pra API', (tester) async {
    final api = montarApi((_) => paginaJson([movJson(id: 1)]));

    await api.usar(() async {
      await abrir(tester);
      await tester.tap(find.text('Todos os tipos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Venda').last);
      await tester.pumpAndSettle();
      expect(filtrosDa(api)['tipo'], 'venda');

      await tester.tap(find.text('Todos os produtos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arroz').last);
      await tester.pumpAndSettle();
      expect(filtrosDa(api)['id_produto'], '2');

      await tester.tap(find.text('Últimos 30 dias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todo o período').last);
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api).containsKey('inicio'), isFalse);
    expect(filtrosDa(api)['tipo'], 'venda'); // os outros filtros continuam
  });

  testWidgets('carregar mais busca a próxima página e junta na lista', (tester) async {
    final api = montarApi((f) => f['pagina'] == '2'
        ? paginaJson([movJson(id: 1, produto: 'Arroz')], total: 3, pagina: 2)
        : paginaJson([movJson(id: 3), movJson(id: 2)], total: 3));

    await api.usar(() async {
      await abrir(tester);
      expect(find.text('Carregar mais (1 restantes)'), findsOneWidget);
      await tester.tap(find.text('Carregar mais (1 restantes)'));
      await tester.pumpAndSettle();
    });

    expect(filtrosDa(api)['pagina'], '2');
    expect(find.text('+20 UN  •  Arroz'), findsOneWidget);
    expect(find.text('+20 UN  •  Leite'), findsNWidgets(2));
    expect(find.textContaining('Carregar mais'), findsNothing);
  });

  testWidgets('sem movimentação mostra a mensagem', (tester) async {
    final api = montarApi((_) => paginaJson([]));
    await api.usar(() => abrir(tester));
    expect(find.text('Nenhuma movimentação nesse filtro.'), findsOneWidget);
  });

  testWidgets('erro da API aparece num SnackBar', (tester) async {
    final api = ApiFalsa({
      '/movimentacoes': (_) => respostaJson({'erro': 'limite tem que ser entre 1 e 200'}, status: 400),
      '/produtos': (_) => respostaJson([]),
    });
    await api.usar(() => abrir(tester));
    expect(find.widgetWithText(SnackBar, 'limite tem que ser entre 1 e 200'), findsOneWidget);
  });

  testWidgets('histórico do lote abre filtrado pelo lote, sem filtro de produto e período', (tester) async {
    final leite = produtoJson(id: 1, nome: 'Leite', quantidade: 10);
    final api = ApiFalsa({
      '/produtos/1/lotes': (_) => respostaJson({
            'produto': leite,
            'lotes': [
              {
                'id_lote': 7, 'id_produto': 1, 'produto_nome': 'Leite', 'unidade': 'UN', 'codigo_lote': 'L-7',
                'data_entrada': '2026-10-01', 'data_validade': null, 'dias_para_vencer': null, 'vencido': false,
                'quantidade_inicial': 10, 'quantidade_atual': 10, 'custo_unitario': 3.0, 'origem': 'entrada',
                'usuario': 'Ana',
              },
            ],
          }),
      '/movimentacoes': (_) => respostaJson(paginaJson([movJson(id: 1, lote: 'Lote L-7')])),
    });

    await api.usar(() async {
      await abrir(tester, tela: LotesScreen(produto: Produto.fromJson(leite)));
      await tester.tap(find.byTooltip('Histórico do lote'));
      await tester.pumpAndSettle();
    });

    expect(find.text('Histórico — Lote L-7'), findsOneWidget);
    expect(find.text('Todos os produtos'), findsNothing);
    final filtros = filtrosDa(api);
    expect(filtros['id_lote'], '7');
    expect(filtros.containsKey('inicio'), isFalse);
  });

  testWidgets('Movimentações aparece no menu do usuário comum', (tester) async {
    expect(modulosNav.any((m) => m.id == 'movimentacoes' && !m.soAdmin), isTrue);
  });
}
