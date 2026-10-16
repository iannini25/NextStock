import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextstock/models/produto.dart';
import 'package:nextstock/screens/alertas_screen.dart';
import 'package:nextstock/screens/armazenamento_screen.dart';
import 'package:nextstock/screens/local_detalhe_screen.dart';
import 'package:nextstock/screens/local_form.dart';
import 'package:nextstock/screens/perda_form.dart';
import 'package:nextstock/screens/produto_form.dart';
import 'package:nextstock/shell/app_shell.dart';

import 'apoio/api_falsa.dart';
import 'apoio/dados.dart';
import 'apoio/sessao.dart';
import 'apoio/tela.dart';

Map<String, dynamic> leituraJson(int id, double temperatura, {bool fora = false, String origem = 'manual'}) => {
      'id_leitura': id, 'id_local': 1, 'temperatura': temperatura, 'umidade': 65.0,
      'data_hora': '2026-10-16T14:30:00', 'origem': origem, 'nome_origem': origem == 'sensor' ? 'Sensor' : 'Manual',
      'usuario': origem == 'sensor' ? null : 'Ana', 'fora_da_faixa': fora,
    };

Map<String, dynamic> localJson({
  int id = 1,
  String nome = 'Geladeira laticínios',
  String status = 'ok',
  String nomeStatus = 'OK',
  double? ultima = 4.0,
  bool ativo = true,
  List<Map<String, dynamic>> produtos = const [],
  String mensagem = 'Geladeira laticínios: 4.0 °C, dentro da faixa 0.0 °C a 5.0 °C.',
}) =>
    {
      'id_local': id, 'nome': nome, 'tipo': 'refrigerado', 'nome_tipo': 'Refrigerado', 'temp_min': 0.0,
      'temp_max': 5.0, 'ativo': ativo, 'status': status, 'nome_status': nomeStatus,
      'prioridade': {'fora_da_faixa': 'alta', 'sem_leitura': 'media'}[status],
      'ultima_leitura': ultima == null ? null : leituraJson(1, ultima, fora: status == 'fora_da_faixa'),
      'horas_desde_ultima': 0.5, 'quantidade_produtos': produtos.length,
      'valor_em_estoque': produtos.fold<double>(0, (s, p) => s + (p['valor'] as double)),
      'mensagem': mensagem, 'produtos': produtos,
    };

final leiteNoLocal = {'id_produto': 7, 'nome': 'Leite', 'unidade': 'UN', 'quantidade_estoque': 10, 'valor': 30.0};

const msgFora = 'Geladeira laticínios: 9.0 °C em 16/10 14:30 (faixa 0.0 °C a 5.0 °C) — 4.0 °C acima do máximo.';

void main() {
  setUp(prepararSessao);

  group('lista de locais', () {
    testWidgets('mostra status, faixa, última leitura e o aviso de atenção', (tester) async {
      logarComo(perfil: 'usuario');
      final api = ApiFalsa({
        '/locais-armazenamento': (_) => respostaJson([
              localJson(),
              localJson(id: 2, nome: 'Freezer', status: 'fora_da_faixa', nomeStatus: 'Fora da faixa', ultima: -10),
            ]),
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: ArmazenamentoScreen()));
        await tester.pumpAndSettle();
      });
      expect(find.text('Geladeira laticínios'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Fora da faixa'), findsOneWidget);
      expect(find.textContaining('faixa 0.0 °C a 5.0 °C'), findsNWidgets(2));
      expect(find.textContaining('última: 4.0 °C em 16/10 14:30'), findsOneWidget);
      expect(find.text('1 local(is) precisam de atenção'), findsOneWidget);
      expect(find.text('Novo local'), findsNothing); // usuario comum nao cadastra
      expect(api.chamadas('/locais-armazenamento').single.url.queryParameters['todos'], isNull);
    });

    testWidgets('admin vê o botão Novo local e os desativados', (tester) async {
      logarComo(perfil: 'admin');
      final api = ApiFalsa({'/locais-armazenamento': (_) => respostaJson([])});
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: ArmazenamentoScreen()));
        await tester.pumpAndSettle();
      });
      expect(find.text('Novo local'), findsOneWidget);
      expect(find.textContaining('Nenhum local cadastrado'), findsOneWidget);
      expect(api.chamadas('/locais-armazenamento').single.url.queryParameters['todos'], '1');
    });
  });

  group('formulário de local', () {
    testWidgets('trocar o tipo preenche a faixa sugerida e salva', (tester) async {
      logarComo(perfil: 'admin');
      Map<String, dynamic>? enviado;
      final api = ApiFalsa({
        '/locais-armazenamento': (req) {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(localJson(), status: 201);
        },
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalForm()));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mínima (°C) *')).controller!.text, '0.0');
        await tester.tap(find.text('Refrigerado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Congelado').last);
        await tester.pumpAndSettle();
        await preencher(tester, 'Nome * (ex.: Geladeira laticínios)', 'Freezer');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
      });
      expect(enviado, {'nome': 'Freezer', 'tipo': 'congelado', 'temp_min': -25.0, 'temp_max': -18.0});
    });

    testWidgets('mínima maior que a máxima não envia', (tester) async {
      logarComo(perfil: 'admin');
      final api = ApiFalsa({});
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalForm()));
        await tester.pumpAndSettle();
        await preencher(tester, 'Nome * (ex.: Geladeira laticínios)', 'X');
        await preencher(tester, 'Mínima (°C) *', '8');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
      });
      expect(find.text('a temperatura mínima tem que ser menor que a máxima'), findsOneWidget);
      expect(api.requisicoes, isEmpty);
    });
  });

  group('detalhe do local', () {
    ApiFalsa montarApi({String statusDepois = 'ok', List<Map<String, dynamic>> produtos = const []}) {
      return ApiFalsa({
        '/locais-armazenamento/1': (_) => respostaJson(localJson(produtos: produtos)),
        '/locais-armazenamento/1/leituras': (req) {
          if (req.method == 'POST') {
            return respostaJson({
              'leitura': leituraJson(3, 9.0, fora: statusDepois == 'fora_da_faixa'),
              'local': localJson(status: statusDepois, nomeStatus: statusDepois == 'ok' ? 'OK' : 'Fora da faixa',
                  mensagem: statusDepois == 'ok' ? 'ok' : msgFora),
            }, status: 201);
          }
          return respostaJson([leituraJson(2, 9.5, fora: true, origem: 'sensor'), leituraJson(1, 4.0)]);
        },
        '/produtos': (_) => respostaJson([produtoJson(id: 7, nome: 'Leite', quantidade: 10)]),
        '/produtos/7/lotes': (_) => respostaJson({
              'produto': produtoJson(id: 7, nome: 'Leite', quantidade: 10),
              'lotes': [
                {'id_lote': 4, 'titulo': 'Lote L4', 'id_produto': 7, 'quantidade_inicial': 10, 'quantidade_atual': 10,
                 'custo_unitario': 3.0, 'origem': 'entrada'},
              ],
            }),
      });
    }

    testWidgets('mostra situação, número do local e histórico com a leitura fora da faixa destacada', (tester) async {
      logarComo(perfil: 'usuario');
      await montarApi().usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalDetalheScreen(idLocal: 1)));
        await tester.pumpAndSettle();
      });
      expect(find.textContaining('Local #1'), findsOneWidget);
      expect(find.text('9.5 °C  •  65%'), findsOneWidget);
      expect(find.textContaining('Sensor'), findsOneWidget);
      expect(find.textContaining('Manual  •  Ana'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.byTooltip('Editar'), findsNothing); // usuario comum nao edita local
    });

    testWidgets('registrar leitura manda o número (aceita vírgula) e avisa quando sai da faixa', (tester) async {
      logarComo(perfil: 'usuario');
      final api = montarApi(statusDepois: 'fora_da_faixa');
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalDetalheScreen(idLocal: 1)));
        await tester.pumpAndSettle();
        await preencher(tester, 'Temperatura (°C) *', '9,0');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar leitura'));
        await tester.pumpAndSettle();
      });
      final post = api.chamadas('/locais-armazenamento/1/leituras').firstWhere((r) => r.method == 'POST');
      expect(jsonDecode(post.body), {'temperatura': 9.0, 'umidade': null});
      expect(find.textContaining('Fora da faixa! $msgFora'), findsOneWidget);
    });

    testWidgets('temperatura vazia não envia', (tester) async {
      logarComo(perfil: 'usuario');
      final api = montarApi();
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalDetalheScreen(idLocal: 1)));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar leitura'));
        await tester.pumpAndSettle();
      });
      expect(find.text('informe a temperatura (ex.: 4,5)'), findsOneWidget);
      expect(api.chamadas('/locais-armazenamento/1/leituras').where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('produto do local tem atalho pra registrar perda com motivo temperatura', (tester) async {
      logarComo(perfil: 'usuario');
      final api = montarApi(produtos: [leiteNoLocal]);
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalDetalheScreen(idLocal: 1)));
        await tester.pumpAndSettle();
        expect(find.textContaining('Produtos guardados aqui (R\$ 30.00)'), findsOneWidget);
        expect(find.text('10 UN  •  R\$ 30.00'), findsOneWidget);
        await tester.tap(find.text('Registrar perda'));
        await tester.pumpAndSettle();
      });
      expect(find.byType(PerdaForm), findsOneWidget);
      expect(find.text('Temperatura'), findsOneWidget); // motivo ja escolhido
      expect(find.textContaining('Leite (estoque: 10)'), findsOneWidget); // produto ja escolhido
      expect(api.chamadas('/produtos/7/lotes'), hasLength(1)); // e os lotes dele carregados
    });

    testWidgets('admin desativa o local com confirmação', (tester) async {
      logarComo(perfil: 'admin');
      final base = montarApi();
      final api = ApiFalsa({
        ...base.rotas,
        '/locais-armazenamento/1': (req) => req.method == 'DELETE'
            ? respostaJson(localJson(ativo: false))
            : respostaJson(localJson()),
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: LocalDetalheScreen(idLocal: 1)));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Desativar'));
        await tester.pumpAndSettle();
        expect(find.text('Desativar local?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Desativar'));
        await tester.pumpAndSettle();
      });
      expect(api.chamadas('/locais-armazenamento/1').where((r) => r.method == 'DELETE'), hasLength(1));
    });
  });

  group('produto', () {
    final leite = Produto.fromJson({...produtoJson(id: 7, nome: 'Leite'), 'id_local_armazenamento': 1,
                                    'local_armazenamento': 'Geladeira laticínios'});

    testWidgets('formulário mostra o local e manda o escolhido', (tester) async {
      logarComo(perfil: 'usuario');
      Map<String, dynamic>? enviado;
      final api = ApiFalsa({
        '/categorias': (_) => respostaJson([]),
        '/locais-armazenamento': (_) => respostaJson([localJson(), localJson(id: 2, nome: 'Freezer')]),
        '/produtos/7': (req) {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(produtoJson(id: 7, nome: 'Leite'));
        },
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(MaterialApp(home: ProdutoForm(produto: leite)));
        await tester.pumpAndSettle();
        expect(find.text('Geladeira laticínios (0.0 °C a 5.0 °C)'), findsOneWidget);
        await tester.tap(find.text('Geladeira laticínios (0.0 °C a 5.0 °C)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Freezer (0.0 °C a 5.0 °C)').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
      });
      expect(enviado!['id_local_armazenamento'], 2);
    });

    testWidgets('sem a lista de locais o formulário funciona e não mexe no local', (tester) async {
      logarComo(perfil: 'usuario');
      Map<String, dynamic>? enviado;
      final api = ApiFalsa({
        '/categorias': (_) => respostaJson([]),
        '/locais-armazenamento': (_) => respostaJson({'erro': 'falhou'}, status: 500),
        '/produtos/7': (req) {
          enviado = jsonDecode(req.body) as Map<String, dynamic>;
          return respostaJson(produtoJson(id: 7, nome: 'Leite'));
        },
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(MaterialApp(home: ProdutoForm(produto: leite)));
        await tester.pumpAndSettle();
        expect(find.text('Local de armazenamento'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
      });
      expect(enviado!.containsKey('id_local_armazenamento'), isFalse); // a API mantem o local
    });

    testWidgets('local desativado do produto continua aparecendo', (tester) async {
      logarComo(perfil: 'usuario');
      final api = ApiFalsa({
        '/categorias': (_) => respostaJson([]),
        '/locais-armazenamento': (_) => respostaJson([localJson(id: 2, nome: 'Freezer')]),
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(MaterialApp(home: ProdutoForm(produto: leite)));
        await tester.pumpAndSettle();
      });
      expect(find.text('Geladeira laticínios (desativado)'), findsOneWidget);
    });
  });

  group('alertas e menu', () {
    final resumo = {'vencendo': 0, 'falta': 0, 'excesso': 0, 'temperatura': 2, 'total': 2, 'prioridade_alta': 1};
    final alertasTemp = [
      localJson(status: 'fora_da_faixa', nomeStatus: 'Fora da faixa', ultima: 9, mensagem: msgFora),
      localJson(id: 2, nome: 'Freezer', status: 'sem_leitura', nomeStatus: 'Sem leitura', ultima: null,
          mensagem: 'Freezer: nenhuma leitura de temperatura registrada ainda.'),
    ];

    testWidgets('tela de alertas mostra o aviso de temperatura', (tester) async {
      final api = ApiFalsa({
        '/produtos/vencendo': (_) => respostaJson([]),
        '/lotes/vencendo': (_) => respostaJson([]),
        '/clima': (_) => respostaJson(climaJson()),
        '/armazenamento/alertas': (_) => respostaJson(alertasTemp),
      });
      await api.usar(() async {
        usarTelaAlta(tester);
        await tester.pumpWidget(const MaterialApp(home: AlertasScreen()));
        await tester.pumpAndSettle();
      });
      expect(find.text('2 local(is) com problema de temperatura'), findsOneWidget);
      expect(find.textContaining('4.0 °C acima do máximo'), findsOneWidget);
      expect(find.text('Ver'), findsNothing); // sem o atalho fora do menu
    });

    testWidgets('selo de temperatura no item Armazenamento e o Ver abre a tela', (tester) async {
      usarTelaAlta(tester);
      logarComo(perfil: 'usuario');
      final api = ApiFalsa({
        '/alertas/resumo': (_) => respostaJson(resumo),
        '/produtos/vencendo': (_) => respostaJson([]),
        '/lotes/vencendo': (_) => respostaJson([]),
        '/clima': (_) => respostaJson(climaJson()),
        '/armazenamento/alertas': (_) => respostaJson(alertasTemp),
        '/locais-armazenamento': (_) => respostaJson([localJson()]),
      });
      await api.usar(() async {
        await tester.pumpWidget(const MaterialApp(home: AppShell()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        final item = find.widgetWithText(ListTile, 'Armazenamento');
        expect(find.descendant(of: item, matching: find.text('2')), findsOneWidget);
        expect(find.byTooltip('0 vencendo • 0 vai faltar • 0 excesso • 2 temperatura'), findsOneWidget);

        await tester.tap(find.widgetWithText(ListTile, 'Alertas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver'));
        await tester.pumpAndSettle();
      });
      expect(find.byType(ArmazenamentoScreen), findsOneWidget);
    });

    test('item Armazenamento existe pra todos os perfis', () {
      expect(modulosNav.where((m) => m.id == 'armazenamento').single.soAdmin, isFalse);
    });
  });
}
