import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/models/produto.dart';
import 'package:nextstock/screens/lotes_screen.dart';
import 'package:nextstock/screens/recomendacoes_screen.dart';
import 'package:nextstock/screens/venda_form.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

final leiteJson = produtoJson(id: 1, nome: 'Leite', quantidade: 12);

Map<String, dynamic> loteJson(int id, String codigo, {required int? dias, int atual = 4, int? posicao, bool primeiro = false}) => {
      'id_lote': id, 'titulo': 'Lote $codigo', 'id_produto': 1, 'produto_nome': 'Leite', 'unidade': 'UN',
      'codigo_lote': codigo, 'data_entrada': '2026-10-01', 'data_validade': dias == null ? null : dataDaqui(dias),
      'dias_para_vencer': dias, 'vencido': dias != null && dias < 0, 'quantidade_inicial': atual,
      'quantidade_atual': atual, 'custo_unitario': 3.0, 'origem': 'entrada', 'usuario': 'Ana',
      'posicao_saida': posicao, 'vender_primeiro': primeiro,
    };

Map<String, dynamic> saida(String titulo, int qtd, int? dias) => {
      'id_lote': 1, 'titulo': titulo, 'quantidade': qtd, 'data_validade': null,
      'dias_para_vencer': dias, 'vencido': dias != null && dias < 0,
    };

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  testWidgets('lotes: selo VENDER PRIMEIRO no próximo a sair e RETIRAR no vencido', (tester) async {
    final api = ApiFalsa({
      '/produtos/1/lotes': (_) => respostaJson({
            'produto': leiteJson,
            'lotes': [
              loteJson(2, 'PERTO', dias: 2, posicao: 1, primeiro: true),
              loteJson(3, 'LONGE', dias: 20, posicao: 2),
              loteJson(1, 'VENC', dias: -1, posicao: 3),
            ],
          }),
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(MaterialApp(home: LotesScreen(produto: Produto.fromJson(leiteJson))));
      await tester.pumpAndSettle();
    });

    Finder noCard(String lote, String texto) =>
        find.descendant(of: find.ancestor(of: find.textContaining(lote), matching: find.byType(Card)), matching: find.text(texto));
    expect(noCard('Lote PERTO', 'VENDER PRIMEIRO'), findsOneWidget);
    expect(noCard('Lote VENC', 'RETIRAR'), findsOneWidget);
    expect(find.text('VENDER PRIMEIRO'), findsOneWidget);
    expect(find.textContaining('1º na fila de saída'), findsOneWidget);
    expect(find.textContaining('3º na fila de saída'), findsOneWidget);
  });

  group('venda', () {
    Future<void> escolherProduto(WidgetTester tester) async {
      await tester.tap(find.text('Produto *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leite (estoque: 12)').last);
      await tester.pumpAndSettle();
    }

    Future<void> digitarQuantidade(WidgetTester tester, String qtd) async {
      await preencher(tester, 'Quantidade *', qtd);
      await tester.pump(const Duration(milliseconds: 450)); // espera de digitacao
      await tester.pumpAndSettle();
    }

    testWidgets('mostra a prévia dos lotes e atualiza quando muda a quantidade', (tester) async {
      final api = ApiFalsa({
        '/produtos': (_) => respostaJson([leiteJson]),
        '/vendas/previa': (req) {
          final qtd = int.parse(req.url.queryParameters['quantidade']!);
          final lotes = qtd <= 4 ? [saida('Lote L1', qtd, 2)] : [saida('Lote L1', 4, 2), saida('Lote L2', qtd - 4, 20)];
          return respostaJson({'id_produto': 1, 'quantidade': qtd, 'suficiente': true, 'falta': 0, 'lotes': lotes, 'aviso': null});
        },
      });

      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: VendaForm()));
        await tester.pumpAndSettle();
        await escolherProduto(tester);
        await digitarQuantidade(tester, '3');
        expect(find.text('• 3 do Lote L1 (vence em 2 dia(s))'), findsOneWidget);

        await digitarQuantidade(tester, '7');
      });

      expect(find.text('• 4 do Lote L1 (vence em 2 dia(s))'), findsOneWidget);
      expect(find.text('• 3 do Lote L2 (vence em 20 dia(s))'), findsOneWidget);
      expect(api.chamadas('/vendas/previa').last.url.queryParameters, {'id_produto': '1', 'quantidade': '7'});
    });

    testWidgets('prévia avisa estoque insuficiente e lote vencido', (tester) async {
      final api = ApiFalsa({
        '/produtos': (_) => respostaJson([leiteJson]),
        '/vendas/previa': (_) => respostaJson({
              'id_produto': 1, 'quantidade': 20, 'suficiente': false, 'falta': 8,
              'lotes': [saida('Lote L1', 10, 5), saida('Lote VENC', 2, -1)],
              'aviso': 'parte da venda sairia de lote vencido: confira se esse produto ainda está bom pra vender',
            }),
      });

      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: VendaForm()));
        await tester.pumpAndSettle();
        await escolherProduto(tester);
        await digitarQuantidade(tester, '20');
      });

      expect(find.text('Estoque insuficiente: faltam 8'), findsOneWidget);
      expect(find.text('• 2 do Lote VENC (VENCIDO há 1 dia(s))'), findsOneWidget);
      expect(find.textContaining('parte da venda sairia de lote vencido'), findsOneWidget);
    });

    testWidgets('se a prévia falhar, a venda continua e mostra os lotes que saíram', (tester) async {
      Map<String, dynamic>? enviado;
      final api = ApiFalsa({
        '/produtos': (_) => respostaJson([leiteJson]),
        '/vendas/previa': (_) => respostaJson({'erro': 'fora do ar'}, status: 500),
        '/vendas': (req) {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson({
            'id_venda': 9, 'id_produto': 1, 'produto_nome': 'Leite', 'quantidade': 5, 'valor_total': 25.0,
            'data_venda': '2026-10-16',
            'lotes_consumidos': [saida('Lote L1', 4, 2), saida('Lote L2', 1, 20)],
          }, status: 201);
        },
      });

      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const VendaForm())),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await escolherProduto(tester);
        await digitarQuantidade(tester, '5');
        expect(find.textContaining('Vai sair'), findsNothing); // previa falhou: so nao aparece
        expect(find.byType(SnackBar), findsNothing);

        await tester.tap(find.text('Registrar venda'));
        await tester.pumpAndSettle();
      });

      expect(enviado!['quantidade'], 5);
      expect(find.text('Nova venda'), findsNothing); // voltou
      expect(
        find.text('Venda registrada: saiu 4 do Lote L1 (vence em 2 dia(s)) e 1 do Lote L2 (vence em 20 dia(s))'),
        findsOneWidget,
      );
    });
  });

  testWidgets('recomendações de lote ganham o ícone de lote', (tester) async {
    final api = ApiFalsa({
      '/recomendacoes': (_) => respostaJson([
            {'tipo': 'retirar', 'prioridade': 'alta', 'id_produto': 1, 'produto_nome': 'Queijo', 'id_lote': 4,
             'mensagem': 'Lote V1 vencido com 5 em estoque: tire da prateleira'},
            {'tipo': 'produto_parado', 'prioridade': 'media', 'id_produto': 2, 'produto_nome': 'Arroz', 'id_lote': null,
             'mensagem': 'Sem venda em 30 dias: avalie promoção ou tirar do mix'},
          ]),
    });

    await api.usar(() async {
      await tester.pumpWidget(const MaterialApp(home: RecomendacoesScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.text('Lote V1 vencido com 5 em estoque: tire da prateleira'), findsOneWidget);
    expect(find.byIcon(Icons.inventory), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsOneWidget);
  });
}
