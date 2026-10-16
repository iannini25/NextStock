import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/screens/alertas_screen.dart';
import 'package:nextstock/shell/app_shell.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> excessoJson({
  required String nome,
  String tipo = 'perecivel',
  String prioridade = 'alta',
  String classe = 'A',
  int quantidade = 5,
  double valor = 10.0,
  String mensagem = 'Lote L1: 5 de 10 UN não devem ser vendidos antes de vencer',
}) {
  return {
    'tipo': tipo,
    'prioridade': prioridade,
    'classe_abc': classe,
    'id_produto': 1,
    'produto_nome': nome,
    'unidade': 'UN',
    'id_lote': tipo == 'perecivel' ? 7 : null,
    'lote': tipo == 'perecivel' ? 'Lote L1' : null,
    'data_validade': tipo == 'perecivel' ? dataDaqui(2) : null,
    'dias_para_vencer': tipo == 'perecivel' ? 2 : null,
    'quantidade_em_risco': quantidade,
    'valor_em_risco': valor,
    'demanda_diaria': 1.0,
    'dias_cobertura': tipo == 'perecivel' ? null : 100,
    'mensagem': mensagem,
  };
}

Map<String, dynamic> resumoJson({int vencendo = 1, int falta = 2, int excesso = 3, int alta = 1}) => {
      'vencendo': vencendo,
      'falta': falta,
      'excesso': excesso,
      'total': vencendo + falta + excesso,
      'prioridade_alta': alta,
    };

ApiFalsa montarApi({Map<String, dynamic>? resumo}) {
  return ApiFalsa({
    '/produtos/vencendo': (_) => respostaJson([produtoJson(id: 1, nome: 'Iogurte', validade: dataDaqui(3))]),
    '/lotes/vencendo': (_) => respostaJson([]),
    '/produtos/risco-ruptura': (_) => respostaJson([
          {...produtoJson(id: 3, nome: 'Alface', quantidade: 1, minimo: 15, motivo: 'estoque no mínimo'),
           'prioridade': 'alta', 'classe_abc': 'A'},
        ]),
    '/alertas/excesso': (_) => respostaJson([
          excessoJson(nome: 'Iogurte Morango'),
          excessoJson(
            nome: 'Enfeite',
            tipo: 'cobertura',
            prioridade: 'media',
            classe: 'C',
            quantidade: 7,
            valor: 21.0,
            mensagem: 'Sem venda prevista: 7 UN parados no estoque.',
          ),
        ]),
    '/alertas/resumo': (_) => respostaJson(resumo ?? resumoJson()),
    '/clima': (_) => respostaJson(climaJson()),
    '/produtos': (_) => respostaJson([]),
  });
}

void main() {
  group('tela de alertas', () {
    testWidgets('botão Excesso mostra os dois tipos com valor e prioridade', (tester) async {
      usarTelaAlta(tester);
      final api = montarApi();
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excesso'));
        await tester.pumpAndSettle();
      });

      expect(find.text('Iogurte Morango'), findsOneWidget);
      expect(find.textContaining('Vai vencer parado: 5 UN  •  R\$ 10.00 em risco'), findsOneWidget);
      expect(find.textContaining('não devem ser vendidos antes de vencer'), findsOneWidget);
      expect(find.text('Enfeite'), findsOneWidget);
      expect(find.textContaining('Estoque demais: 7 UN'), findsOneWidget);
      expect(find.textContaining('Sem venda prevista'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Média'), findsOneWidget);
      expect(find.text('classe A'), findsOneWidget);
      expect(find.textContaining('2 alerta(s)  •  R\$ 31.00 em risco'), findsOneWidget);
      expect(find.text('Iogurte'), findsNothing); // a lista do Vencendo saiu
      expect(api.chamadas('/alertas/excesso').single.url.queryParameters['dias_cobertura'], '30');
    });

    testWidgets('trocar o estoque ideal busca de novo com o novo limite', (tester) async {
      usarTelaAlta(tester);
      final api = montarApi();
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excesso'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('30 dias de venda'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('60 dias de venda').last);
        await tester.pumpAndSettle();
      });

      final limites = api.chamadas('/alertas/excesso').map((r) => r.url.queryParameters['dias_cobertura']);
      expect(limites, ['30', '60']);
    });

    testWidgets('sem excesso mostra mensagem', (tester) async {
      final api = ApiFalsa({
        '/produtos/vencendo': (_) => respostaJson([]),
        '/lotes/vencendo': (_) => respostaJson([]),
        '/alertas/excesso': (_) => respostaJson([]),
        '/clima': (_) => respostaJson(climaJson()),
      });
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excesso'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Nenhum produto com estoque sobrando.'), findsOneWidget);
    });

    testWidgets('Vai faltar mostra a prioridade e a classe, sem perder o resto', (tester) async {
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
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('classe A'), findsOneWidget);
    });

    testWidgets('Vencendo continua sem selo de prioridade', (tester) async {
      final api = montarApi();
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
      });
      expect(find.text('Iogurte'), findsOneWidget);
      expect(find.text('Alta'), findsNothing);
      expect(api.chamadas('/alertas/excesso'), isEmpty);
    });

    testWidgets('erro no excesso aparece num SnackBar', (tester) async {
      final api = ApiFalsa({
        '/produtos/vencendo': (_) => respostaJson([]),
        '/lotes/vencendo': (_) => respostaJson([]),
        '/alertas/excesso': (_) => respostaJson({'erro': 'dias_cobertura tem que ser entre 1 e 365'}, status: 400),
        '/clima': (_) => respostaJson(climaJson()),
      });
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excesso'));
        await tester.pumpAndSettle();
      });
      expect(find.widgetWithText(SnackBar, 'dias_cobertura tem que ser entre 1 e 365'), findsOneWidget);
    });
  });

  group('selo de alertas no menu', () {
    setUp(prepararSessao);

    Finder seloDoMenu(String texto) => find.descendant(of: find.byType(Badge), matching: find.text(texto));

    testWidgets('mostra o total no botão do menu e no item Alertas', (tester) async {
      usarTelaAlta(tester);
      logarComo(perfil: 'usuario');
      final api = montarApi(); // 1 + 2 + 3 = 6
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
      });
      expect(seloDoMenu('6'), findsOneWidget); // no botao do menu (celular)

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final itemAlertas = find.widgetWithText(ListTile, 'Alertas');
      expect(find.descendant(of: itemAlertas, matching: find.text('6')), findsOneWidget);
      expect(find.byTooltip('1 vencendo • 2 vai faltar • 3 excesso'), findsOneWidget);
      expect(api.chamadas('/alertas/resumo'), hasLength(1));
    });

    testWidgets('sem alertas não aparece selo', (tester) async {
      usarTelaAlta(tester);
      logarComo();
      await montarApi(resumo: resumoJson(vencendo: 0, falta: 0, excesso: 0, alta: 0)).usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
      });
      expect(seloDoMenu('0'), findsNothing);
    });

    testWidgets('atualiza sozinho a cada 5 minutos', (tester) async {
      usarTelaAlta(tester);
      logarComo();
      var total = 6;
      final api = ApiFalsa({
        '/alertas/resumo': (_) => respostaJson(resumoJson(vencendo: 0, falta: 0, excesso: total)),
      });
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
      });
      expect(seloDoMenu('6'), findsOneWidget);

      total = 2; // resolveram alertas
      await tester.pump(const Duration(minutes: 4));
      expect(seloDoMenu('6'), findsOneWidget); // ainda nao deu 5 min
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(seloDoMenu('2'), findsOneWidget);
      expect(api.chamadas('/alertas/resumo'), hasLength(2));
    });

    testWidgets('o relógio para quando o app sai da tela (logout)', (tester) async {
      usarTelaAlta(tester);
      logarComo();
      final api = montarApi();
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const MaterialApp(home: SizedBox())); // AppShell sai (dispose)
      });
      await tester.pump(const Duration(minutes: 20));
      expect(api.chamadas('/alertas/resumo'), hasLength(1));
    });

    testWidgets('erro no resumo não atrapalha: só não mostra o selo', (tester) async {
      usarTelaAlta(tester);
      logarComo();
      await ApiFalsa({
        '/alertas/resumo': (_) => respostaJson({'erro': 'falhou'}, status: 500),
      }).usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
      });
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Produtos'), findsOneWidget); // a tela inicial abriu normal
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('abrir Alertas atualiza o selo', (tester) async {
      usarTelaAlta(tester);
      logarComo();
      final api = montarApi();
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Alertas'));
        await tester.pumpAndSettle();
      });
      expect(find.byType(AlertasScreen), findsOneWidget);
      expect(api.chamadas('/alertas/resumo'), hasLength(2));
    });
  });
}
