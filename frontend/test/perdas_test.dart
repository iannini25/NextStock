import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/models/lote.dart';
import 'package:nextstock/models/produto.dart';
import 'package:nextstock/screens/lotes_screen.dart';
import 'package:nextstock/screens/painel_screen.dart';
import 'package:nextstock/screens/perda_form.dart';
import 'package:nextstock/screens/perdas_screen.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

final queijoJson = produtoJson(id: 1, nome: 'Queijo', quantidade: 15);

Map<String, dynamic> loteJson(int id, String codigo, {required int dias, int atual = 5, double custo = 3.0}) => {
      'id_lote': id, 'titulo': 'Lote $codigo', 'id_produto': 1, 'produto_nome': 'Queijo', 'unidade': 'UN',
      'codigo_lote': codigo, 'data_entrada': '2026-10-01', 'data_validade': dataDaqui(dias), 'dias_para_vencer': dias,
      'vencido': dias < 0, 'quantidade_inicial': atual, 'quantidade_atual': atual, 'custo_unitario': custo,
      'origem': 'entrada', 'usuario': 'Ana', 'posicao_saida': 1, 'vender_primeiro': dias >= 0,
    };

Map<String, dynamic> perdaJson(int id, {String motivo = 'vencimento', String nomeMotivo = 'Vencimento', double valor = 15.0}) => {
      'id_perda': id, 'id_produto': 1, 'produto_nome': 'Queijo', 'unidade': 'UN', 'id_lote': 2, 'lote': 'Lote V1',
      'tipo': 'descarte', 'nome_tipo': 'Descarte', 'motivo': motivo, 'nome_motivo': nomeMotivo, 'quantidade': 5,
      'custo_unitario': 3.0, 'valor_total': valor, 'observacao': null, 'usuario': 'Ana',
      'data_registro': '2026-10-16T10:15:00',
    };

Map<String, dynamic> respostaPerda({String? aviso}) =>
    {'perda': perdaJson(9), 'produto': queijoJson, 'aviso': aviso};

void main() {
  setUp(() {
    prepararSessao();
    logarComo(perfil: 'usuario');
  });

  testWidgets('tela de perdas mostra o prejuízo, os motivos e a lista', (tester) async {
    final api = ApiFalsa({
      '/perdas/resumo': (_) => respostaJson({
            'dias': 30, 'valor_total': 23.0, 'quantidade_total': 7, 'registros': 2,
            'por_motivo': [
              {'motivo': 'vencimento', 'nome': 'Vencimento', 'valor': 18.0, 'quantidade': 6, 'registros': 1},
              {'motivo': 'avaria', 'nome': 'Avaria', 'valor': 5.0, 'quantidade': 1, 'registros': 1},
            ],
            'por_produto': [],
          }),
      '/perdas': (_) => respostaJson({'itens': [perdaJson(1)], 'valor_total': 15.0, 'quantidade_total': 5}),
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: PerdasScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Prejuízo no período: R\$ 23.00'), findsOneWidget);
      expect(find.text('7 item(ns) em 2 registro(s)'), findsOneWidget);
      expect(find.text('Vencimento: R\$ 18.00 (6)'), findsOneWidget);
      expect(find.text('Avaria: R\$ 5.00 (1)'), findsOneWidget);
      expect(find.text('−5 UN  •  Queijo  •  R\$ 15.00'), findsOneWidget);
      expect(find.textContaining('Descarte  •  Vencimento  •  Lote V1'), findsOneWidget);

      await tester.tap(find.text('últimos 30 dias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('últimos 7 dias').last);
      await tester.pumpAndSettle();
    });

    expect(api.chamadas('/perdas/resumo').last.url.queryParameters['dias'], '7');
    final inicio = DateTime.parse(api.chamadas('/perdas').last.url.queryParameters['inicio']!);
    expect(DateTime.now().difference(inicio).inDays, inInclusiveRange(6, 7));
  });

  testWidgets('descartar a partir do lote vencido: já vem preenchido e mostra o valor', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/produtos/1/lotes': (_) => respostaJson({
            'produto': queijoJson,
            'lotes': [loteJson(1, 'BOM', dias: 10, atual: 10), loteJson(2, 'V1', dias: -1, atual: 5, custo: 3.5)],
          }),
      '/perdas': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(respostaPerda(), status: 201);
      },
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(MaterialApp(home: LotesScreen(produto: Produto.fromJson(queijoJson))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Descartar'), findsOneWidget); // so no lote vencido

      await tester.tap(find.byTooltip('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar descarte'), findsOneWidget);
      expect(find.textContaining('Lote V1  •  saldo: 5'), findsOneWidget);
      expect(find.text('Valor da perda: R\$ 17.50'), findsOneWidget); // 5 x 3,50

      await preencher(tester, 'Quantidade *', '2');
      await tester.pump();
      expect(find.text('Valor da perda: R\$ 7.00'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {'id_lote': 2, 'quantidade': 2, 'tipo': 'descarte', 'motivo': 'vencimento', 'observacao': null});
    expect(find.text('Descarte registrado'), findsOneWidget);
    expect(api.chamadas('/produtos/1/lotes'), hasLength(2)); // voltou e recarregou os lotes
  });

  testWidgets('registrar perda escolhendo produto e lote', (tester) async {
    Map<String, dynamic>? enviado;
    final api = ApiFalsa({
      '/produtos': (_) => respostaJson([queijoJson, produtoJson(id: 2, nome: 'Sem estoque', quantidade: 0)]),
      '/produtos/1/lotes': (_) => respostaJson({'produto': queijoJson, 'lotes': [loteJson(1, 'L1', dias: 10, atual: 10)]}),
      '/perdas': (req) {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return respostaJson(respostaPerda(), status: 201);
      },
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: PerdaForm()));
      await tester.pumpAndSettle();
      expect(find.text('Registrar perda'), findsOneWidget);

      await tester.tap(find.text('Produto *'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sem estoque'), findsNothing); // so produtos com estoque
      await tester.tap(find.text('Queijo (estoque: 15)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lote *'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Lote L1 — saldo 10').last);
      await tester.pumpAndSettle();

      await preencher(tester, 'Quantidade *', '3');
      await tester.tap(find.text('Motivo *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avaria').last);
      await tester.pumpAndSettle();
      await preencher(tester, 'Observação (opcional)', 'caiu da prateleira');
      await tester.pump();
      expect(find.text('Valor da perda: R\$ 9.00'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    });

    expect(enviado, {'id_lote': 1, 'quantidade': 3, 'tipo': 'perda', 'motivo': 'avaria', 'observacao': 'caiu da prateleira'});
  });

  testWidgets('quantidade maior que o saldo e motivo vazio são barrados no app', (tester) async {
    final api = ApiFalsa({'/perdas': (_) => respostaJson(respostaPerda(), status: 201)});
    final lote = loteJson(2, 'V1', dias: -1, atual: 5);

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(MaterialApp(
        home: PerdaForm(produto: Produto.fromJson(queijoJson), lote: _lote(lote)),
      ));
      await tester.pumpAndSettle();
      await preencher(tester, 'Quantidade *', '9');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBar, 'o lote só tem 5 em estoque'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // o aviso some (o proximo fica na fila ate la)
      await tester.pumpAndSettle();

      await preencher(tester, 'Quantidade *', '2');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    });

    expect(find.widgetWithText(SnackBar, 'escolha o motivo'), findsOneWidget);
    expect(api.chamadas('/perdas'), isEmpty);
  });

  testWidgets('aviso da API (produto sem custo) aparece depois de registrar', (tester) async {
    final api = ApiFalsa({
      '/perdas': (_) => respostaJson(
          respostaPerda(aviso: 'esse produto não tem custo cadastrado: o valor da perda ficou R\$ 0,00'), status: 201),
    });

    await api.usar(() async {
      usarTelaAlta(tester);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => PerdaForm(
                  produto: Produto.fromJson(queijoJson),
                  lote: _lote(loteJson(2, 'V1', dias: -1)),
                  tipoInicial: 'descarte',
                  motivoInicial: 'vencimento',
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('não tem custo cadastrado'), findsOneWidget);
  });

  testWidgets('painel mostra as perdas registradas', (tester) async {
    final api = ApiFalsa({
      '/painel': (_) => respostaJson({
            'total_produtos': 3, 'itens_em_estoque': 10, 'valor_estoque': 50.0, 'produtos_vencidos': 0,
            'valor_vencido': 0.0, 'produtos_vencendo': 0, 'produtos_em_risco': 0, 'vendas_30_dias': 0,
            'faturamento_30_dias': 0.0, 'percentual_desperdicio': 0.0, 'giro_estoque': 0.0,
            'valor_perdas_30_dias': 42.5, 'quantidade_perdas_30_dias': 12,
          }),
    });

    await api.usar(() async {
      usarTelaAlta(tester, altura: 2000);
      await tester.pumpWidget(const MaterialApp(home: PainelScreen()));
      await tester.pumpAndSettle();
    });

    expect(find.descendant(of: find.widgetWithText(ListTile, 'Perdas registradas (30 dias)'), matching: find.text('R\$ 42.50')),
        findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(ListTile, 'Itens perdidos (30 dias)'), matching: find.text('12')),
        findsOneWidget);
  });
}

// monta o Lote do app a partir do json de teste
Lote _lote(Map<String, dynamic> j) => Lote.fromJson(j);
